//! System occupancy telemetry for the bar.
//!
//! [`Monitor`] reads CPU, memory, disk, uptime, temperature, and process
//! counts from Linux host files. Domain types live in [`domain`]; `/proc` and
//! `statvfs` stay in [`host`]. The host keeps one selected temperature input
//! between observations and periodically rediscovers sensors. RINF projections
//! live in [`signal`].
//!
//! ```text
//! Monitor --poll--> host::{cpu,memory,disk,...} --parse--> Snapshot
//!                                               |
//!                                               +--> Trace (rolling occupancy)
//! ```

mod domain;
mod host;
mod signal;

use std::{sync::Arc, time::Duration};

use serde::Deserialize;
use tokio::{
    sync::{Mutex, broadcast},
    time::{MissedTickBehavior, interval, sleep},
};
use tracing::instrument;

use crate::config::Cadence;

use self::host::{Thermometer, Tick};

pub use domain::{Bytes, Celsius, Cpu, Disk, Memory, Percent, Snapshot, Trace, Usage};

/// Shared system occupancy handle.
pub type Handle = Arc<Monitor>;

const FIRST_SAMPLE: Duration = Duration::from_millis(80);

/// System occupancy polling policy.
///
/// ```toml
/// [system]
/// refresh_interval = "1s"
/// ```
#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(default)]
pub struct Configuration {
    refresh_interval: Cadence,
}

impl Default for Configuration {
    fn default() -> Self {
        Self {
            refresh_interval: Cadence::seconds(1),
        }
    }
}

/// Live system occupancy state.
pub struct Monitor {
    events: broadcast::Sender<Snapshot>,
    latest: Mutex<State>,
}

/// Last published values and host sampling state for one monitor.
struct State {
    /// Last snapshot delivered to subscribers.
    last: Snapshot,
    /// Previous aggregate CPU counter for delta calculation.
    tick: Option<Tick>,
    /// Selected temperature source, shared across observations.
    thermometer: Thermometer,
}

impl Monitor {
    /// Bootstraps occupancy and starts background refreshes.
    #[instrument(name = "system::monitor::bootstrap", skip_all)]
    pub async fn bootstrap(config: &Configuration) -> (Handle, Snapshot) {
        let first_tick = host::cpu_tick()
            .inspect_err(|error| {
                tracing::warn!(%error, "Initial CPU tick is unavailable");
            })
            .ok();
        sleep(FIRST_SAMPLE).await;
        let mut thermometer = Thermometer::default();
        let (initial, tick) = observe(
            first_tick,
            Cpu::measuring(),
            Trace::empty(),
            &mut thermometer,
        );

        let (events, _) = broadcast::channel(16);
        let monitor = Arc::new(Self {
            events,
            latest: Mutex::new(State {
                tick,
                thermometer,
                last: initial.clone(),
            }),
        });
        spawn_poll(Arc::clone(&monitor), config.refresh_interval.duration());

        (monitor, initial)
    }

    /// Subscribes to occupancy [`Snapshot`] changes.
    pub fn subscribe(&self) -> broadcast::Receiver<Snapshot> {
        self.events.subscribe()
    }

    #[instrument(name = "system::monitor::refresh", skip(self))]
    async fn refresh(&self) {
        let mut state = self.latest.lock().await;
        let (cpu, memory_history) = match &state.last {
            Snapshot::Ready { cpu, memory, .. } => (cpu.clone(), memory.history.clone()),
            Snapshot::Unavailable { .. } => (Cpu::measuring(), Trace::empty()),
        };
        let (snapshot, tick) = observe(state.tick, cpu, memory_history, &mut state.thermometer);

        if snapshot == state.last {
            state.tick = tick;
            return;
        }

        state.tick = tick;
        state.last = snapshot.clone();
        drop(self.events.send(snapshot));
    }
}

