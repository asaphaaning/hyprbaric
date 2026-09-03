//! First-run setup-guide policy and persistence.

mod domain;
mod settings;
mod signal;

use std::sync::Arc;

use serde::{Deserialize, Deserializer};
use tokio::sync::{Mutex, broadcast};
use tracing::instrument;

pub use domain::{Command, Completion, Outcome, Report, Startup, Status};

/// Setup-guide configuration loaded from `[setup]`.
///
/// Deserialization is total: a malformed `[setup]` table degrades to defaults
/// with a warning instead of failing the whole configuration load. Setup is a
/// first-run convenience and must never prevent the bar from starting.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Configuration {
    startup: Startup,
    completed: Completion,
}

impl<'de> Deserialize<'de> for Configuration {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let value = toml::Value::deserialize(deserializer)?;

        Ok(Self::from_value(&value))
    }
}

impl Default for Configuration {
    fn default() -> Self {
        Self {
            startup: Startup::Once,
            completed: Completion::PENDING,
        }
    }
}

impl Configuration {
    /// Projects a raw TOML value into configuration, degrading to defaults.
    ///
    /// Missing keys stay silent; present-but-invalid values warn. Either way
    /// the bar keeps a well-defined setup policy.
    fn from_value(value: &toml::Value) -> Self {
        let Some(table) = value.as_table() else {
            tracing::warn!(
                "Ignoring malformed [setup] configuration; expected a table, using defaults"
            );

            return Self::default();
        };

        Self {
            startup: match table.get("startup") {
                None => Startup::Once,
                Some(value) => match value.as_str() {
                    Some("once") => Startup::Once,
                    Some("never") => Startup::Never,
                    Some(other) => {
                        tracing::warn!(
                            startup = other,
                            "Ignoring malformed [setup] startup policy; expected \"once\" or \"never\""
                        );

                        Startup::Once
                    }
                    None => {
                        tracing::warn!(
                            "Ignoring malformed [setup] startup policy; expected a string"
                        );

                        Startup::Once
                    }
                },
            },
            completed: match table.get("completed") {
                None => Completion::PENDING,
                Some(value) => match value.as_bool() {
                    Some(true) => Completion::COMPLETE,
                    Some(false) => Completion::PENDING,
                    None => {
                        tracing::warn!(
                            "Ignoring malformed [setup] completion flag; expected a boolean"
                        );

                        Completion::PENDING
                    }
                },
            },
        }
    }

    /// Returns the automatic startup policy.
    pub const fn startup(&self) -> Startup {
        self.startup
    }

    /// Returns the persisted completion fact.
    pub const fn completion(&self) -> Completion {
        self.completed
    }

    /// Projects configuration into an exhaustive UI status.
    pub const fn status(&self) -> Status {
        match (self.startup, self.completed.is_complete()) {
            (Startup::Never, _) => Status::Disabled,
            (Startup::Once, true) => Status::Complete,
            (Startup::Once, false) => Status::Required,
        }
    }

    /// Returns this configuration with completion acknowledged.
    #[must_use]
    pub const fn completed(&self) -> Self {
        Self {
            startup: self.startup,
            completed: Completion::COMPLETE,
        }
    }
}

/// Shared setup-guide runtime handle.
pub type Handle = Arc<Guide>;

/// Persists setup completion and publishes typed state transitions.
pub struct Guide {
    state: Mutex<Configuration>,
    events: broadcast::Sender<Status>,
    reports: broadcast::Sender<Report>,
}

impl Guide {
    /// Creates the setup runtime and its initial status.
    pub fn bootstrap(configuration: &Configuration) -> (Handle, Status) {
        let (events, _) = broadcast::channel(8);
        let (reports, _) = broadcast::channel(8);
        let status = configuration.status();
        let guide = Arc::new(Self {
            state: Mutex::new(configuration.clone()),
            events,
            reports,
        });

        (guide, status)
    }

