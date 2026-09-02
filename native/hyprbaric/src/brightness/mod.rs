//! Brightness runtime.
//!
//! The public surface is intentionally small: [`Brightness`] accepts typed
//! [`Command`] requests through methods, publishes [`Snapshot`] updates, and
//! reports command progress as [`Report`]. Backend details stay below this
//! module boundary so Flutter and RINF only see the brightness vocabulary.

mod backend;
mod domain;
mod registry;
mod signal;

use std::{collections::HashMap, process::ExitStatus, sync::Arc, time::Duration};

use serde::Deserialize;
use tokio::{
    sync::{broadcast, mpsc},
    time::{MissedTickBehavior, interval, sleep, timeout},
};
use tracing::instrument;

use crate::config::Cadence;

use self::{
    backend::Controller,
    domain::{Command as PublicCommand, Device, DeviceId, DeviceKind, Target},
    registry::Registry,
};

pub use domain::{Command, Percent, Report, Snapshot};

/// Shared brightness runtime handle.
pub type Handle = Arc<Brightness>;

const DDC_BRIGHTNESS_VCP: &str = "10";

/// Brightness polling and DDC write policy loaded from Hyprbaric configuration.
///
/// Defaults keep Linux backlight reads cheap and frequent, while DDC discovery
/// stays delayed and conservative:
///
/// ```toml
/// [brightness]
/// backlight_refresh_interval = "1s"
/// ddc_discovery_delay = "1s"
/// # Optional: repeat DDC discovery when displays may be hot-plugged.
/// # ddc_discovery_interval = "15m"
/// ddc_write_debounce = "300ms"
/// ddc_command_timeout = "1200ms"
/// # Backstop for a backend write that never returns.
/// write_timeout = "5s"
/// ```
#[derive(Clone, Debug, Deserialize)]
#[serde(default)]
pub struct Configuration {
    backlight_refresh_interval: Cadence,
    ddc_discovery_delay: Cadence,
    ddc_discovery_interval: Option<Cadence>,
    ddc_write_debounce: Cadence,
    ddc_command_timeout: Cadence,
    write_timeout: Cadence,
}

impl Default for Configuration {
    fn default() -> Self {
        Self {
            backlight_refresh_interval: Cadence::seconds(1),
            ddc_discovery_delay: Cadence::seconds(1),
            ddc_discovery_interval: None,
            ddc_write_debounce: Cadence::milliseconds(300),
            ddc_command_timeout: Cadence::milliseconds(1200),
            write_timeout: Cadence::seconds(5),
        }
    }
}

impl Configuration {
    pub(super) const fn ddc_command_timeout(&self) -> Duration {
        self.ddc_command_timeout.duration()
    }
}

/// Actor-backed brightness subsystem.
///
/// [`Brightness`] keeps discovery, optimistic updates, debounced DDC writes,
/// and polling behind a compact handle. Callers subscribe to [`Snapshot`] and
/// [`Report`] streams rather than reaching into backend state.
#[derive(Clone)]
pub struct Brightness {
    commands: mpsc::Sender<Work>,
    events: broadcast::Sender<Snapshot>,
    results: broadcast::Sender<Report>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum DiscoveryMode {
    Backlight,
    Ddc,
}

#[derive(Debug)]
enum Work {
    Discover(DiscoveryMode),
    PollBacklight,
    DiscoveryFinished(DiscoveryMode, Result<Vec<Device>, Error>),
    Set(Target, Percent),
    WriteReady {
        device_id: DeviceId,
        generation: u64,
    },
    WriteFinished {
        device_id: DeviceId,
        generation: u64,
        command: PublicCommand,
        result: Result<(), Error>,
    },
    Resync(DeviceId),
    ResyncFinished(Result<Device, Error>),
}

/// The latest value waiting to cross one brightness backend boundary.
#[derive(Clone, Debug)]
struct WriteRequest {
    device: Device,
    value: Percent,
}

/// Per-device write lifecycle used to serialize and coalesce hardware access.
///
/// A device holds at most one open debounce window and at most one active
/// backend write. Newer values always replace the value already held, so the
/// window keeps its original deadline instead of restarting: latency stays
/// bounded by one debounce even while the user is dragging.
#[derive(Debug)]
enum WriteState {
    /// The debounce window is open and holds the newest value seen.
    Waiting {
        generation: u64,
        request: WriteRequest,
    },
    /// One backend write is active and at most one newer value is retained.
    Running {
        generation: u64,
        next: Option<WriteRequest>,
    },
}

impl WriteState {
    const fn waiting(generation: u64, request: WriteRequest) -> Self {
        Self::Waiting {
            generation,
            request,
        }
    }

