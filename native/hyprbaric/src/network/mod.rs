//! Network status, traffic polling, and Wi-Fi commands.
//!
//! [`Wifi`] owns the runtime boundary that Flutter talks to. It publishes
//! [`Snapshot`] values, reports command outcomes through [`Report`], and
//! keeps the last traffic sample available to both full NetworkManager refreshes
//! and cheaper counter-only ticks.
//!
//! Network shape and UI-facing state live in the domain module. NetworkManager,
//! `/proc` counters, and external settings applications stay in boundary
//! modules so the public runtime does not need to coordinate raw system data.

mod domain;

pub use domain::{Join, Security};
mod settings;
mod signal;
mod traffic;
mod wireless;

use std::{sync::Arc, time::Instant};

use serde::Deserialize;
use tokio::{
    sync::{Mutex, broadcast},
    time::interval,
};
use tracing::instrument;

use crate::config::Cadence;

pub use domain::{EntryState, Snapshot, Traffic};

/// A shared handle to live network state.
pub type Handle = Arc<Wifi>;

/// Network polling policy loaded from Hyprbaric configuration.
///
/// Defaults keep traffic counters lively while leaving NetworkManager reads at
/// a calmer cadence. Configuration accepts human-readable intervals:
///
/// ```toml
/// [network]
/// traffic_refresh_interval = "750ms"
/// full_refresh_interval = "12s"
/// ```
#[derive(Clone, Debug, Deserialize)]
#[serde(default)]
pub struct Configuration {
    traffic_refresh_interval: Cadence,
    full_refresh_interval: Cadence,
}

impl Default for Configuration {
    fn default() -> Self {
        Self {
            traffic_refresh_interval: Cadence::seconds(1),
            full_refresh_interval: Cadence::seconds(8),
        }
    }
}

/// Live Wi-Fi status and command delivery.
///
/// [`Wifi`] deliberately separates a cheap traffic tick from a full
/// NetworkManager refresh. The full refresh provides access points, interface
/// state, and current Wi-Fi status; the traffic tick keeps transfer rates lively
/// between those heavier reads.
pub struct Wifi {
    events: broadcast::Sender<Snapshot>,
    results: broadcast::Sender<Report>,
    counters: Mutex<Option<traffic::Sample>>,
    /// Serializes reads and holds the latest confirmed connection facts.
    snapshot: Mutex<Snapshot>,
    wireless: wireless::Client,
}

/// A network command that reached a system boundary.
///
/// Commands keep the useful context for their own variant instead of requiring
/// reports to coordinate a command kind with optional side fields.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Command {
    /// Ask NetworkManager to scan visible access points.
    Scan,
    /// Enable or disable Wi-Fi radio support.
    SetWifiEnabled {
        /// The Wi-Fi state requested by the UI.
        enabled: bool,
    },
    /// Connect to one visible Wi-Fi network.
    Connect {
        /// The display SSID that received the connection request.
        ssid: String,
    },
    /// Open a system network settings application.
    OpenSettings,
    /// Disconnect a single interface.
    Disconnect { interface: String },
    /// Set a Wi-Fi interface's automatic connection policy.
    SetAutoConnect { interface: String, enabled: bool },
}

/// A network command report published to subscribers.
///
/// Failure detail can only exist on [`Report::Failed`], while a successful
/// report carries the exact [`Command`] that started.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Report {
    /// The command reached its system boundary.
    Started(Command),
    /// The command failed before that boundary accepted it.
    Failed {
        /// The command that could not be started.
        command: Command,
        /// A user-facing failure detail.
        message: String,
    },
}

impl Wifi {
    /// Bootstraps live network state and starts background refreshes.
    #[instrument(skip_all)]
    pub async fn bootstrap(config: &Configuration) -> (Handle, Snapshot) {
        let wireless = wireless::Client::new();
        let initial = wireless.read_snapshot(wireless::Scan::Idle, None).await;
        let initial_sample = initial.as_ref().ok().map(|(_, sample)| sample.clone());
        let initial_snapshot = initial
            .map(|(snapshot, _)| snapshot)
            .unwrap_or_else(|error| {
                tracing::warn!("Network bootstrap failed: {error}");
                Snapshot::unavailable(error.to_string())
            });

        let (events, _) = broadcast::channel(32);
        let (results, _) = broadcast::channel(16);
        let wifi = Arc::new(Self {
            events,
            results,
            counters: Mutex::new(initial_sample),
            snapshot: Mutex::new(initial_snapshot.clone()),
            wireless,
        });
        spawn_poll(Arc::clone(&wifi), config.clone());

        (wifi, initial_snapshot)
    }

