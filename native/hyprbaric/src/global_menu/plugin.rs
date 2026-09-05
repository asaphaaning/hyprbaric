//! Hyprland AppMenu companion installation.
//!
//! The companion is a compositor plugin, so it is compiled against Hyprland's
//! internals and only loads into the version it was built for. Two paths lead
//! to a loaded companion, and this module tries them in the order that costs
//! the user least.
//!
//! The bundle carries one prebuilt companion beside its native libraries.
//! Loading that needs no privileges, no toolchain and no network, so it is
//! tried first and is what almost every launch uses. It stops working after a
//! Hyprland upgrade, at which point Hyprland rejects it for the ABI it was
//! built against.
//!
//! hyprpm is the answer to that: Hyprland's own plugin manager, which builds
//! the companion from `hyprpm.toml` against the headers of the installed
//! compositor. It is slower, needs a toolchain, and its first ever run needs
//! one privileged command, so it is the fallback rather than the default.

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
const HYPRPM_PLUGIN: &str = "hyprbaric-appmenu";
const HYPRPM_STATE_STORE: &str = "/var/cache/hyprpm";
const REPOSITORY: &str = "https://github.com/asaphaaning/Hyprbaric";

/// Global-menu companion settings loaded from `[global_menu]`.
///
/// Whether the menu is shown at all lives with the other modules, in
/// `[modules.global_menu]`. What is here is only how to obtain the companion.
#[derive(Clone, Debug, Deserialize, PartialEq, Eq)]
#[serde(default)]
pub struct Configuration {
    /// Path replacing the companion bundled beside Hyprbaric.
    pub plugin_path: Option<PathBuf>,
    /// Repository hyprpm builds the companion from.
    pub repository: String,
}

/// How far the companion got toward being usable.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Readiness {
    /// Loaded into Hyprland; menus can be read.
    Ready,
    /// Something only the user can resolve is in the way.
    Blocked(Blocker),
}

/// What stopped the companion from loading.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Blocker {
    /// Neither a bundled nor a configured companion exists to load.
    MissingPlugin { path: PathBuf },
    /// The prebuilt companion does not fit this Hyprland and hyprpm is absent.
    ToolMissing,
    /// hyprpm has never run, and creating its store needs a privileged command.
    ///
    /// A desktop session has no terminal to answer that prompt on, so the one
    /// command is left to the user rather than raised behind their back.
    StateStore,
    /// hyprpm could not produce a companion this Hyprland accepts.
    Rebuild { detail: String },
}

impl Default for Configuration {
    fn default() -> Self {
        Self {
            plugin_path: None,
            repository: REPOSITORY.to_owned(),
        }
    }
}

impl Configuration {
    fn plugin_path(&self) -> Result<PathBuf, Error> {
        match &self.plugin_path {
            Some(path) => Ok(path.clone()),
            None => bundled_plugin_path(),
        }
    }
}

impl Blocker {
    /// One sentence naming what is wrong.
    pub fn message(&self) -> String {
        match self {
            Self::MissingPlugin { path } => {
                format!(
                    "The AppMenu companion is missing from `{}`.",
                    path.display()
                )
            }
            Self::ToolMissing => {
                "The bundled AppMenu companion does not fit this version of Hyprland, and \
                 hyprpm is not installed to rebuild it."
                    .to_owned()
            }
            Self::StateStore => {
                "The bundled AppMenu companion does not fit this version of Hyprland, and \
                 rebuilding it needs hyprpm's store, which does not exist yet."
                    .to_owned()
            }
            Self::Rebuild { detail } => {
                format!("Hyprland would not load a rebuilt AppMenu companion: {detail}")
            }
        }
    }

    /// The command that resolves this, when one exists.
    pub fn instruction(&self) -> Option<String> {
        match self {
            Self::StateStore => Some(format!("hyprpm add {REPOSITORY}")),
            Self::Rebuild { .. } => Some("hyprpm update".to_owned()),
            Self::MissingPlugin { .. } | Self::ToolMissing => None,
        }
    }
}

/// Loads the companion, rebuilding it through hyprpm if the bundle no longer
/// fits the running compositor.
#[instrument(name = "hyprbaric::global_menu::plugin::install", skip_all, err)]
pub(super) async fn install(configuration: &Configuration) -> Result<Readiness, Error> {
    if is_loaded().await? {
        tracing::debug!("Hyprbaric AppMenu companion is already loaded");
        return Ok(Readiness::Ready);
    }

    match load_bundled(configuration).await? {
        Readiness::Ready => return Ok(Readiness::Ready),
        Readiness::Blocked(Blocker::MissingPlugin { path }) => {
            tracing::debug!(path = %path.display(), "No bundled companion; asking hyprpm");
        }
        Readiness::Blocked(blocker) => return Ok(Readiness::Blocked(blocker)),
    }

    rebuild(configuration).await
}

