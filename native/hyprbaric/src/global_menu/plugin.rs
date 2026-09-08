//! Hyprland AppMenu companion installation.
//!
//! The companion is a compositor plugin, so it is compiled against Hyprland's
//! internals and only loads into the version it was built for. Three paths
//! lead to a loaded companion, and this module tries them in the order that
//! costs the user least.
//!
//! The bundle carries one prebuilt companion beside its native libraries.
//! Loading that needs no privileges, no toolchain and no network, so it is
//! tried first and is what almost every launch uses. It stops working after a
//! Hyprland upgrade, at which point Hyprland rejects it for the ABI it was
//! built against, or a compositor library SONAME the `.so` still names.
//!
//! A checkout or a bundle that still has `hyprland-appmenu` source can rebuild
//! against the installed `hyprland.pc` into a user cache. That needs cmake and
//! headers, not hyprpm's privileged store, so a packaging bump of Aquamarine
//! does not strand a session that already has the tree it was built from.
//!
//! hyprpm remains the last resort: Hyprland's own plugin manager, which builds
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
const REPOSITORY: &str = "https://github.com/asaphaaning/hyprbaric";
const SOURCE_DIR_NAME: &str = "hyprland-appmenu";
const SOURCE_WALK_LIMIT: usize = 10;

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
    /// Where enabling the global menu used to live.
    ///
    /// Kept so a configuration written against the older key keeps working
    /// rather than silently losing its menus. [`Configuration::enabled`] folds
    /// it into the module switch that replaced it.
    #[serde(default)]
    enabled: Option<bool>,
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
            enabled: None,
        }
    }
}

