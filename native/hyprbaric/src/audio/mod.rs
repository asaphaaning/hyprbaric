//! Audio runtime.
//!
//! [`Control`] owns the live audio handle used by the bar. The domain module
//! defines the public vocabulary, while [`backend`] owns the `wpctl` boundary.

mod backend;
mod domain;
mod signal;

use std::{
    process::Stdio,
    sync::{Arc, Mutex},
    time::Duration,
};

use serde::Deserialize;
use tokio::{
    io::{AsyncBufReadExt, BufReader},
    process::Command as ProcessCommand,
    sync::broadcast,
    time::{Instant, interval, timeout_at},
};
use tracing::instrument;

use self::{
    backend::Devices,
    domain::{Command as PublicCommand, EndpointKind},
};

pub use domain::EndpointKind as Kind;
pub use domain::{Command, Endpoint, OutputId, Outputs, Percent, Report, Snapshot, VolumeStep};

/// Shared audio runtime handle.
pub type Handle = Arc<Control>;

const REFRESH_INTERVAL: Duration = Duration::from_secs(10);
const EVENT_DEBOUNCE: Duration = Duration::from_millis(140);

/// Audio interaction policy loaded from Hyprbaric configuration.
///
/// ```toml
/// [audio]
/// volume_step = 5
/// ```
#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Eq)]
#[serde(default)]
pub struct Configuration {
    volume_step: VolumeStep,
}

impl Default for Configuration {
    fn default() -> Self {
        Self {
            volume_step: VolumeStep::DEFAULT,
        }
    }
}

impl Configuration {
    /// Returns the normalized volume shortcut step.
    pub const fn volume_step(self) -> VolumeStep {
        self.volume_step
    }
}

/// Live audio state and command delivery.
///
/// [`Control`] polls occasionally, reacts to PipeWire/Pulse events, and reports
/// command acceptance through typed [`Report`] values.
#[derive(Clone)]
pub struct Control {
    events: broadcast::Sender<Snapshot>,
    results: broadcast::Sender<Report>,
    devices: Devices,
    /// Last published snapshot, reused by endpoint-only refreshes.
    latest: Arc<Mutex<Snapshot>>,
}

/// How much of the audio state an event can have changed.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
enum Scope {
    /// Volume or mute on an existing device.
    Endpoints,
    /// Devices, cards or the default endpoint changed.
    Full,
}

impl Control {
    /// Bootstraps audio state and starts background refresh tasks.
    #[instrument(skip_all)]
    pub async fn bootstrap() -> (Handle, Snapshot) {
        let devices = Devices;
        let initial_snapshot = devices.read_snapshot().await.unwrap_or_else(|error| {
            tracing::warn!("Audio bootstrap failed: {error}");
            Snapshot::unavailable(error.to_string())
        });

        let (events, _) = broadcast::channel(32);
        let (results, _) = broadcast::channel(16);
        let control = Arc::new(Self {
            events,
            results,
            devices,
            latest: Arc::new(Mutex::new(initial_snapshot.clone())),
        });
        spawn_poll(Arc::clone(&control));
        spawn_event_watch(Arc::clone(&control));

        (control, initial_snapshot)
    }

    /// Subscribes to audio [`Snapshot`] updates.
    pub fn subscribe(&self) -> broadcast::Receiver<Snapshot> {
        self.events.subscribe()
    }

    /// Subscribes to audio command [`Report`] updates.
    pub fn subscribe_results(&self) -> broadcast::Receiver<Report> {
        self.results.subscribe()
    }

    /// Sets volume for an endpoint class.
    #[instrument(skip(self))]
    pub async fn set_volume(&self, kind: EndpointKind, volume: Percent) {
        let command = PublicCommand::SetVolume { kind, volume };
        let result = self.devices.set_volume(kind, volume).await;
        self.send_report(command, result);
        self.refresh(Scope::Endpoints).await;
    }

    /// Sets mute state for an endpoint class.
    #[instrument(skip(self))]
    pub async fn set_muted(&self, kind: EndpointKind, muted: bool) {
        let command = PublicCommand::SetMuted { kind, muted };
        let result = self.devices.set_muted(kind, muted).await;
        self.send_report(command, result);
        self.refresh(Scope::Endpoints).await;
    }