/// Loads the companion the bundle carries, or the one the user configured.
async fn load_bundled(configuration: &Configuration) -> Result<Readiness, Error> {
    let path = configuration.plugin_path()?;
    if !path.is_file() {
        return Ok(Readiness::Blocked(Blocker::MissingPlugin { path }));
    }

    let output = Command::new("hyprctl")
        .args(["plugin", "load"])
        .arg(&path)
        .stdin(Stdio::null())
        .output()
        .await
        .map_err(Error::Load)?;

    // Hyprland answers a version mismatch on stdout with a zero exit status, so
    // whether the companion actually loaded is the only reliable signal.
    if is_loaded().await? {
        tracing::info!(path = %path.display(), "Loaded the bundled AppMenu companion");
        return Ok(Readiness::Ready);
    }

    tracing::info!(
        path = %path.display(),
        detail = %command_detail(&output),
        "The bundled AppMenu companion does not fit this Hyprland; rebuilding"
    );

    Ok(Readiness::Blocked(Blocker::MissingPlugin { path }))
}

/// Rebuilds the companion against the running Hyprland through hyprpm.
async fn rebuild(configuration: &Configuration) -> Result<Readiness, Error> {
    if which("hyprpm").await.is_none() {
        return Ok(Readiness::Blocked(Blocker::ToolMissing));
    }

    if !Path::new(HYPRPM_STATE_STORE).is_dir() {
        return Ok(Readiness::Blocked(Blocker::StateStore));
    }

    // Adding a repository hyprpm already knows is an error rather than a no-op,
    // so its outcome is a fact to record, not a failure to report.
    let added = hyprpm(&["add", configuration.repository.as_str()]).await?;
    tracing::debug!(added, "Asked hyprpm for the Hyprbaric repository");

    for arguments in [vec!["enable", HYPRPM_PLUGIN], vec!["reload"]] {
        if !hyprpm(&arguments).await? {
            tracing::debug!(?arguments, "hyprpm declined a step");
        }
    }

    if is_loaded().await? {
        tracing::info!("Rebuilt the AppMenu companion through hyprpm");
        return Ok(Readiness::Ready);
    }

    Ok(Readiness::Blocked(Blocker::Rebuild {
        detail: "the rebuilt companion did not appear in Hyprland's plugin list".to_owned(),
    }))
}

async fn hyprpm(arguments: &[&str]) -> Result<bool, Error> {
    let output = Command::new("hyprpm")
        .args(arguments)
        .stdin(Stdio::null())
        .output()
        .await
        .map_err(Error::Hyprpm)?;

    Ok(output.status.success())
}

async fn which(program: &str) -> Option<()> {
    Command::new("sh")
        .args(["-c", &format!("command -v {program}")])
        .stdin(Stdio::null())
        .output()
        .await
        .ok()
        .filter(|output| output.status.success())
        .map(|_| ())
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

/// AppMenu companion installation failures.
#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("failed to resolve the Hyprbaric executable")]
    CurrentExecutable(#[source] std::io::Error),
    #[error("the Hyprbaric executable `{executable}` has no parent directory")]
    ExecutableDirectory { executable: PathBuf },
    #[error("failed to query loaded Hyprland plugins")]
    Query(#[source] std::io::Error),
    #[error("Hyprland rejected the plugin query with status {status:?}: {detail}")]
    QueryRejected { status: Option<i32>, detail: String },
    #[error("Hyprland returned an invalid plugin listing")]
    Decode(#[source] serde_json::Error),
    #[error("failed to load the Hyprbaric AppMenu companion")]
    Load(#[source] std::io::Error),
    #[error("failed to run hyprpm")]
    Hyprpm(#[source] std::io::Error),
}

#[cfg(test)]
mod tests {
    use std::path::{Path, PathBuf};

    use super::{Blocker, Configuration, PLUGIN_NAME, Plugin, bundled_plugin_path_for};

    #[test]
    fn configuration_defaults_to_the_bundled_companion() {
        let configuration = toml::from_str::<Configuration>("")
            .expect("default global-menu configuration should parse");

        assert_eq!(configuration, Configuration::default());
        assert_eq!(configuration.plugin_path, None);
        assert!(configuration.repository.starts_with("https://"));
    }

    #[test]
    fn configuration_accepts_a_custom_plugin_path() {
        let configuration =
            toml::from_str::<Configuration>("plugin_path = \"/opt/hyprbaric/custom-menu.so\"\n")
                .expect("global-menu configuration should parse");

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

    #[test]
    fn only_blockers_the_user_can_act_on_carry_a_command() {
        assert!(Blocker::StateStore.instruction().is_some());
        assert!(Blocker::ToolMissing.instruction().is_none());
        assert!(
            Blocker::MissingPlugin {
                path: PathBuf::from("/nowhere.so"),
            }
            .instruction()
            .is_none()
        );
    }

    #[test]
    fn every_blocker_explains_itself() {
        for blocker in [
            Blocker::ToolMissing,
            Blocker::StateStore,
            Blocker::Rebuild {
                detail: "build failed".to_owned(),
            },
            Blocker::MissingPlugin {
                path: PathBuf::from("/nowhere.so"),
            },
        ] {
            assert!(!blocker.message().is_empty());
        }
    }
}
