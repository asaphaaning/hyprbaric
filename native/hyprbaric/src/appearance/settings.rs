//! Appearance settings persistence.

use toml_edit::{DocumentMut, Item, Table, value};
use tracing::instrument;

use crate::config;

use super::{Command, Configuration, Error};

const TABLE: &str = "appearance";

#[instrument(skip(command), err)]
pub fn save(command: &Command, current: Configuration) -> Result<Configuration, Error> {
    let next = current.apply(command);
    config::edit(|document| write_appearance(document, &next))?;

    Ok(next)
}

fn write_appearance(document: &mut DocumentMut, config: &Configuration) {
    if !document.as_table().contains_key(TABLE) {
        document[TABLE] = Item::Table(Table::new());
    }
    let table = document[TABLE]
        .as_table_mut()
        .expect("appearance item should be a table");
    table["position"] = value(config.position().as_str());
    table["monitor"] = value(config.monitor().as_str());
    table["opacity"] = value(config.opacity().as_u8() as i64);
    table["corner_radius"] = value(config.corner_radius().as_u8() as i64);
    table["accent_hue"] = value(config.accent_hue().as_u16() as i64);
}

#[cfg(test)]
mod tests {
    use std::{env, fs, path::PathBuf};

    use toml_edit::DocumentMut;

    use crate::appearance::{Command, Configuration, Opacity};

    use super::{save, write_appearance};

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
    fn save_patches_appearance_without_removing_existing_config() {
        let _environment = crate::config::environment_lock();
        let root =
            env::temp_dir().join(format!("hyprbaric-appearance-test-{}", std::process::id()));
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
            &Command::SetOpacity {
                opacity: Opacity::new(82).expect("opacity should be valid"),
            },
            Configuration::default(),
        )
        .expect("appearance config should save");

        let source = fs::read_to_string(&config_path).expect("config should be readable");
        assert!(source.contains("[network]"));
        assert!(source.contains("[appearance]"));
        assert!(source.contains("position = \"top\""));
        assert!(source.contains("monitor = \"primary\""));
        assert!(source.contains("opacity = 82"));
        assert!(source.contains("corner_radius = 12"));
        assert!(source.contains("accent_hue = 197"));
        assert_eq!(next.opacity().as_u8(), 82);

        fs::remove_dir_all(root).expect("fixture config should be removed");
    }

    #[test]
    fn restore_defaults_rewrites_configured_values() {
        let current = toml::from_str::<Configuration>(
            "position = \"bottom\"\nmonitor = \"all\"\nopacity = 42\ncorner_radius = 4\naccent_hue = 300\n",
        )
        .expect("fixture should parse");
        let next = current.apply(&Command::RestoreDefaults);
        let mut document = "[appearance]\nposition = \"bottom\"\nmonitor = \"all\"\nopacity = 42\ncorner_radius = 4\naccent_hue = 300\n"
            .parse::<DocumentMut>()
            .expect("fixture document should parse");

        write_appearance(&mut document, &next);
        let source = document.to_string();
        assert!(source.contains("position = \"top\""));
        assert!(source.contains("monitor = \"primary\""));
        assert!(source.contains("opacity = 77"));
        assert!(source.contains("corner_radius = 12"));
        assert!(source.contains("accent_hue = 197"));
        assert_eq!(next, Configuration::default());
    }
}