    /// Selects a playback device and publishes its confirmed default state.
    #[instrument(name = "audio::select_output", skip(self))]
    pub async fn select_output(&self, id: OutputId) {
        let result = self.devices.select_output(&id).await;
        self.send_report(PublicCommand::SelectOutput { id }, result);
        self.refresh(Scope::Full).await;
    }

    #[instrument(skip(self))]
    async fn refresh(&self, scope: Scope) {
        let snapshot = match scope {
            Scope::Full => self.devices.read_snapshot().await,
            Scope::Endpoints => {
                let previous = self.latest_snapshot();
                self.devices.read_endpoints_into(&previous).await
            }
        };
        self.send_snapshot(snapshot);
    }

    fn latest_snapshot(&self) -> Snapshot {
        self.latest.lock().map_or_else(
            |poisoned| poisoned.into_inner().clone(),
            |latest| latest.clone(),
        )
    }

    fn send_snapshot(&self, snapshot: Result<Snapshot, Error>) {
        let snapshot = snapshot.unwrap_or_else(|error| Snapshot::unavailable(error.to_string()));
        match self.latest.lock() {
            Ok(mut latest) => latest.clone_from(&snapshot),
            Err(poisoned) => poisoned.into_inner().clone_from(&snapshot),
        }
        drop(self.events.send(snapshot));
    }

    fn send_report(&self, command: PublicCommand, result: Result<(), Error>) {
        let report = match result {
            Ok(()) => Report::Started(command),
            Err(error) => Report::Failed {
                command,
                message: error.to_string(),
            },
        };
        drop(self.results.send(report));
    }
}

#[instrument(skip_all)]
fn spawn_poll(control: Handle) {
    tokio::spawn(async move {
        let mut ticker = interval(REFRESH_INTERVAL);
        loop {
            ticker.tick().await;
            let snapshot = control
                .devices
                .read_snapshot()
                .await
                .unwrap_or_else(|error| Snapshot::unavailable(error.to_string()));
            if snapshot != control.latest_snapshot() {
                control.send_snapshot(Ok(snapshot));
            }
        }
    });
}

#[instrument(skip_all)]
fn spawn_event_watch(control: Handle) {
    tokio::spawn(async move {
        let mut command = ProcessCommand::new("pactl");
        command
            .arg("subscribe")
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .kill_on_drop(true);
        let mut child = match command.spawn() {
            Ok(child) => child,
            Err(error) => {
                tracing::warn!("Audio event watch unavailable: {error}");
                return;
            }
        };

        let Some(stdout) = child.stdout.take() else {
            tracing::warn!("Audio event watch has no stdout");
            return;
        };
        let mut lines = BufReader::new(stdout).lines();
        loop {
            let scope = match lines.next_line().await {
                Ok(Some(line)) => match event_scope(&line) {
                    Some(scope) => scope,
                    None => continue,
                },
                Ok(None) => return,
                Err(error) => {
                    tracing::warn!("Audio event watch failed: {error}");
                    return;
                }
            };

            // A volume drag or a playing stream emits bursts of events. Fold
            // every line that lands inside the debounce window into a single
            // refresh instead of queueing one process round-trip per line.
            let deadline = Instant::now() + EVENT_DEBOUNCE;
            let mut scope = scope;
            let mut closed = false;
            loop {
                match timeout_at(deadline, lines.next_line()).await {
                    Err(_elapsed) => break,
                    Ok(Ok(Some(line))) => {
                        if let Some(next) = event_scope(&line) {
                            scope = scope.max(next);
                        }
                    }
                    Ok(Ok(None)) => {
                        closed = true;
                        break;
                    }
                    Ok(Err(error)) => {
                        tracing::warn!("Audio event watch failed: {error}");
                        closed = true;
                        break;
                    }
                }
            }
            control.refresh(scope).await;
            if closed {
                return;
            }
        }
    });
}