    /// Subscribes to network [`Snapshot`] changes.
    pub fn subscribe(&self) -> broadcast::Receiver<Snapshot> {
        self.events.subscribe()
    }

    /// Subscribes to network command results.
    pub fn subscribe_results(&self) -> broadcast::Receiver<Report> {
        self.results.subscribe()
    }

    /// Starts a Wi-Fi scan and refreshes the visible network snapshot.
    #[instrument(skip(self))]
    pub async fn scan(&self) {
        self.refresh(wireless::Scan::Requested).await;
        self.send_report(Command::Scan, self.wireless.scan().await);
        self.refresh(wireless::Scan::Idle).await;
    }

    /// Enables or disables Wi-Fi through NetworkManager.
    #[instrument(skip(self))]
    pub async fn set_wifi_enabled(&self, enabled: bool) {
        self.send_report(
            Command::SetWifiEnabled { enabled },
            self.wireless.set_enabled(enabled).await,
        );
        self.refresh(wireless::Scan::Idle).await;
    }

    /// Connects to a visible Wi-Fi network.
    #[instrument(skip(self, password), fields(ssid = %ssid))]
    pub async fn connect(&self, ssid: String, bssid: Option<String>, password: Option<String>) {
        let request = wireless::Connect::new(ssid, bssid, password);
        let ssid = request.ssid().to_owned();

        self.send_report(
            Command::Connect { ssid },
            self.wireless.connect(request).await,
        );
        self.refresh(wireless::Scan::Idle).await;
    }

    /// Disconnects an interface and publishes its refreshed state.
    #[instrument(name = "network::disconnect_request", skip(self))]
    pub async fn disconnect(&self, interface: String) {
        let outcome = self.wireless.disconnect(&interface).await;
        self.send_report(Command::Disconnect { interface }, outcome);
        self.refresh(wireless::Scan::Idle).await;
    }

    /// Changes Wi-Fi autoconnect policy and publishes its refreshed state.
    #[instrument(name = "network::auto_connect_request", skip(self))]
    pub async fn set_auto_connect(&self, interface: String, enabled: bool) {
        let outcome = self.wireless.set_auto_connect(&interface, enabled).await;
        self.send_report(Command::SetAutoConnect { interface, enabled }, outcome);
        self.refresh(wireless::Scan::Idle).await;
    }

    /// Creates and activates an explicitly named Wi-Fi profile.
    #[instrument(name = "network::join", skip(self, request), fields(ssid = %request.ssid))]
    pub async fn join(&self, request: Join) {
        let command = Command::Connect {
            ssid: request.ssid.clone(),
        };
        self.send_report(command, self.wireless.join(request).await);
        self.refresh(wireless::Scan::Idle).await;
    }

    /// Opens the first available system network settings application.
    #[instrument(skip(self))]
    pub async fn open_settings(&self) {
        self.send_report(Command::OpenSettings, settings::open());
    }

    /// Publishes a fresh NetworkManager-backed snapshot.
    async fn refresh(&self, scan: wireless::Scan) {
        let mut current = self.snapshot.lock().await;
        let snapshot = self.read_snapshot(scan).await;
        self.publish(&mut current, snapshot);
    }

    /// Reads a full snapshot and advances the shared traffic counter baseline.
    async fn read_snapshot(&self, scan: wireless::Scan) -> Result<Snapshot, Error> {
        let previous = self.counters.lock().await.clone();
        let (snapshot, sample) = self.wireless.read_snapshot(scan, previous.as_ref()).await?;
        *self.counters.lock().await = Some(sample);
        Ok(snapshot)
    }

    /// Reads a traffic-only update and advances the counter baseline.
    async fn read_traffic(&self, ping_ms: Option<u16>) -> Result<Traffic, Error> {
        let previous = self.counters.lock().await.clone();
        let (traffic, sample) = traffic::read(previous.as_ref(), ping_ms)?;
        *self.counters.lock().await = Some(sample);
        Ok(traffic)
    }