    /// Replaces the value this device is holding, whichever phase it is in.
    fn queue(&mut self, request: WriteRequest) {
        match self {
            Self::Waiting { request: held, .. } => *held = request,
            Self::Running { next, .. } => *next = Some(request),
        }
    }

    /// Takes the held value when `generation` still owns the debounce window.
    fn begin(&mut self, generation: u64) -> Option<WriteRequest> {
        let Self::Waiting {
            generation: waiting,
            request,
        } = self
        else {
            return None;
        };
        if *waiting != generation {
            return None;
        }

        let request = request.clone();
        *self = Self::Running {
            generation,
            next: None,
        };
        Some(request)
    }

    fn finish(self, generation: u64) -> Result<Option<WriteRequest>, Self> {
        match self {
            Self::Running {
                generation: running,
                next,
            } if running == generation => Ok(next),
            state @ (Self::Waiting { .. } | Self::Running { .. }) => Err(state),
        }
    }
}

#[derive(Default)]
struct Running {
    backlight: bool,
    ddc: bool,
}

struct Actor {
    controller: Controller,
    commands: mpsc::Sender<Work>,
    events: broadcast::Sender<Snapshot>,
    results: broadcast::Sender<Report>,
    registry: Registry,
    config: Configuration,
    snapshot: Snapshot,
    running: Running,
    writes: HashMap<DeviceId, WriteState>,
    next_generation: u64,
    last_error: Option<String>,
}

impl Brightness {
    /// Starts the brightness worker and returns its handle plus initial
    /// [`Snapshot`].
    ///
    /// The initial snapshot is always emitted synchronously so the UI can render
    /// a deterministic discovering state before system backends respond.
    #[instrument(skip_all)]
    pub async fn bootstrap(config: &Configuration) -> (Handle, Snapshot) {
        let initial_snapshot = Snapshot::discovering("Discovering brightness devices");
        let (commands, command_rx) = mpsc::channel(32);
        let (events, _) = broadcast::channel(16);
        let (results, _) = broadcast::channel(8);
        let brightness = Arc::new(Self {
            commands: commands.clone(),
            events: events.clone(),
            results: results.clone(),
        });

        Actor::spawn(
            Controller::new(config),
            commands,
            command_rx,
            events,
            results,
            config.clone(),
            initial_snapshot.clone(),
        );

        (brightness, initial_snapshot)
    }

    /// Subscribes to UI-facing [`Snapshot`] updates.
    pub fn subscribe(&self) -> broadcast::Receiver<Snapshot> {
        self.events.subscribe()
    }

    /// Subscribes to command [`Report`] updates.
    pub fn subscribe_results(&self) -> broadcast::Receiver<Report> {
        self.results.subscribe()
    }

    /// Sets brightness for the currently selected target.
    ///
    /// The worker applies the value optimistically before writing to the
    /// backend. A backend failure is reported later and triggers a resync.
    #[instrument(skip(self))]
    pub async fn set_level(&self, value: Percent) {
        if self
            .commands
            .send(Work::Set(Target::Selected, value))
            .await
            .is_err()
        {
            let _ = self.results.send(Report::Failed {
                command: PublicCommand::SetLevel { value },
                message: "Brightness worker is not running".to_owned(),
            });
        }
    }
}

impl Actor {
    #[instrument(skip_all)]
    fn spawn(
        controller: Controller,
        commands: mpsc::Sender<Work>,
        mut command_rx: mpsc::Receiver<Work>,
        events: broadcast::Sender<Snapshot>,
        results: broadcast::Sender<Report>,
        config: Configuration,
        initial_snapshot: Snapshot,
    ) {
        spawn_timers(commands.clone(), config.clone());
        tokio::spawn(async move {
            let mut actor = Self {
                controller,
                commands: commands.clone(),
                events,
                results,
                registry: Registry::default(),
                config,
                snapshot: initial_snapshot,
                running: Running::default(),
                writes: HashMap::new(),
                next_generation: 0,
                last_error: None,
            };
            actor.start_discovery(DiscoveryMode::Backlight);

            while let Some(command) = command_rx.recv().await {
                actor.apply(command);
            }
        });
    }

