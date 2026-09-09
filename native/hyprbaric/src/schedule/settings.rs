//! Schedule settings persistence.

use toml_edit::{DocumentMut, Table, value};
use tracing::instrument;

use crate::config;

use super::{Action, Command, Configuration, DailyWindow, Error};

const SCHEDULES: &str = "schedules";
const NIGHT_LIGHT: &str = "night_light";

/// Persists a scheduler command into the user configuration file.
#[instrument(skip(command), err)]
pub fn save(command: &Command, current: Configuration) -> Result<Configuration, Error> {
    let next = current.apply(command);
    config::try_edit(|document| write_configuration(document, next))?;

    Ok(next)
}

fn write_configuration(
    document: &mut DocumentMut,
    config: Configuration,
) -> Result<(), config::Error> {
    match config.night_light() {
        window => write_daily_window(document, Action::NightLight, window),
    }
}

fn write_daily_window(
    document: &mut DocumentMut,
    action: Action,
    window: DailyWindow,
) -> Result<(), config::Error> {
    let table = schedule_table(document, action)?;
    table["enabled"] = value(window.enabled);
    table["start_hour"] = value(i64::from(window.start.as_u8()));
    table["stop_hour"] = value(i64::from(window.stop.as_u8()));
    Ok(())
}

fn schedule_table(document: &mut DocumentMut, action: Action) -> Result<&mut Table, config::Error> {
    let schedules = config::table(document.as_table_mut(), SCHEDULES)?;
    let key = match action {
        Action::NightLight => NIGHT_LIGHT,
    };
    config::table(schedules, key)
}

#[cfg(test)]
mod tests {
    use std::{env, fs, path::PathBuf};

    use crate::schedule::{Action, Command, Configuration, DailyWindow, Hour};

    use super::save;

    struct EnvGuard {
        key: &'static str,
        previous: Option<std::ffi::OsString>,
    }

    impl EnvGuard {
        fn set(key: &'static str, value: &PathBuf) -> Self {
            let previous = env::var_os(key);
            // SAFETY: tests in this module do not spawn threads that read this
            // process environment while the guard is alive.
            unsafe {
                env::set_var(key, value);
            }
            Self { key, previous }
        }
    }

    impl Drop for EnvGuard {
        fn drop(&mut self) {
            // SAFETY: tests in this module do not spawn threads that read this
            // process environment while the guard is alive.
            unsafe {
                match &self.previous {
                    Some(value) => env::set_var(self.key, value),
                    None => env::remove_var(self.key),
                }
            }
        }
    }

    #[test]
    fn save_patches_schedule_without_removing_existing_config() {
        let _environment = crate::config::environment_lock();
        let root = env::temp_dir().join(format!("hyprbaric-schedule-test-{}", std::process::id()));
        let _guard = EnvGuard::set("XDG_CONFIG_HOME", &root);
        let config_path = root.join("hyprbaric/config.toml");
        fs::create_dir_all(config_path.parent().expect("config should have parent"))
            .expect("config directory should be created");
        fs::write(&config_path, "[night_light]\ntemperature = 2500\n")
            .expect("fixture config should be written");

        let window = DailyWindow {
            enabled: true,
            start: Hour::new(22).expect("hour should parse"),
            stop: Hour::new(6).expect("hour should parse"),
        };
        let next = save(
            &Command::SetDailyWindow {
                action: Action::NightLight,
                window,
            },
            Configuration::default(),
        )
        .expect("schedule config should save");

        let source = fs::read_to_string(&config_path).expect("config should be readable");
        assert!(source.contains("[night_light]"));
        assert!(source.contains("[schedules.night_light]"));
        assert!(source.contains("enabled = true"));
        assert!(source.contains("start_hour = 22"));
        assert!(source.contains("stop_hour = 6"));
        assert_eq!(next.night_light(), window);

        fs::remove_dir_all(root).expect("fixture config should be removed");
    }
}