impl Configuration {
    /// Whether the global menu is on, honouring the key this table used to own.
    pub fn enabled(&self, module: bool) -> bool {
        if self.enabled == Some(true) && !module {
            tracing::warn!(
                "`[global_menu] enabled` has moved to `[modules.global_menu] enabled`; \
                 honouring the old key for now"
            );
        }

        module || self.enabled == Some(true)
    }

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

/// Loads the companion, rebuilding it if the bundle no longer fits.
///
/// Order: the `.so` already in the bundle, a cmake rebuild from nearby source,
/// then hyprpm. The local rebuild is what keeps a compositor-library bump
/// from depending on hyprpm's store existing.
#[instrument(name = "hyprbaric::global_menu::plugin::install", skip_all, err)]
pub(super) async fn install(configuration: &Configuration) -> Result<Readiness, Error> {
    if is_loaded().await? {
        tracing::debug!("Hyprbaric AppMenu companion is already loaded");
        return Ok(Readiness::Ready);
    }

    match load_bundled(configuration).await? {
        Readiness::Ready => return Ok(Readiness::Ready),
        Readiness::Blocked(Blocker::MissingPlugin { path }) => {
            tracing::debug!(
                path = %path.display(),
                "Bundled companion unavailable; rebuilding from source"
            );
        }
        Readiness::Blocked(blocker) => return Ok(Readiness::Blocked(blocker)),
    }

    if let Some(path) = rebuild_from_source().await {
        if load_plugin(&path).await? {
            tracing::info!(
                path = %path.display(),
                "Loaded an AppMenu companion rebuilt from source"
            );
            return Ok(Readiness::Ready);
        }

        tracing::info!(
            path = %path.display(),
            "Rebuilt the AppMenu companion from source, but Hyprland would not load it"
        );
    }

    rebuild(configuration).await
}

/// Loads the companion the bundle carries, or the one the user configured.
async fn load_bundled(configuration: &Configuration) -> Result<Readiness, Error> {
    let path = configuration.plugin_path()?;
    if !path.is_file() {
        return Ok(Readiness::Blocked(Blocker::MissingPlugin { path }));
    }

    if load_plugin(&path).await? {
        tracing::info!(path = %path.display(), "Loaded the bundled AppMenu companion");
        return Ok(Readiness::Ready);
    }

    tracing::info!(
        path = %path.display(),
        "The bundled AppMenu companion does not fit this Hyprland; rebuilding"
    );

    Ok(Readiness::Blocked(Blocker::MissingPlugin { path }))
}

/// Asks Hyprland to load a companion, and checks that it stayed loaded.
///
/// Hyprland answers a version mismatch on stdout with a zero exit status, so
/// whether the companion actually appears in the plugin list is the only
/// reliable signal.
async fn load_plugin(path: &Path) -> Result<bool, Error> {
    let output = Command::new("hyprctl")
        .args(["plugin", "load"])
        .arg(path)
        .stdin(Stdio::null())
        .output()
        .await
        .map_err(Error::Load)?;

    if is_loaded().await? {
        return Ok(true);
    }

    tracing::debug!(
        path = %path.display(),
        detail = %command_detail(&output),
        "Hyprland did not keep this companion loaded"
    );
    Ok(false)
}

/// Rebuilds the companion from source shipped with this binary.
///
/// The Flutter bundle carries `data/hyprland-appmenu`. A source checkout that
/// has not installed that snapshot still has the tree a few directories up
/// from `bundle/`. Output goes to the user cache so a root-owned bundle does
/// not block the rebuild. `None` means this install has no source or cmake,
/// and the caller should ask hyprpm.
#[instrument(name = "hyprbaric::global_menu::plugin::rebuild_from_source", skip_all)]
async fn rebuild_from_source() -> Option<PathBuf> {
    if which("cmake").await.is_none() {
        tracing::debug!("cmake is not installed; skipping a local companion rebuild");
        return None;
    }

    let executable = env::current_exe().ok()?;
    let source = companion_source_for(&executable)?;
    let cache = cache_build_dir();
    if let Err(error) = std::fs::create_dir_all(&cache) {
        tracing::warn!(
            path = %cache.display(),
            %error,
            "Could not create the AppMenu companion build cache"
        );
        return None;
    }

    tracing::info!(
        source = %source.display(),
        cache = %cache.display(),
        "Rebuilding the AppMenu companion against this Hyprland"
    );

    let mut configure = Command::new("cmake");
    configure
        .arg("-S")
        .arg(&source)
        .arg("-B")
        .arg(&cache)
        .arg("-DHYPRBARIC_APPMENU_BUILD_PROBES=OFF")
        .arg("-DCMAKE_BUILD_TYPE=Release");
    if !run_cmake(&mut configure).await {
        return None;
    }

    let mut build = Command::new("cmake");
    build
        .arg("--build")
        .arg(&cache)
        .arg("--target")
        .arg("hyprbaric-appmenu");
    if !run_cmake(&mut build).await {
        return None;
    }

    let built = cache.join(BUNDLED_PLUGIN);
    if !built.is_file() {
        tracing::warn!(
            path = %built.display(),
            "cmake finished without producing the AppMenu companion"
        );
        return None;
    }

    if let Some(bundled) = bundled_plugin_path_for(&executable)
        && std::fs::copy(&built, &bundled).is_ok()
    {
        tracing::debug!(
            path = %bundled.display(),
            "Replaced the bundled AppMenu companion with the rebuilt one"
        );
        return Some(bundled);
    }

    Some(built)
}

async fn run_cmake(command: &mut Command) -> bool {
    match command.stdin(Stdio::null()).output().await {
        Ok(output) if output.status.success() => true,
        Ok(output) => {
            tracing::warn!(
                detail = %command_detail(&output),
                "cmake declined a companion rebuild"
            );
            false
        }
        Err(error) => {
            tracing::warn!(%error, "failed to run cmake for the AppMenu companion");
            false
        }
    }
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

/// Source used to rebuild the companion when the bundled `.so` no longer loads.
///
/// The snapshot installed next to the binary is preferred so a packaged
/// bundle can relink without the original checkout. A Flutter tree that
/// has not copied that snapshot still resolves `hyprland-appmenu` by
/// walking up from `bundle/`.
fn companion_source_for(executable: &Path) -> Option<PathBuf> {
    bundled_source_path_for(executable)
        .filter(|path| path.join("CMakeLists.txt").is_file())
        .or_else(|| source_near(executable))
}

fn bundled_source_path_for(executable: &Path) -> Option<PathBuf> {
    executable
        .parent()
        .map(|directory| directory.join("data").join(SOURCE_DIR_NAME))
}

fn source_near(executable: &Path) -> Option<PathBuf> {
    let mut directory = executable.parent()?;
    for _ in 0..SOURCE_WALK_LIMIT {
        let candidate = directory.join(SOURCE_DIR_NAME);
        if candidate.join("CMakeLists.txt").is_file() {
            return Some(candidate);
        }
        directory = directory.parent()?;
    }
    None
}

fn cache_build_dir() -> PathBuf {
    cache_home_from(env::var_os("XDG_CACHE_HOME"), env::var_os("HOME"))
        .join("hyprbaric")
        .join(SOURCE_DIR_NAME)
}

fn cache_home_from(
    xdg_cache_home: Option<std::ffi::OsString>,
    home: Option<std::ffi::OsString>,
) -> PathBuf {
    if let Some(path) = xdg_cache_home
        && !path.is_empty()
    {
        return PathBuf::from(path);
    }

    match home {
        Some(home) => PathBuf::from(home).join(".cache"),
        None => env::temp_dir(),
    }
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

    use super::{
        Blocker, Configuration, PLUGIN_NAME, Plugin, bundled_plugin_path_for,
        bundled_source_path_for, cache_home_from, companion_source_for,
    };

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
    fn the_module_switch_turns_the_global_menu_on() {
        let configuration = Configuration::default();

        assert!(configuration.enabled(true));
        assert!(!configuration.enabled(false));
    }

    #[test]
    fn the_key_this_table_used_to_own_still_turns_it_on() {
        let configuration =
            toml::from_str::<Configuration>("enabled = true\n").expect("legacy key should parse");

        assert!(configuration.enabled(false));
    }

    #[test]
    fn bundled_plugin_lives_in_the_bundle_library_directory() {
        assert_eq!(
            bundled_plugin_path_for(Path::new("/opt/hyprbaric/hyprbaric")),
            Some(Path::new("/opt/hyprbaric/lib/hyprbaric-appmenu.so").to_path_buf())
        );
    }

    #[test]
    fn bundled_source_lives_in_the_bundle_data_directory() {
        assert_eq!(
            bundled_source_path_for(Path::new("/opt/hyprbaric/hyprbaric")),
            Some(Path::new("/opt/hyprbaric/data/hyprland-appmenu").to_path_buf())
        );
    }

    #[test]
    fn a_flutter_bundle_finds_companion_source_in_the_checkout() {
        let root =
            std::env::temp_dir().join(format!("hyprbaric-plugin-source-{}", std::process::id()));
        let source = root.join("hyprland-appmenu");
        let executable = root.join("build/linux/x64/release/bundle/hyprbaric");
        std::fs::create_dir_all(&source).expect("source directory");
        std::fs::write(source.join("CMakeLists.txt"), "").expect("source marker");

        let found = companion_source_for(&executable);
        let _ = std::fs::remove_dir_all(&root);

        assert_eq!(found, Some(source));
    }

    #[test]
    fn bundled_source_wins_over_a_checkout_walk() {
        let root =
            std::env::temp_dir().join(format!("hyprbaric-plugin-bundled-{}", std::process::id()));
        let checkout = root.join("hyprland-appmenu");
        let bundle = root.join("build/linux/x64/release/bundle");
        let bundled = bundle.join("data/hyprland-appmenu");
        std::fs::create_dir_all(&checkout).expect("checkout source");
        std::fs::create_dir_all(&bundled).expect("bundled source");
        std::fs::write(checkout.join("CMakeLists.txt"), "").expect("checkout marker");
        std::fs::write(bundled.join("CMakeLists.txt"), "").expect("bundled marker");

        let found = companion_source_for(&bundle.join("hyprbaric"));
        let _ = std::fs::remove_dir_all(&root);

        assert_eq!(found, Some(bundled));
    }

    #[test]
    fn cache_home_prefers_xdg_cache_home() {
        assert_eq!(
            cache_home_from(
                Some(std::ffi::OsString::from("/tmp/hyprbaric-xdg-cache")),
                Some(std::ffi::OsString::from("/home/unused")),
            ),
            PathBuf::from("/tmp/hyprbaric-xdg-cache")
        );
    }

    #[test]
    fn cache_home_falls_back_to_the_user_cache() {
        assert_eq!(
            cache_home_from(None, Some(std::ffi::OsString::from("/home/frederik"))),
            PathBuf::from("/home/frederik/.cache")
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
