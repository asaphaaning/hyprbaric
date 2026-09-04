use std::{
    env, fs, io,
    path::{Path, PathBuf},
    time::Duration,
};

use serde::{Deserialize, Deserializer, de};
use toml_edit::{DocumentMut, Item, Table};
use tracing::instrument;

use crate::{
    appearance, audio, brightness, modules, network, night_light, power, schedule, setup,
    shortcuts, workspaces,
};

#[derive(Clone, Debug, Default, Deserialize)]
#[serde(default)]
pub struct Configuration {
    pub appearance: appearance::Configuration,
    pub audio: audio::Configuration,
    pub brightness: brightness::Configuration,
    pub modules: modules::Configuration,
    pub network: network::Configuration,
    pub night_light: night_light::Configuration,
    pub power: power::Configuration,
    pub schedules: schedule::Configuration,
    pub setup: setup::Configuration,
    pub shortcuts: shortcuts::Configuration,
    pub workspaces: workspaces::Configuration,
}

impl Configuration {
    #[instrument(err)]
    pub fn load() -> Result<Self, Error> {
        for candidate in candidates() {
            match read(&candidate)? {
                Some(config) => {
                    tracing::info!(path = %candidate.display(), "Loaded Hyprbaric config");
                    return Ok(config);
                }
                None => continue,
            }
        }

        tracing::debug!("No Hyprbaric config override found; using defaults");
        Ok(Self::default())
    }
}

pub(crate) fn writable_user_path() -> Result<PathBuf, Error> {
    // Reads prefer `HYPRBARIC_CONFIG` first (see `candidates`), so writes
    // target it when set. Otherwise completion would land in a file the next
    // launch never reads.
    if let Some(path) = env::var_os("HYPRBARIC_CONFIG") {
        return Ok(PathBuf::from(path));
    }

    let Some(config_home) = config_home() else {
        return Err(Error::ConfigHome);
    };
    Ok(config_home.join("hyprbaric/config.toml"))
}

/// Serializes read-modify-write cycles against the user configuration.
///
/// Every editor goes through this lock so concurrent commands from different
/// modules cannot interleave a read between another command's read and write.
static EDIT_LOCK: std::sync::Mutex<()> = std::sync::Mutex::new(());

fn edit_lock() -> std::sync::MutexGuard<'static, ()> {
    EDIT_LOCK
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner)
}

/// Edits the writable user configuration and replaces it atomically.
///
/// Feature modules own the shape of their TOML tables. This boundary owns the
/// shared filesystem operation so parsing and replacement behave consistently.
#[instrument(skip(apply), err)]
pub(crate) fn edit(apply: impl FnOnce(&mut DocumentMut)) -> Result<(), Error> {
    try_edit(|document| {
        apply(document);
        Ok::<(), Error>(())
    })
}

/// Edits the user configuration, skipping the replacement when `apply` fails.
///
/// A fallible editor must never persist a half-applied document, so the file
/// is left untouched and the original error propagates to the caller.
#[instrument(skip(apply), err)]
pub(crate) fn try_edit<E>(apply: impl FnOnce(&mut DocumentMut) -> Result<(), E>) -> Result<(), E>
where
    E: From<Error> + std::fmt::Debug + std::fmt::Display,
{
    let _guard = edit_lock();
    let path = writable_user_path()?;
    edit_path_fallible(&path, apply)
}

/// Edits one module-owned table, rejecting incompatible user configuration.
#[instrument(skip(apply), err)]
pub(crate) fn edit_table(name: &'static str, apply: impl FnOnce(&mut Table)) -> Result<(), Error> {
    try_edit(|document| {
        if !document.as_table().contains_key(name) {
            document[name] = Item::Table(Table::new());
        }
        let table = document[name]
            .as_table_mut()
            .ok_or(Error::InvalidTable { name })?;
        apply(table);
        Ok(())
    })
}

