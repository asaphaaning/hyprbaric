//! Daily action scheduling.
//!
//! The scheduler owns time-window state and applies typed actions when local
//! wall-clock hours cross a configured boundary. Night light is the first
//! action, but the core vocabulary is intentionally action-oriented so other
//! daily bar features can join later without reshaping the transport boundary.

mod domain;
pub mod settings;
mod signal;

use std::{sync::Arc, time::Duration};

use jiff::Zoned;
use serde::Deserialize;
use tokio::{
    sync::{Mutex, Notify, broadcast},
    time::sleep,
};
use tracing::instrument;

use crate::night_light;

pub use domain::{Action, Command, DailyWindow, Entry, Hour, Report, Snapshot};

/// Shared scheduler handle.
pub type Handle = Arc<Scheduler>;

const HOUR: Duration = Duration::from_secs(3600);

/// How often an enabled schedule re-checks that its action is actually applied.
/// Transitions are driven by the hour boundary, so this only exists to retry an
/// action that failed when the boundary was crossed.
const RECONCILE_INTERVAL: Duration = Duration::from_secs(300);

/// Keeps each wake-up just past the boundary rather than a rounding error
/// before it, which would read the hour that is about to end.
const TICK_MARGIN: Duration = Duration::from_millis(5);

/// Schedule configuration.
///
/// ```toml
/// [schedules.night_light]
/// enabled = false
/// start_hour = 21
/// stop_hour = 7
/// ```
#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Eq)]
#[serde(default)]
pub struct Configuration {
    night_light: DailyWindow,
}

/// Live daily scheduler.
pub struct Scheduler {
    events: broadcast::Sender<Snapshot>,
    results: broadcast::Sender<Report>,
    state: Mutex<State>,
    night_light: night_light::Handle,
    /// Wakes the tick loop when configuration changes, so enabling a window
    /// does not wait for a timer that is parked indefinitely.
    wakeup: Notify,
}

#[derive(Clone, Copy, Debug)]
struct State {
    config: Configuration,
    night_light_active: bool,
}

impl Default for Configuration {
    fn default() -> Self {
        Self {
            night_light: DailyWindow::default(),
        }
    }
}

impl Configuration {
    /// Returns the configured night-light schedule.
    pub const fn night_light(self) -> DailyWindow {
        self.night_light
    }

    fn apply(self, command: &Command) -> Self {
        match *command {
            Command::SetDailyWindow {
                action: Action::NightLight,
                window,
            } => Self {
                night_light: window,
                ..self
            },
        }
    }

    fn snapshot(self) -> Snapshot {
        Snapshot::night_light(self.night_light)
    }
}

impl Scheduler {
    /// Starts the scheduler and applies launch-time catch-up.
    #[instrument(skip_all)]
    pub async fn bootstrap(
        config: &Configuration,
        night_light: night_light::Handle,
    ) -> (Handle, Snapshot) {
        let now = current_hour();
        let night_light_active = config.night_light().contains(now);
        let (events, _) = broadcast::channel(16);
        let (results, _) = broadcast::channel(8);
        let scheduler = Arc::new(Self {
            events,
            results,
            state: Mutex::new(State {
                config: *config,
                night_light_active,
            }),
            night_light,
            wakeup: Notify::new(),
        });

        if config.night_light().enabled {
            scheduler
                .apply(Action::NightLight, night_light_active)
                .await;
        }

        spawn_tick(Arc::clone(&scheduler));
        (scheduler, config.snapshot())
    }

    /// Subscribes to schedule snapshots.
    pub fn subscribe(&self) -> broadcast::Receiver<Snapshot> {
        self.events.subscribe()
    }

    /// Subscribes to schedule command reports.
    pub fn subscribe_results(&self) -> broadcast::Receiver<Report> {
        self.results.subscribe()
    }

    /// Persists a daily window and reconciles its current active state.
    #[instrument(skip(self))]
    pub async fn set_daily_window(&self, action: Action, window: DailyWindow) {
        self.apply_command(Command::SetDailyWindow { action, window })
            .await;
    }

    #[instrument(skip(self, command))]
    async fn apply_command(&self, command: Command) {
        drop(self.results.send(Report::Started(command)));
        let current = { self.state.lock().await.config };

        match settings::save(&command, current) {
            Ok(next) => {
                let active = next.night_light().contains(current_hour());
                {
                    let mut state = self.state.lock().await;
                    state.config = next;
                    state.night_light_active = active;
                }
                drop(self.events.send(next.snapshot()));
                drop(self.results.send(Report::Saved(command)));
                self.wakeup.notify_one();

                if next.night_light().enabled {
                    self.apply(Action::NightLight, active).await;
                }
            }
            Err(error) => {
                drop(self.results.send(Report::Failed {
                    command,
                    message: error.to_string(),
                }));
            }
        }
    }

