//! Hyprland AppMenu companion loading.
//!
//! The Flutter bundle carries the compositor plugin beside its native shared
//! libraries. [`Configuration`] makes loading an explicit user choice, while
//! this module keeps the process boundary and Hyprland's JSON listing protocol
//! out of the menu reader.

use std::{
    env,
    path::{Path, PathBuf},
    process::Stdio,
};

use serde::Deserialize;
use tokio::process::Command;
use tracing::instrument;

const PLUGIN_NAME: &str = "Hyprbaric AppMenu";
const BUNDLED_PLUGIN: &str = "hyprbaric-appmenu.so";

/// Global-menu boot policy loaded from `[global_menu]`.
#[derive(Clone, Debug, Default, Deserialize, PartialEq, Eq)]
#[serde(default)]
pub struct Configuration {
    /// Whether Hyprbaric should load its AppMenu companion at startup.
    pub enabled: bool,
    /// Optional path replacing the plugin bundled beside Hyprbaric.
    pub plugin_path: Option<PathBuf>,
}

impl Configuration {
    fn plugin_path(&self) -> Result<PathBuf, Error> {
        match &self.plugin_path {
            Some(path) => Ok(path.clone()),
            None => bundled_plugin_path(),
        }
    }
}

/// Loads the companion if the user enabled global menus and it is not active.
#[instrument(
    name = "hyprbaric::global_menu::plugin::load",
    skip(configuration),
    err
)]
pub(super) async fn load(configuration: &Configuration) -> Result<(), Error> {
    if !configuration.enabled {
        tracing::debug!("Global-menu companion loading is disabled by configuration");
        return Ok(());
    }

    if is_loaded().await? {
        tracing::debug!("Hyprbaric AppMenu companion is already loaded");
        return Ok(());
    }

    let path = configuration.plugin_path()?;
    if !path.is_file() {
        return Err(Error::MissingPlugin { path });
    }

    let output = Command::new("hyprctl")
        .args(["plugin", "load"])
        .arg(&path)
        .stdin(Stdio::null())
        .output()
        .await
        .map_err(Error::Load)?;

    if !output.status.success() {
        return Err(Error::LoadRejected {
            status: output.status.code(),
            detail: command_detail(&output),
        });
    }

    tracing::info!(path = %path.display(), "Loaded Hyprbaric AppMenu companion");
    Ok(())
}

async fn is_loaded() -> Result<bool, Error> {
    let output = Command::new("hyprctl")
        .args(["-j", "plugins", "list"])
        .stdin(Stdio::null())
        .output()
        .await
        .map_err(Error::Query)?;

    if !output.status.success() {
        return Err(Error::QueryRejected {
            status: output.status.code(),
            detail: command_detail(&output),
        });
    }

    let plugins = serde_json::from_slice::<Vec<Plugin>>(&output.stdout).map_err(Error::Decode)?;
    Ok(plugins.iter().any(|plugin| plugin.name == PLUGIN_NAME))
}

fn bundled_plugin_path() -> Result<PathBuf, Error> {
    let executable = env::current_exe().map_err(Error::CurrentExecutable)?;
    bundled_plugin_path_for(&executable).ok_or(Error::ExecutableDirectory { executable })
}

fn bundled_plugin_path_for(executable: &Path) -> Option<PathBuf> {
    executable
        .parent()
        .map(|directory| directory.join("lib").join(BUNDLED_PLUGIN))
}

fn command_detail(output: &std::process::Output) -> String {
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_owned();
    if stderr.is_empty() {
        String::from_utf8_lossy(&output.stdout).trim().to_owned()
    } else {
        stderr
    }
}

#[derive(Deserialize)]
struct Plugin {
    name: String,
}

/// AppMenu companion loading failures.
#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("failed to resolve the Hyprbaric executable")]
    CurrentExecutable(#[source] std::io::Error),
    #[error("the Hyprbaric executable `{executable}` has no parent directory")]
    ExecutableDirectory { executable: PathBuf },
    #[error("the configured AppMenu companion `{path}` does not exist")]
    MissingPlugin { path: PathBuf },
    #[error("failed to query loaded Hyprland plugins")]
    Query(#[source] std::io::Error),
    #[error("Hyprland rejected the plugin query with status {status:?}: {detail}")]
    QueryRejected { status: Option<i32>, detail: String },
    #[error("Hyprland returned an invalid plugin listing")]
    Decode(#[source] serde_json::Error),
    #[error("failed to load the Hyprbaric AppMenu companion")]
    Load(#[source] std::io::Error),
    #[error("Hyprland rejected the AppMenu companion with status {status:?}: {detail}")]
    LoadRejected { status: Option<i32>, detail: String },
}

#[cfg(test)]
mod tests {
    use std::path::Path;

    use super::{Configuration, PLUGIN_NAME, Plugin, bundled_plugin_path_for};

    #[test]
    fn configuration_is_disabled_by_default() {
        let configuration = toml::from_str::<Configuration>("")
            .expect("default global-menu configuration should parse");

        assert_eq!(configuration, Configuration::default());
    }

    #[test]
    fn configuration_accepts_an_enabled_custom_plugin_path() {
        let configuration = toml::from_str::<Configuration>(
            "enabled = true\nplugin_path = \"/opt/hyprbaric/custom-menu.so\"\n",
        )
        .expect("global-menu configuration should parse");

        assert!(configuration.enabled);
        assert_eq!(
            configuration.plugin_path.as_deref(),
            Some(Path::new("/opt/hyprbaric/custom-menu.so"))
        );
    }

    #[test]
    fn bundled_plugin_lives_in_the_bundle_library_directory() {
        assert_eq!(
            bundled_plugin_path_for(Path::new("/opt/hyprbaric/hyprbaric")),
            Some(Path::new("/opt/hyprbaric/lib/hyprbaric-appmenu.so").to_path_buf())
        );
    }

    #[test]
    fn plugin_listing_uses_the_companion_name() {
        let plugin = serde_json::from_str::<Plugin>(r#"{"name":"Hyprbaric AppMenu"}"#)
            .expect("plugin listing fixture should parse");

        assert_eq!(plugin.name, PLUGIN_NAME);
    }
}
