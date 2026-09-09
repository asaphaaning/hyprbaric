//! Night-light settings persistence.

use toml_edit::{Table, value};
use tracing::instrument;

use crate::config;

use super::{Command, Configuration, Error};

const TABLE: &str = "night_light";

/// Persists the command into the user configuration file.
#[instrument(skip(command), err)]
pub fn save(command: &Command, current: Configuration) -> Result<Configuration, Error> {
    let next = current.apply(command);
    config::edit_table(TABLE, |table| write_night_light(table, next))?;

    Ok(next)
}

fn write_night_light(table: &mut Table, config: Configuration) {
    table["enabled"] = value(config.enabled());
    table["temperature"] = value(config.temperature().as_u32() as i64);
}

#[cfg(test)]
mod tests {
    use std::{env, fs, path::PathBuf};

    use crate::night_light::{Command, Configuration, Temperature};

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
    fn save_patches_night_light_without_removing_existing_config() {
        let _environment = crate::config::environment_lock();
        let root =
            env::temp_dir().join(format!("hyprbaric-night-light-test-{}", std::process::id()));
        let _guard = EnvGuard::set("XDG_CONFIG_HOME", &root);
        let config_path = root.join("hyprbaric/config.toml");
        fs::create_dir_all(config_path.parent().expect("config should have parent"))
            .expect("config directory should be created");
        fs::write(
            &config_path,
            "[network]\ntraffic_refresh_interval = \"1s\"\n",
        )
        .expect("fixture config should be written");

        let next = save(
            &Command::SetTemperature {
                temperature: Temperature::new(3000).expect("temperature should be valid"),
            },
            Configuration::default(),
        )
        .expect("night-light config should save");

        let source = fs::read_to_string(&config_path).expect("config should be readable");
        assert!(source.contains("[network]"));
        assert!(source.contains("[night_light]"));
        assert!(source.contains("enabled = false"));
        assert!(source.contains("temperature = 3000"));
        assert_eq!(next.temperature().as_u32(), 3000);

        fs::remove_dir_all(root).expect("fixture config should be removed");
    }
}
