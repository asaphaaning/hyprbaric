//! Workspace indicator settings persistence.

use toml_edit::{Table, value};
use tracing::instrument;

use crate::config;

use super::{Command, Configuration, Error};

const TABLE: &str = "workspaces";

#[instrument(skip(command), err)]
pub fn save(command: &Command, current: Configuration) -> Result<Configuration, Error> {
    let next = current.apply(command);
    config::edit_table(TABLE, |table| write_workspaces(table, next))?;

    Ok(next)
}

fn write_workspaces(table: &mut Table, config: Configuration) {
    table["indicator_style"] = value(config.indicator_style().as_str());
    table["clickable"] = value(config.clickable());
    table["visible_range"] = value(config.visible_range().as_str());
}

#[cfg(test)]
mod tests {
    use std::{env, fs, path::PathBuf};

    use crate::workspaces::{Command, Configuration, IndicatorStyle, VisibleRange};

    use super::save;

    struct EnvGuard {
        key: &'static str,
        previous: Option<std::ffi::OsString>,
    }

    impl EnvGuard {
        fn set(key: &'static str, value: &PathBuf) -> Self {
            let previous = env::var_os(key);
            unsafe {
                env::set_var(key, value);
            }
            Self { key, previous }
        }
    }

    impl Drop for EnvGuard {
        fn drop(&mut self) {
            unsafe {
                match &self.previous {
                    Some(value) => env::set_var(self.key, value),
                    None => env::remove_var(self.key),
                }
            }
        }
    }

    #[test]
    fn save_patches_workspaces_without_removing_existing_config() {
        let _environment = crate::config::environment_lock();
        let root =
            env::temp_dir().join(format!("hyprbaric-workspaces-test-{}", std::process::id()));
        let _guard = EnvGuard::set("XDG_CONFIG_HOME", &root);
        let config_path = root.join("hyprbaric/config.toml");
        fs::create_dir_all(config_path.parent().expect("config should have parent"))
            .expect("config directory should be created");
        fs::write(&config_path, "[night_light]\ntemperature = 3500\n")
            .expect("fixture config should be written");

        let next = save(
            &Command::SetIndicatorStyle {
                indicator_style: IndicatorStyle::Numeric,
            },
            Configuration::default(),
        )
        .expect("workspace config should save");

        let source = fs::read_to_string(&config_path).expect("config should be readable");
        assert!(source.contains("[night_light]"));
        assert!(source.contains("[workspaces]"));
        assert!(source.contains("indicator_style = \"numeric\""));
        assert!(source.contains("clickable = true"));
        assert!(source.contains("visible_range = \"medium\""));
        assert_eq!(next.indicator_style(), IndicatorStyle::Numeric);

        fs::remove_dir_all(root).expect("fixture config should be removed");
    }

    #[test]
    fn save_writes_visible_range() {
        let next = Configuration::default().apply(&Command::SetVisibleRange {
            visible_range: VisibleRange::Large,
        });

        assert_eq!(next.visible_range(), VisibleRange::Large);
    }
}