    /// Applies one setup command.
    ///
    /// The state lock is held across the whole read-modify-write cycle, so
    /// concurrent commands serialize instead of interleaving duplicate
    /// persists. Filesystem work runs on the blocking pool: the runtime is
    /// single-threaded and must never stall on disk IO.
    #[instrument(name = "hyprbaric::setup::guide::apply", skip(self))]
    pub async fn apply(&self, command: Command) {
        drop(self.reports.send(Report::Started(command)));

        let Command::Complete(_) = command;

        let mut state = self.state.lock().await;

        if state.completion().is_complete() {
            drop(self.reports.send(Report::Saved(command)));

            return;
        }

        let current = state.clone();
        let persisted = tokio::task::spawn_blocking(move || settings::complete(&current)).await;

        match persisted {
            Ok(Ok(next)) => {
                // The published status is derived, never assumed: completing a
                // guide whose policy is `never` leaves it disabled, not
                // complete, and the UI has to hear the same answer the
                // configuration would give.
                let status = next.status();
                *state = next;
                drop(state);
                drop(self.events.send(status));
                drop(self.reports.send(Report::Saved(command)));
            }
            Ok(Err(error)) => {
                drop(state);
                drop(self.reports.send(Report::Failed {
                    command,
                    message: error.to_string(),
                }));
            }
            Err(join) => {
                drop(state);
                drop(self.reports.send(Report::Failed {
                    command,
                    message: format!("setup persistence task failed: {join}"),
                }));
            }
        }
    }

    /// Subscribes to setup statuses.
    pub fn subscribe(&self) -> broadcast::Receiver<Status> {
        self.events.subscribe()
    }

    /// Subscribes to setup command reports.
    pub fn subscribe_results(&self) -> broadcast::Receiver<Report> {
        self.reports.subscribe()
    }
}

/// Setup-guide failure.
#[derive(Debug, thiserror::Error)]
pub enum Error {
    /// The `[setup]` configuration item is not a TOML table.
    #[error("setup configuration must be a TOML table")]
    InvalidTable,
    /// The user configuration could not be updated.
    #[error("failed to persist setup completion")]
    Configuration(#[from] crate::config::Error),
}

#[cfg(test)]
mod tests {
    use std::{env, fs};

    use super::{Command, Completion, Configuration, Guide, Outcome, Report, Startup, Status};

    struct EnvGuard {
        key: &'static str,
        previous: Option<std::ffi::OsString>,
    }

    impl EnvGuard {
        fn set(key: &'static str, value: &std::path::Path) -> Self {
            let previous = env::var_os(key);
            // SAFETY: tests in this module hold the environment lock while
            // the guard is alive.
            unsafe {
                env::set_var(key, value);
            }
            Self { key, previous }
        }
    }

    impl Drop for EnvGuard {
        fn drop(&mut self) {
            // SAFETY: tests in this module hold the environment lock while
            // the guard is alive.
            unsafe {
                match &self.previous {
                    Some(value) => env::set_var(self.key, value),
                    None => env::remove_var(self.key),
                }
            }
        }
    }

    fn override_config(
        name: &str,
    ) -> (
        std::sync::MutexGuard<'static, ()>,
        EnvGuard,
        std::path::PathBuf,
    ) {
        let environment = crate::config::environment_lock();
        let path = env::temp_dir().join(format!(
            "hyprbaric-setup-test-{}-{}",
            std::process::id(),
            name
        ));
        let _ = fs::remove_file(&path);
        let guard = EnvGuard::set("HYPRBARIC_CONFIG", &path);

        (environment, guard, path)
    }

    #[test]
    fn startup_status_is_exhaustive() {
        let required = Configuration::default();
        let complete = toml::from_str::<Configuration>("completed = true")
            .expect("completed setup should parse");
        let disabled = toml::from_str::<Configuration>("startup = \"never\"")
            .expect("disabled setup should parse");

        assert_eq!(required.status(), Status::Required);
        assert_eq!(complete.status(), Status::Complete);
        assert_eq!(disabled.status(), Status::Disabled);
    }