    #[instrument(skip(self))]
    fn apply(&mut self, command: Work) {
        match command {
            Work::Discover(mode) => self.start_discovery(mode),
            Work::PollBacklight => self.start_discovery(DiscoveryMode::Backlight),
            Work::DiscoveryFinished(mode, result) => self.finish_discovery(mode, result),
            Work::Set(target, value) => self.set(target, value),
            Work::WriteReady {
                device_id,
                generation,
            } => self.start_write(device_id, generation),
            Work::WriteFinished {
                device_id,
                generation,
                command,
                result,
            } => self.finish_write(device_id, generation, command, result),
            Work::Resync(device_id) => self.start_resync(device_id),
            Work::ResyncFinished(result) => self.finish_resync(result),
        }
    }

    #[instrument(skip(self))]
    fn start_discovery(&mut self, mode: DiscoveryMode) {
        let running = match mode {
            DiscoveryMode::Backlight => &mut self.running.backlight,
            DiscoveryMode::Ddc => &mut self.running.ddc,
        };
        if *running {
            return;
        }
        *running = true;

        let controller = self.controller.clone();
        let commands = self.commands.clone();
        tokio::spawn(async move {
            let result = match mode {
                DiscoveryMode::Backlight => controller.discover_backlight().await,
                DiscoveryMode::Ddc => controller.discover_ddc().await,
            };
            let _ = commands.send(Work::DiscoveryFinished(mode, result)).await;
        });
    }

    #[instrument(skip(self, result))]
    fn finish_discovery(&mut self, mode: DiscoveryMode, result: Result<Vec<Device>, Error>) {
        match mode {
            DiscoveryMode::Backlight => self.running.backlight = false,
            DiscoveryMode::Ddc => self.running.ddc = false,
        }

        match result {
            Ok(devices) => {
                let kind = match mode {
                    DiscoveryMode::Backlight => DeviceKind::Backlight,
                    DiscoveryMode::Ddc => DeviceKind::DdcCi,
                };
                self.registry.replace_kind(kind, devices);
                self.last_error = None;
            }
            Err(error) => {
                if self.registry.is_empty() {
                    self.last_error = Some(error.to_string());
                }
            }
        }
        self.publish();
    }

    #[instrument(skip(self))]
    fn set(&mut self, target: Target, value: Percent) {
        match self.registry.set_optimistic(target, value) {
            Ok(device) => {
                self.send_command(PublicCommand::SetLevel { value }, Ok(()));
                self.publish();
                self.schedule_write(device, value);
            }
            Err(error) => {
                self.send_command(PublicCommand::SetLevel { value }, Err(error));
            }
        }
    }

    #[instrument(skip(self))]
    fn schedule_write(&mut self, device: Device, value: Percent) {
        let request = WriteRequest { device, value };
        let device_id = request.device.id.clone();

        if let Some(state) = self.writes.get_mut(&device_id) {
            state.queue(request);
            return;
        }

        self.next_generation = self.next_generation.wrapping_add(1);
        let generation = self.next_generation;
        let delay = match request.device.kind {
            DeviceKind::Backlight => Duration::ZERO,
            DeviceKind::DdcCi => self.config.ddc_write_debounce.duration(),
        };
        self.writes
            .insert(device_id.clone(), WriteState::waiting(generation, request));

        let commands = self.commands.clone();
        tokio::spawn(async move {
            if !delay.is_zero() {
                sleep(delay).await;
            }
            drop(
                commands
                    .send(Work::WriteReady {
                        device_id,
                        generation,
                    })
                    .await,
            );
        });
    }