pub(crate) fn edit_path(path: &Path, apply: impl FnOnce(&mut DocumentMut)) -> Result<(), Error> {
    edit_path_fallible(path, |document| {
        apply(document);
        Ok::<(), Error>(())
    })
}

fn edit_path_fallible<E>(
    path: &Path,
    apply: impl FnOnce(&mut DocumentMut) -> Result<(), E>,
) -> Result<(), E>
where
    E: From<Error>,
{
    let source = match fs::read_to_string(path) {
        Ok(source) => source,
        Err(error) if error.kind() == io::ErrorKind::NotFound => String::new(),
        Err(source) => {
            return Err(Error::ReadDocument {
                path: path.to_path_buf(),
                source,
            }
            .into());
        }
    };
    let mut document = source.parse::<DocumentMut>().map_err(|source| {
        E::from(Error::ParseDocument {
            path: path.to_path_buf(),
            source,
        })
    })?;

    apply(&mut document)?;
    replace(path, document.to_string().as_bytes())?;
    Ok(())
}

fn replace(path: &Path, bytes: &[u8]) -> Result<(), Error> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|source| Error::CreateDirectory {
            path: parent.to_path_buf(),
            source,
        })?;
    }

    let temporary = path.with_extension("toml.tmp");
    fs::write(&temporary, bytes).map_err(|source| Error::WriteDocument {
        path: temporary.clone(),
        source,
    })?;
    fs::rename(&temporary, path).map_err(|source| Error::ReplaceDocument {
        from: temporary,
        to: path.to_path_buf(),
        source,
    })
}

/// A non-zero timing cadence loaded from Hyprbaric configuration.
///
/// [`Cadence`] accepts human-readable durations through [`humantime_serde`]
/// while ensuring timer intervals and command timeouts cannot be zero.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct Cadence(Duration);

impl Cadence {
    pub(crate) const fn seconds(seconds: u64) -> Self {
        Self(Duration::from_secs(seconds))
    }

    pub(crate) const fn milliseconds(milliseconds: u64) -> Self {
        Self(Duration::from_millis(milliseconds))
    }

    pub(crate) const fn duration(self) -> Duration {
        self.0
    }
}

impl<'de> Deserialize<'de> for Cadence {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let duration: Duration = humantime_serde::deserialize(deserializer)?;

        if duration.is_zero() {
            return Err(de::Error::custom("cadence cannot be zero"));
        }

        Ok(Self(duration))
    }
}

fn read(path: &Path) -> Result<Option<Configuration>, Error> {
    let source = match fs::read_to_string(path) {
        Ok(source) => source,
        Err(source) if source.kind() == io::ErrorKind::NotFound => return Ok(None),
        Err(source) => {
            return Err(Error::Read {
                path: path.to_path_buf(),
                source,
            });
        }
    };

    toml::from_str(&source)
        .map(Some)
        .map_err(|source| Error::Parse {
            path: path.to_path_buf(),
            source,
        })
}

fn candidates() -> Vec<PathBuf> {
    let mut paths = Vec::new();

    if let Some(path) = env::var_os("HYPRBARIC_CONFIG") {
        paths.push(PathBuf::from(path));
    }

    if let Some(config_home) = config_home() {
        paths.push(config_home.join("hyprbaric/config.toml"));
    }

    for config_dir in config_dirs() {
        let path = config_dir.join("hyprbaric/config.toml");
        if !paths.contains(&path) {
            paths.push(path);
        }
    }

    paths
}

fn config_home() -> Option<PathBuf> {
    env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .or_else(|| env::var_os("HOME").map(|home| PathBuf::from(home).join(".config")))
}

fn config_dirs() -> Vec<PathBuf> {
    env::var_os("XDG_CONFIG_DIRS")
        .map(|dirs| env::split_paths(&dirs).collect())
        .unwrap_or_else(|| vec![PathBuf::from("/etc/xdg")])
}