/// Classifies one `pactl subscribe` line.
///
/// Per-application streams (`sink-input`, `source-output`) and clients do not
/// touch the default endpoints or the device list, and a playing browser tab
/// emits them continuously, so they are ignored.
fn event_scope(line: &str) -> Option<Scope> {
    let target = line.split(" on ").nth(1)?.split_whitespace().next()?;
    match target {
        "sink" | "source" if line.contains("'change'") => Some(Scope::Endpoints),
        "sink" | "source" | "server" | "card" => Some(Scope::Full),
        _ => None,
    }
}

/// An audio runtime or boundary error.
#[derive(Debug, thiserror::Error)]
pub enum Error {
    /// An audio command exceeded its bounded execution time.
    #[error("`{program}` did not respond within five seconds")]
    Timeout {
        /// Program that timed out.
        program: String,
    },
    /// The requested output disappeared before it could be selected.
    #[error("the selected output device is no longer available")]
    OutputMissing,
    /// PipeWire returned malformed device metadata.
    #[error("could not read output devices: {0}")]
    ParseDevices(#[from] serde_json::Error),
    /// No default endpoint could be read.
    #[error("audio controls are unavailable")]
    Unavailable,
    /// A process could not be spawned.
    #[error("failed to launch `{program}`")]
    Spawn {
        /// Program that failed to spawn.
        program: String,
        /// Process spawn error.
        #[source]
        source: std::io::Error,
    },
    /// A process exited unsuccessfully.
    #[error("`{program}` failed with status {status}: {stderr}")]
    CommandFailed {
        /// Program that failed.
        program: String,
        /// Exit status as reported by the process boundary.
        status: String,
        /// Captured stderr.
        stderr: String,
    },
    /// A process returned invalid UTF-8.
    #[error("audio command returned invalid UTF-8")]
    Utf8(#[from] std::string::FromUtf8Error),
    /// The `wpctl get-volume` output did not match the expected shape.
    #[error("could not parse volume from `{output}`")]
    ParseVolume {
        /// Raw output that failed to parse.
        output: String,
    },
}

#[cfg(test)]
mod tests {
    use super::{Configuration, Scope, VolumeStep, event_scope};

    #[test]
    fn stream_events_do_not_refresh() {
        assert_eq!(event_scope("Event 'change' on sink-input #84"), None);
        assert_eq!(event_scope("Event 'new' on source-output #12"), None);
        assert_eq!(event_scope("Event 'change' on client #7"), None);
    }

    #[test]
    fn endpoint_changes_skip_device_discovery() {
        assert_eq!(
            event_scope("Event 'change' on sink #55"),
            Some(Scope::Endpoints)
        );
        assert_eq!(
            event_scope("Event 'change' on source #56"),
            Some(Scope::Endpoints)
        );
    }

    #[test]
    fn device_and_default_changes_refresh_everything() {
        assert_eq!(event_scope("Event 'new' on sink #90"), Some(Scope::Full));
        assert_eq!(
            event_scope("Event 'remove' on source #91"),
            Some(Scope::Full)
        );
        assert_eq!(
            event_scope("Event 'change' on server #-1"),
            Some(Scope::Full)
        );
        assert_eq!(event_scope("Event 'change' on card #3"), Some(Scope::Full));
    }

    #[test]
    fn config_defaults_volume_step_to_five_percent() {
        assert_eq!(Configuration::default().volume_step().as_u8(), 5);
    }

    #[test]
    fn config_accepts_custom_volume_step() {
        let config =
            toml::from_str::<Configuration>("volume_step = 17").expect("volume step should parse");

        assert_eq!(config.volume_step().as_u8(), 17);
    }

    #[test]
    fn volume_step_clamps_to_percentage_bounds() {
        let below = toml::from_str::<Configuration>("volume_step = -1")
            .expect("negative volume step should clamp");
        let above = toml::from_str::<Configuration>("volume_step = 101")
            .expect("large volume step should clamp");

        assert_eq!(below.volume_step(), VolumeStep::new(0));
        assert_eq!(above.volume_step(), VolumeStep::new(100));
    }
}