    #[test]
    fn malformed_startup_falls_back_to_once() {
        let configuration = toml::from_str::<Configuration>("startup = \"sometimes\"")
            .expect("malformed startup should degrade instead of failing");

        assert_eq!(configuration.startup(), Startup::Once);
        assert_eq!(configuration.status(), Status::Required);
    }

    #[test]
    fn malformed_completion_falls_back_to_pending() {
        let configuration = toml::from_str::<Configuration>("completed = \"yes\"")
            .expect("malformed completion should degrade instead of failing");

        assert_eq!(configuration.completion(), Completion::PENDING);
        assert_eq!(configuration.status(), Status::Required);
    }

    #[test]
    fn unknown_keys_fall_back_to_defaults() {
        let configuration = toml::from_str::<Configuration>("setup = \"already-complete\"")
            .expect("unknown setup keys should degrade instead of failing");

        assert_eq!(configuration, Configuration::default());
    }

    #[tokio::test]
    async fn apply_persists_completion_to_the_override_config() {
        let (_environment, _guard, path) = override_config("persist");
        let (guide, initial) = Guide::bootstrap(&Configuration::default());
        let mut events = guide.subscribe();
        let mut reports = guide.subscribe_results();

        assert_eq!(initial, Status::Required);

        guide.apply(Command::Complete(Outcome::Finished)).await;

        let source = fs::read_to_string(&path).expect("config should be readable");
        assert!(source.contains("completed = true"));
        assert!(source.contains("startup = \"once\""));
        assert_eq!(
            events.try_recv().expect("status should be published"),
            Status::Complete
        );
        assert!(matches!(
            reports.try_recv().expect("report should be published"),
            Report::Started(Command::Complete(Outcome::Finished))
        ));
        assert!(matches!(
            reports.try_recv().expect("report should be published"),
            Report::Saved(Command::Complete(Outcome::Finished))
        ));

        let _ = fs::remove_file(&path);
    }

    #[tokio::test]
    async fn apply_replay_is_idempotent() {
        let (_environment, _guard, path) = override_config("replay");
        fs::write(&path, "[setup]\nstartup = \"once\"\ncompleted = true\n")
            .expect("fixture config should be written");
        let before = fs::read(&path).expect("fixture config should be readable");
        let (guide, _) = Guide::bootstrap(&Configuration::default().completed());
        let mut events = guide.subscribe();
        let mut reports = guide.subscribe_results();

        guide.apply(Command::Complete(Outcome::Skipped)).await;

        assert_eq!(fs::read(&path).expect("config should be readable"), before);
        assert!(events.try_recv().is_err());
        assert!(matches!(
            reports.try_recv().expect("report should be published"),
            Report::Started(_)
        ));
        assert!(matches!(
            reports.try_recv().expect("report should be published"),
            Report::Saved(_)
        ));

        let _ = fs::remove_file(&path);
    }

    #[tokio::test]
    async fn apply_reports_failure_without_touching_the_config() {
        let (_environment, _guard, path) = override_config("failure");
        fs::write(&path, "setup = \"already-complete\"\n").expect("fixture should be written");
        let (guide, _) = Guide::bootstrap(&Configuration::default());
        let mut events = guide.subscribe();
        let mut reports = guide.subscribe_results();

        guide.apply(Command::Complete(Outcome::Finished)).await;

        assert_eq!(
            fs::read_to_string(&path).expect("config should be readable"),
            "setup = \"already-complete\"\n"
        );
        assert!(events.try_recv().is_err());
        assert!(matches!(
            reports.try_recv().expect("report should be published"),
            Report::Started(_)
        ));
        assert!(matches!(
            reports.try_recv().expect("report should be published"),
            Report::Failed { .. }
        ));

        let _ = fs::remove_file(&path);
    }
}