    #[instrument(skip(self))]
    fn start_write(&mut self, device_id: DeviceId, generation: u64) {
        let Some(state) = self.writes.get_mut(&device_id) else {
            return;
        };
        let Some(request) = state.begin(generation) else {
            return;
        };

        let controller = self.controller.clone();
        let commands = self.commands.clone();
        let watchdog = self.config.write_timeout.duration();
        tokio::spawn(async move {
            let command = PublicCommand::SetLevel {
                value: request.value,
            };
            // A backend that never returns would otherwise pin this device in
            // `Running` forever, silently swallowing every later write.
            let result = match timeout(
                watchdog,
                controller.set_brightness(&request.device, request.value),
            )
            .await
            {
                Ok(result) => result,
                Err(_) => Err(Error::CommandTimedOut {
                    program: request.device.kind.backend_name(),
                    timeout: watchdog,
                }),
            };
            drop(
                commands
                    .send(Work::WriteFinished {
                        device_id,
                        generation,
                        command,
                        result,
                    })
                    .await,
            );
        });
    }

    #[instrument(skip(self, result))]
    fn finish_write(
        &mut self,
        device_id: DeviceId,
        generation: u64,
        command: PublicCommand,
        result: Result<(), Error>,
    ) {
        let next = match self
            .writes
            .remove(&device_id)
            .map(|state| state.finish(generation))
        {
            Some(Ok(next)) => next,
            Some(Err(state)) => {
                self.writes.insert(device_id.clone(), state);
                return;
            }
            None => return,
        };

        if let Err(error) = result {
            self.send_command(command, Err(error));
            if next.is_none() {
                // A dropped resync would strand the optimistic value, so wait
                // for capacity off-actor rather than discarding it.
                let commands = self.commands.clone();
                tokio::spawn(async move {
                    drop(commands.send(Work::Resync(device_id)).await);
                });
            }
        }

        if let Some(next) = next {
            self.schedule_write(next.device, next.value);
        }
    }

    #[instrument(skip(self))]
    fn start_resync(&mut self, device_id: DeviceId) {
        let Some(device) = self.registry.device(&device_id).cloned() else {
            return;
        };
        let controller = self.controller.clone();
        let commands = self.commands.clone();
        tokio::spawn(async move {
            let result = controller.read_device(&device).await;
            let _ = commands.send(Work::ResyncFinished(result)).await;
        });
    }

    #[instrument(skip(self, result))]
    fn finish_resync(&mut self, result: Result<Device, Error>) {
        match result {
            Ok(device) => {
                self.registry.upsert(device);
                self.last_error = None;
            }
            Err(error) => {
                if self.registry.is_empty() {
                    self.last_error = Some(error.to_string());
                }
            }
        }
        self.publish();
    }

    fn publish(&mut self) {
        let snapshot = self.registry.snapshot(self.last_error.as_deref());
        if snapshot == self.snapshot {
            return;
        }
        self.snapshot = snapshot.clone();
        let _ = self.events.send(snapshot);
    }