#[instrument(name = "system::observe", skip_all)]
fn observe(
    previous: Option<Tick>,
    cpu: Cpu,
    memory_history: Trace,
    thermometer: &mut Thermometer,
) -> (Snapshot, Option<Tick>) {
    let later = host::cpu_tick()
        .inspect_err(|error| {
            tracing::debug!(%error, "CPU occupancy is still measuring");
        })
        .ok();
    let tick = later.or(previous);
    let memory = match host::memory(memory_history) {
        Ok(memory) => memory,
        Err(error) => {
            tracing::warn!(%error, "System memory occupancy is unavailable");
            return (Snapshot::unavailable(error.to_string()), tick);
        }
    };
    let usage = match (previous, later) {
        (Some(earlier), Some(later)) => earlier.usage_until(later),
        _ => Usage::Measuring,
    };
    let cpu = match usage.percent() {
        Some(percent) => cpu.record(percent),
        None => Cpu {
            usage: Usage::Measuring,
            history: cpu.history,
        },
    };
    let uptime = host::uptime().unwrap_or_else(|error| {
        tracing::debug!(%error, "System uptime is unavailable");
        Duration::ZERO
    });
    let processes = host::processes().unwrap_or_else(|error| {
        tracing::debug!(%error, "Process count is unavailable");
        0
    });

    (
        Snapshot::Ready {
            cpu,
            memory,
            disk: host::disk(),
            uptime,
            temperature: thermometer.sample(),
            processes,
        },
        tick,
    )
}

#[instrument(name = "system::monitor::poll", skip_all)]
fn spawn_poll(monitor: Handle, refresh_interval: Duration) {
    tokio::spawn(async move {
        let mut ticker = interval(refresh_interval);
        ticker.set_missed_tick_behavior(MissedTickBehavior::Skip);
        loop {
            ticker.tick().await;
            monitor.refresh().await;
        }
    });
}

/// A system occupancy host-boundary error.
#[derive(Debug, thiserror::Error)]
pub enum Error {
    /// `/proc/stat` could not be read.
    #[error("CPU counters are unavailable")]
    CpuStat(#[source] std::io::Error),
    /// `/proc/stat` did not contain a usable aggregate `cpu` line.
    #[error("CPU counters are malformed")]
    CpuStatMissing,
    /// `/proc/meminfo` could not be read.
    #[error("memory occupancy is unavailable")]
    Memory(#[source] std::io::Error),
    /// `/proc/meminfo` did not contain `MemTotal`.
    #[error("memory occupancy is malformed")]
    MemoryMissing,
    /// `/proc/uptime` could not be read.
    #[error("system uptime is unavailable")]
    Uptime(#[source] std::io::Error),
    /// `/proc/uptime` did not contain a usable seconds field.
    #[error("system uptime is malformed")]
    UptimeMissing,
    /// `/proc` could not be listed.
    #[error("process list is unavailable")]
    Processes(#[source] std::io::Error),
    /// The root path could not be turned into a C string.
    #[error("root filesystem path is invalid")]
    DiskPath,
    /// Root filesystem occupancy could not be measured.
    #[error("root filesystem occupancy is unavailable")]
    Disk(#[source] std::io::Error),
    /// A thermal sensor directory could not be read.
    #[error("CPU temperature is unavailable")]
    Temperature(#[source] std::io::Error),
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use super::Configuration;

    #[test]
    fn config_accepts_human_refresh_cadence() {
        let config = toml::from_str::<Configuration>(
            r#"
            refresh_interval = "750ms"
            "#,
        )
        .expect("system config should parse human refresh cadence");

        assert_eq!(
            config.refresh_interval.duration(),
            Duration::from_millis(750)
        );
    }

    #[test]
    fn config_rejects_zero_refresh_cadence() {
        let error = toml::from_str::<Configuration>(
            r#"
            refresh_interval = "0s"
            "#,
        )
        .expect_err("zero system refresh cadence should not deserialize");

        assert!(error.to_string().contains("cadence cannot be zero"));
    }
}