#[cfg(test)]
pub(crate) fn environment_lock() -> std::sync::MutexGuard<'static, ()> {
    static LOCK: std::sync::Mutex<()> = std::sync::Mutex::new(());
    LOCK.lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner)
}

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("could not determine the user config directory")]
    ConfigHome,
    #[error("failed to read config `{}`", path.display())]
    Read {
        path: PathBuf,
        #[source]
        source: io::Error,
    },
    #[error("failed to parse config `{}`", path.display())]
    Parse {
        path: PathBuf,
        #[source]
        source: toml::de::Error,
    },
    #[error("failed to read user config `{}`", path.display())]
    ReadDocument {
        path: PathBuf,
        #[source]
        source: io::Error,
    },
    #[error("failed to parse user config `{}` for editing", path.display())]
    ParseDocument {
        path: PathBuf,
        #[source]
        source: toml_edit::TomlError,
    },
    #[error("configuration item `{name}` must be a table")]
    InvalidTable { name: &'static str },
    #[error("failed to create user config directory `{}`", path.display())]
    CreateDirectory {
        path: PathBuf,
        #[source]
        source: io::Error,
    },
    #[error("failed to write user config `{}`", path.display())]
    WriteDocument {
        path: PathBuf,
        #[source]
        source: io::Error,
    },
    #[error("failed to replace user config `{}` with `{}`", to.display(), from.display())]
    ReplaceDocument {
        from: PathBuf,
        to: PathBuf,
        #[source]
        source: io::Error,
    },
}

#[cfg(test)]
mod tests {
    use std::{fs, time::Duration};

    use serde::Deserialize;

    use crate::setup;

    use super::{Cadence, Configuration};

    #[derive(Debug, Deserialize)]
    struct CadenceFixture {
        cadence: Cadence,
    }

    #[test]
    fn cadence_accepts_human_durations() {
        let fixture = toml::from_str::<CadenceFixture>(r#"cadence = "250ms""#)
            .expect("cadence should parse human duration");

        assert_eq!(fixture.cadence.duration(), Duration::from_millis(250));
    }

    #[test]
    fn cadence_rejects_zero_duration() {
        let error = toml::from_str::<CadenceFixture>(r#"cadence = "0s""#)
            .expect_err("zero cadence should be rejected");

        assert!(error.to_string().contains("cadence cannot be zero"));
    }

    #[test]
    fn cadence_constructors_are_duration_projections() {
        assert_eq!(Cadence::seconds(2).duration(), Duration::from_secs(2));
        assert_eq!(
            Cadence::milliseconds(300).duration(),
            Duration::from_millis(300)
        );
    }

    #[test]
    fn scalar_setup_value_falls_back_to_setup_defaults() {
        let configuration = toml::from_str::<Configuration>("setup = \"already-complete\"\n")
            .expect("scalar setup should degrade instead of failing");

        assert_eq!(configuration.setup, setup::Configuration::default());
    }

    #[test]
    fn unknown_setup_values_fall_back_to_setup_defaults() {
        let configuration =
            toml::from_str::<Configuration>("[setup]\nstartup = \"sometimes\"\ncompleted = 7\n")
                .expect("malformed setup should degrade instead of failing");

        assert_eq!(configuration.setup, setup::Configuration::default());
    }

    #[test]
    fn try_edit_skips_replacement_when_the_editor_fails() {
        let path = std::env::temp_dir().join(format!(
            "hyprbaric-config-test-{}-fallible.tmp",
            std::process::id()
        ));
        fs::write(&path, "answer = 42\n").expect("fixture config should be written");

        let result =
            super::edit_path_fallible(&path, |_| Err::<(), super::Error>(super::Error::ConfigHome));

        assert!(result.is_err());
        assert_eq!(
            fs::read_to_string(&path).expect("config should be readable"),
            "answer = 42\n"
        );

        let _ = fs::remove_file(&path);
    }

    #[test]
    fn configuration_accepts_audio_volume_step() {
        let config = toml::from_str::<Configuration>("[audio]\nvolume_step = 9")
            .expect("audio configuration should parse");

        assert_eq!(config.audio.volume_step().as_u8(), 9);
    }
}