    fn send_command(&self, command: PublicCommand, result: Result<(), Error>) {
        let command_result = match result {
            Ok(()) => Report::Started(command),
            Err(error) => Report::Failed {
                command,
                message: error.to_string(),
            },
        };
        let _ = self.results.send(command_result);
    }
}

#[instrument(skip_all)]
fn spawn_timers(commands: mpsc::Sender<Work>, config: Configuration) {
    let backlight_commands = commands.clone();
    let backlight_refresh_interval = config.backlight_refresh_interval.duration();
    tokio::spawn(async move {
        let mut ticker = interval(backlight_refresh_interval);
        ticker.set_missed_tick_behavior(MissedTickBehavior::Skip);
        loop {
            ticker.tick().await;
            if backlight_commands.send(Work::PollBacklight).await.is_err() {
                break;
            }
        }
    });

    let ddc_discovery_delay = config.ddc_discovery_delay.duration();
    let ddc_discovery_interval = config
        .ddc_discovery_interval
        .map(|cadence| cadence.duration());
    tokio::spawn(async move {
        sleep(ddc_discovery_delay).await;
        if commands
            .send(Work::Discover(DiscoveryMode::Ddc))
            .await
            .is_err()
        {
            return;
        }

        let Some(ddc_discovery_interval) = ddc_discovery_interval else {
            return;
        };

        let mut ticker = interval(ddc_discovery_interval);
        ticker.set_missed_tick_behavior(MissedTickBehavior::Skip);
        ticker.tick().await;
        loop {
            ticker.tick().await;
            if commands
                .send(Work::Discover(DiscoveryMode::Ddc))
                .await
                .is_err()
            {
                break;
            }
        }
    });
}

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("no brightness device is available")]
    NoDevice,
    #[error("{backend} brightness backend is unsupported")]
    Unsupported { backend: &'static str },
    #[error("{backend} brightness backend needs additional permissions: {message}")]
    PermissionDenied {
        backend: &'static str,
        message: String,
    },
    #[error("brightness device `{device}` is unavailable")]
    DeviceUnavailable { device: String },
    #[error("{backend} brightness backend failed: {message}")]
    BackendFailed {
        backend: &'static str,
        message: String,
    },
    #[error("failed to run {program}")]
    Command {
        program: &'static str,
        #[source]
        source: std::io::Error,
    },
    #[error("{program} timed out after {timeout:?}")]
    CommandTimedOut {
        program: &'static str,
        timeout: Duration,
    },
    #[error("{program} exited with {status}: {stderr}")]
    CommandFailed {
        program: &'static str,
        status: ExitStatus,
        stderr: String,
    },
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use super::{Configuration, WriteRequest, WriteState};
    use crate::brightness::domain::{Device, DeviceId, DeviceKind, Percent};

    fn ddc_request(value: u8) -> WriteRequest {
        WriteRequest {
            device: Device {
                id: DeviceId::ddc("5", "display"),
                label: "Display".to_owned(),
                kind: DeviceKind::DdcCi,
                value: Percent::new(value),
            },
            value: Percent::new(value),
        }
    }

    #[test]
    fn stale_debounce_generation_cannot_start_a_write() {
        let mut state = WriteState::waiting(2, ddc_request(10));

        assert!(state.begin(1).is_none());
        assert!(state.begin(2).is_some());
    }

    #[test]
    fn debounce_window_coalesces_without_restarting() {
        let mut state = WriteState::waiting(1, ddc_request(10));

        state.queue(ddc_request(40));
        state.queue(ddc_request(80));

        // The original generation still owns the window, so the timer armed for
        // the first value is the one that fires: a sustained drag cannot push
        // the write past its deadline.
        let request = state
            .begin(1)
            .expect("original generation should still own the window");
        assert_eq!(request.value, Percent::new(80));
    }

    #[test]
    fn running_write_retains_only_the_latest_value() {
        let mut state = WriteState::waiting(1, ddc_request(10));
        assert!(state.begin(1).is_some());

        state.queue(ddc_request(40));
        state.queue(ddc_request(80));

        let next = state
            .finish(1)
            .expect("running generation should finish")
            .expect("latest write should remain queued");
        assert_eq!(next.value, Percent::new(80));
    }

    #[test]
    fn finished_write_without_a_successor_leaves_nothing_queued() {
        let mut state = WriteState::waiting(3, ddc_request(55));
        assert!(state.begin(3).is_some());

        assert!(
            state
                .finish(3)
                .expect("running generation should finish")
                .is_none()
        );
    }

    #[test]
    fn config_accepts_human_brightness_timings() {
        let config = toml::from_str::<Configuration>(
            r#"
            backlight_refresh_interval = "750ms"
            ddc_discovery_delay = "2s"
            ddc_discovery_interval = "45s"
            ddc_write_debounce = "250ms"
            ddc_command_timeout = "1500ms"
            "#,
        )
        .expect("brightness config should parse human timings");

        assert_eq!(
            config.backlight_refresh_interval.duration(),
            Duration::from_millis(750)
        );
        assert_eq!(
            config.ddc_discovery_delay.duration(),
            Duration::from_secs(2)
        );
        assert_eq!(
            config
                .ddc_discovery_interval
                .expect("configured DDC interval should be present")
                .duration(),
            Duration::from_secs(45)
        );
        assert_eq!(
            config.ddc_write_debounce.duration(),
            Duration::from_millis(250)
        );
        assert_eq!(
            config.ddc_command_timeout.duration(),
            Duration::from_millis(1500)
        );
    }

    #[test]
    fn config_rejects_zero_brightness_timings() {
        let error = toml::from_str::<Configuration>(
            r#"
            backlight_refresh_interval = "0s"
            "#,
        )
        .expect_err("zero brightness timings should not deserialize");

        assert!(error.to_string().contains("cadence cannot be zero"));
    }

    #[test]
    fn config_disables_periodic_ddc_discovery_by_default() {
        assert_eq!(Configuration::default().ddc_discovery_interval, None);
    }
}