    #[instrument(skip(self))]
    async fn tick(&self) {
        let now = current_hour();
        let Some((action, active, changed)) = ({
            let mut state = self.state.lock().await;
            let next = state.config.night_light().contains(now);
            if !state.config.night_light().enabled {
                None
            } else {
                let changed = next != state.night_light_active;
                state.night_light_active = next;
                Some((Action::NightLight, next, changed))
            }
        }) else {
            return;
        };

        if changed || self.needs_reconcile(action, active).await {
            self.apply(action, active).await;
        }
    }

    #[instrument(skip(self))]
    async fn apply(&self, action: Action, active: bool) {
        match action {
            Action::NightLight => self.night_light.set_enabled(active).await,
        }
    }

    /// Returns how long the tick loop should sleep, or `None` while every
    /// window is disabled and there is nothing to wake up for.
    async fn next_wakeup(&self) -> Option<Duration> {
        let enabled = self.state.lock().await.config.night_light().enabled;

        enabled.then(|| until_next_hour(&Zoned::now()).min(RECONCILE_INTERVAL))
    }

    #[instrument(skip(self))]
    async fn needs_reconcile(&self, action: Action, active: bool) -> bool {
        match action {
            Action::NightLight => self.night_light.needs_reconcile(active).await,
        }
    }
}

/// Drives schedule transitions without a standing poll.
///
/// A disabled schedule parks on [`Scheduler::wakeup`] and costs nothing until
/// configuration changes. An enabled one sleeps to the next hour boundary,
/// capped by [`RECONCILE_INTERVAL`] so a failed action is still retried.
fn spawn_tick(scheduler: Handle) {
    tokio::spawn(async move {
        loop {
            match scheduler.next_wakeup().await {
                Some(delay) => {
                    tokio::select! {
                        () = sleep(delay) => {}
                        () = scheduler.wakeup.notified() => {}
                    }
                }
                None => scheduler.wakeup.notified().await,
            }

            scheduler.tick().await;
        }
    });
}

/// Returns the wall-clock time left in the current hour.
fn until_next_hour(now: &Zoned) -> Duration {
    let elapsed = Duration::new(
        (now.minute().max(0) as u64) * 60 + now.second().max(0) as u64,
        now.subsec_nanosecond().max(0) as u32,
    );

    HOUR.saturating_sub(elapsed) + TICK_MARGIN
}

fn current_hour() -> Hour {
    Hour::from_time(Zoned::now().time())
}

/// Scheduler runtime or persistence error.
#[derive(Debug, thiserror::Error)]
pub enum Error {
    /// A schedule hour was outside the accepted domain.
    #[error(transparent)]
    Hour(#[from] domain::HourError),
    /// Configuration path could not be found.
    #[error(transparent)]
    Config(#[from] crate::config::Error),
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use jiff::{Zoned, civil::date};

    use super::{
        Configuration, DailyWindow, Hour, RECONCILE_INTERVAL, TICK_MARGIN, until_next_hour,
    };

    fn at(minute: i8, second: i8) -> Zoned {
        date(2026, 8, 20)
            .at(12, minute, second, 0)
            .in_tz("UTC")
            .expect("UTC should resolve")
    }

    #[test]
    fn sleeps_the_remainder_of_the_current_hour() {
        assert_eq!(
            until_next_hour(&at(59, 30)),
            Duration::from_secs(30) + TICK_MARGIN
        );
    }

    #[test]
    fn sleeps_a_full_hour_on_the_boundary() {
        assert_eq!(
            until_next_hour(&at(0, 0)),
            Duration::from_secs(3600) + TICK_MARGIN
        );
    }

    #[test]
    fn reconcile_interval_caps_a_long_wait() {
        assert!(until_next_hour(&at(0, 0)).min(RECONCILE_INTERVAL) == RECONCILE_INTERVAL);
        assert!(until_next_hour(&at(59, 30)).min(RECONCILE_INTERVAL) < RECONCILE_INTERVAL);
    }

    #[test]
    fn config_defaults_to_disabled_night_light_window() {
        let config = Configuration::default();

        assert!(!config.night_light().enabled);
        assert_eq!(config.night_light().start.as_u8(), 21);
        assert_eq!(config.night_light().stop.as_u8(), 7);
    }

    #[test]
    fn config_accepts_night_light_window_override() {
        let config = toml::from_str::<Configuration>(
            "\
[night_light]
enabled = true
start_hour = 22
stop_hour = 6
",
        )
        .expect("schedule config should parse");

        assert_eq!(
            config.night_light(),
            DailyWindow {
                enabled: true,
                start: Hour::new(22).expect("hour should parse"),
                stop: Hour::new(6).expect("hour should parse"),
            }
        );
    }

    #[test]
    fn config_rejects_invalid_hours() {
        let error = toml::from_str::<Configuration>(
            "\
[night_light]
start_hour = 24
",
        )
        .expect_err("invalid hour should fail");

        assert!(error.to_string().contains("outside 0..=23"));
    }
}