    /// Publishes a snapshot, degrading failed reads into unavailable status.
    fn publish(&self, current: &mut Snapshot, snapshot: Result<Snapshot, Error>) {
        *current = snapshot.unwrap_or_else(|error| Snapshot::unavailable(error.to_string()));
        drop(self.events.send(current.clone()));
    }

    /// Publishes a typed command report for a system boundary result.
    fn send_report(&self, command: Command, result: Result<(), Error>) {
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

/// Starts periodic full and traffic-only network refreshes.
#[instrument(skip_all)]
fn spawn_poll(wifi: Handle, config: Configuration) {
    tokio::spawn(async move {
        let mut ticker = interval(config.traffic_refresh_interval.duration());
        let mut last_full_refresh = Instant::now();
        ticker.tick().await;

        loop {
            ticker.tick().await;
            // Command refreshes share this guard, so a traffic tick cannot
            // restore connection facts captured before a completed action.
            let mut current = wifi.snapshot.lock().await;
            let snapshot = if last_full_refresh.elapsed() >= config.full_refresh_interval.duration()
            {
                last_full_refresh = Instant::now();
                wifi.read_snapshot(wireless::Scan::Idle)
                    .await
                    .unwrap_or_else(|error| Snapshot::unavailable(error.to_string()))
            } else {
                match wifi.read_traffic(current.traffic.ping_ms).await {
                    Ok(traffic) => Snapshot {
                        traffic,
                        scanning: false,
                        ..current.clone()
                    },
                    Err(error) => Snapshot::unavailable(error.to_string()),
                }
            };

            // Every tick is an observation, including a repeated zero rate.
            // Dropping identical snapshots would erase idle time from history.
            wifi.publish(&mut current, Ok(snapshot));
        }
    });
}

/// A network runtime or boundary error.
#[derive(Debug, thiserror::Error)]
pub enum Error {
    /// NetworkManager could not serve a Wi-Fi operation.
    #[error("NetworkManager is unavailable: {0}")]
    NetworkManager(#[source] nmrs::ConnectionError),
    /// `/proc` traffic counters could not be read.
    #[error("network counters are unavailable: {0}")]
    Counters(#[source] std::io::Error),
    /// A visible network disappeared before a connect request used it.
    #[error("network `{ssid}` is no longer visible")]
    NetworkNotFound { ssid: String },
    /// A secured network connect request omitted its secret.
    #[error("this network requires a password")]
    MissingPassword,
    /// Enterprise Wi-Fi needs the user's network settings application for now.
    #[error(
        "enterprise Wi-Fi is not supported in Hyprbaric yet; open Network settings to connect to `{ssid}`"
    )]
    UnsupportedEnterprise { ssid: String },
    /// No supported network settings application could be launched.
    #[error("no known network settings application is available")]
    SettingsUnavailable,
    /// SSIDs contain between one and 32 bytes.
    #[error("network name must contain 1–32 UTF-8 bytes")]
    InvalidNetworkName,
    /// The personal network key does not meet the WPA-PSK format.
    #[error("use 8–63 ASCII characters or a 64-digit hexadecimal key")]
    InvalidPersonalKey,
    /// The requested interface disappeared before the operation reached it.
    #[error("network interface `{interface}` is no longer available")]
    InterfaceNotFound { interface: String },
    /// NetworkManager rejected a device-scoped D-Bus operation.
    #[error("could not change the network interface: {0}")]
    DeviceAccess(#[source] zbus::Error),
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use super::Configuration;

    #[test]
    fn config_accepts_human_refresh_cadences() {
        let config = toml::from_str::<Configuration>(
            r#"
            traffic_refresh_interval = "250ms"
            full_refresh_interval = "15s"
            "#,
        )
        .expect("network config should parse human refresh cadences");

        assert_eq!(
            config.traffic_refresh_interval.duration(),
            Duration::from_millis(250)
        );
        assert_eq!(
            config.full_refresh_interval.duration(),
            Duration::from_secs(15)
        );
    }

    #[test]
    fn config_rejects_zero_refresh_cadences() {
        let error = toml::from_str::<Configuration>(
            r#"
            traffic_refresh_interval = "0s"
            "#,
        )
        .expect_err("zero network refresh cadences should not deserialize");

        assert!(error.to_string().contains("cadence cannot be zero"));
    }
}
