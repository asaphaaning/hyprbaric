//! Shortcut settings snapshots and persistence.

use std::path::PathBuf;

use toml_edit::{Array, DocumentMut, Table, value};
use tracing::instrument;

use crate::config;

use super::{
    Shortcut,
    binding::{self, Binding, Mapping},
    domain,
};

/// A user-facing settings snapshot for every known shortcut.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Snapshot {
    /// Rows rendered by the settings panel.
    pub rows: Vec<Row>,
    /// The user config path Hyprbaric writes for shortcut overrides.
    pub writable_path: PathBuf,
    /// Optional status message for the settings surface.
    pub message: Option<String>,
}

/// One shortcut row in the settings panel.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Row {
    /// The shortcut meaning.
    pub shortcut: Shortcut,
    /// User-facing label.
    pub label: &'static str,
    /// User-facing description.
    pub description: &'static str,
    /// User-facing category.
    pub category: domain::Category,
    /// The built-in mapping.
    pub default_mapping: ViewMapping,
    /// The currently effective mapping.
    pub effective_mapping: ViewMapping,
    /// Where the effective mapping came from.
    pub source: Source,
    /// Conflicting Hyprbaric shortcut, if any.
    pub conflict: Option<Shortcut>,
}

/// A mapping projected for settings UI.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ViewMapping {
    /// The shortcut is bound to a chord.
    Bound(ViewBinding),
    /// The shortcut is disabled.
    Disabled,
}

/// A binding projected for settings UI.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ViewBinding {
    /// The activation phase.
    pub phase: binding::Phase,
    /// Ordered modifiers.
    pub modifiers: Vec<binding::Modifier>,
    /// Normalized key label.
    pub key: String,
    /// User-facing trigger string.
    pub display: String,
}

/// Effective mapping source.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Source {
    /// The default mapping is active.
    Default,
    /// A user override is active.
    UserOverride,
    /// The shortcut is disabled.
    Disabled,
}

/// Shortcut settings command.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Command {
    /// Load the effective settings snapshot.
    Load,
    /// Persist a replacement binding.
    SetBinding {
        /// Shortcut to update.
        shortcut: Shortcut,
        /// New binding.
        binding: Binding,
    },
    /// Persist a disabled mapping.
    Disable {
        /// Shortcut to disable.
        shortcut: Shortcut,
    },
    /// Remove the user override for this shortcut.
    Reset {
        /// Shortcut to reset.
        shortcut: Shortcut,
    },
}

impl Command {
    /// Returns the shortcut affected by this command, if any.
    pub const fn shortcut(&self) -> Option<Shortcut> {
        match self {
            Self::Load => None,
            Self::SetBinding { shortcut, .. }
            | Self::Disable { shortcut }
            | Self::Reset { shortcut } => Some(*shortcut),
        }
    }
}

/// Shortcut settings command report.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Report {
    /// A command started.
    Started(Command),
    /// A command completed.
    Saved(Command),
    /// A command failed.
    Failed { command: Command, message: String },
}

impl Report {
    /// Creates a started report.
    pub fn started(command: Command) -> Self {
        Self::Started(command)
    }

    /// Creates a saved report.
    pub fn saved(command: Command) -> Self {
        Self::Saved(command)
    }

    /// Creates a failed report.
    pub fn failed(command: Command, error: impl std::fmt::Display) -> Self {
        Self::Failed {
            command,
            message: error.to_string(),
        }
    }
}

/// Loads the current effective shortcut settings snapshot.
#[instrument(err)]
pub fn load() -> Result<Snapshot, Error> {
    let config = config::Configuration::load()?;
    snapshot(&config)
}

/// Persists a command to the user config and returns the new effective config.
#[instrument(skip(command), err)]
pub fn save(command: &Command) -> Result<config::Configuration, Error> {
    match command {
        Command::Load => {}
        Command::SetBinding { shortcut, binding } => {
            config::try_edit(|document| set_binding(document, *shortcut, binding))?;
        }
        Command::Disable { shortcut } => {
            config::try_edit(|document| disable(document, *shortcut))?;
        }
        Command::Reset { shortcut } => {
            config::try_edit(|document| reset(document, *shortcut))?;
        }
    }

    let config = config::Configuration::load()?;
    validate_unique_bindings(&config.shortcuts)?;
    Ok(config)
}

/// Projects a loaded configuration into a settings snapshot.
pub fn snapshot(config: &config::Configuration) -> Result<Snapshot, Error> {
    let writable_path = config::writable_user_path()?;
    let conflicts = conflicts(&config.shortcuts);
    let rows = Shortcut::ALL
        .iter()
        .map(|shortcut| row(&config.shortcuts, *shortcut, &conflicts))
        .collect();

    Ok(Snapshot {
        rows,
        writable_path,
        message: None,
    })
}

fn row(
    config: &super::Configuration,
    shortcut: Shortcut,
    conflicts: &[(Shortcut, Shortcut)],
) -> Row {
    let effective = config.mapping(shortcut);
    let default_mapping = Mapping::default_for(shortcut);
    let source = source(effective, &default_mapping);
    let conflict = conflicts.iter().find_map(|(left, right)| {
        if *left == shortcut {
            Some(*right)
        } else if *right == shortcut {
            Some(*left)
        } else {
            None
        }
    });

    Row {
        shortcut,
        label: shortcut.label(),
        description: shortcut.description(),
        category: shortcut.category(),
        default_mapping: (&default_mapping).into(),
        effective_mapping: effective.into(),
        source,
        conflict,
    }
}

fn source(effective: &Mapping, default_mapping: &Mapping) -> Source {
    if effective.is_disabled() {
        Source::Disabled
    } else if effective == default_mapping {
        Source::Default
    } else {
        Source::UserOverride
    }
}

fn validate_unique_bindings(config: &super::Configuration) -> Result<(), Error> {
    if let Some((left, right)) = conflicts(config).first().copied() {
        return Err(Error::Conflict { left, right });
    }

    Ok(())
}

fn conflicts(config: &super::Configuration) -> Vec<(Shortcut, Shortcut)> {
    let mut seen = Vec::<(Shortcut, Binding)>::new();
    let mut conflicts = Vec::new();

    for shortcut in Shortcut::ALL {
        let Some(binding) = config.mapping(*shortcut).binding() else {
            continue;
        };
        if let Some((other, _)) = seen
            .iter()
            .find(|(_, other_binding)| *other_binding == *binding)
        {
            conflicts.push((*other, *shortcut));
        } else {
            seen.push((*shortcut, binding.clone()));
        }
    }

    conflicts
}

fn shortcuts_table(document: &mut DocumentMut) -> Result<&mut Table, config::Error> {
    config::table(document.as_table_mut(), "shortcuts")
}

fn shortcut_table(
    document: &mut DocumentMut,
    shortcut: Shortcut,
) -> Result<&mut Table, config::Error> {
    config::table(shortcuts_table(document)?, shortcut.config_key())
}

fn set_binding(
    document: &mut DocumentMut,
    shortcut: Shortcut,
    binding: &Binding,
) -> Result<(), config::Error> {
    let table = shortcut_table(document, shortcut)?;
    table.clear();
    table["phase"] = value(match binding.configured_phase() {
        binding::Phase::Press => "press",
        binding::Phase::Release => "release",
    });
    let mut modifiers = Array::new();
    for modifier in binding.modifiers() {
        modifiers.push(match modifier {
            binding::Modifier::Logo => "logo",
            binding::Modifier::Ctrl => "ctrl",
            binding::Modifier::Shift => "shift",
            binding::Modifier::Alt => "alt",
            binding::Modifier::Num => "num",
        });
    }
    table["modifiers"] = value(modifiers);
    table["key"] = value(binding.key());
    Ok(())
}

fn disable(document: &mut DocumentMut, shortcut: Shortcut) -> Result<(), config::Error> {
    let table = shortcut_table(document, shortcut)?;
    table.clear();
    table["state"] = value("disabled");
    Ok(())
}

fn reset(document: &mut DocumentMut, shortcut: Shortcut) -> Result<(), config::Error> {
    let shortcuts = shortcuts_table(document)?;
    shortcuts.remove(shortcut.config_key());
    Ok(())
}

impl From<&Mapping> for ViewMapping {
    fn from(mapping: &Mapping) -> Self {
        match mapping {
            Mapping::Bound(binding) => Self::Bound(binding.into()),
            Mapping::Disabled(_) => Self::Disabled,
        }
    }
}

impl From<&Binding> for ViewBinding {
    fn from(binding: &Binding) -> Self {
        Self {
            phase: binding.configured_phase(),
            modifiers: binding.modifiers(),
            key: binding.key(),
            display: binding.display(),
        }
    }
}

/// Settings persistence error.
#[derive(Debug, thiserror::Error)]
pub enum Error {
    /// Configuration loading failed.
    #[error(transparent)]
    Configuration(#[from] config::Error),
    /// A binding was invalid.
    #[error(transparent)]
    InvalidBinding(#[from] binding::InvalidBinding),
    /// A binding conflicts with another Hyprbaric shortcut.
    #[error("`{left}` conflicts with `{right}`")]
    Conflict { left: Shortcut, right: Shortcut },
}

#[cfg(test)]
mod tests {
    use std::{
        fs,
        path::PathBuf,
        time::{SystemTime, UNIX_EPOCH},
    };

    use super::{Command, Source, ViewMapping, disable, reset, set_binding, snapshot};
    use crate::{
        config,
        shortcuts::{
            self,
            binding::{Binding, Modifier, Phase},
        },
    };

    #[test]
    fn snapshot_contains_every_shortcut() {
        let config = config::Configuration::default();
        let snapshot = snapshot(&config).expect("snapshot should project");

        assert_eq!(snapshot.rows.len(), shortcuts::Shortcut::ALL.len());
        assert!(
            snapshot
                .rows
                .iter()
                .all(|row| matches!(row.default_mapping, ViewMapping::Bound(_)))
        );
    }

    #[test]
    fn snapshot_marks_overridden_binding_source() {
        let config = toml::from_str::<config::Configuration>(
            r#"
            [shortcuts.controls]
            key = "P"
            modifiers = ["logo", "shift"]
            "#,
        )
        .expect("config should parse");
        let snapshot = snapshot(&config).expect("snapshot should project");
        let row = snapshot
            .rows
            .iter()
            .find(|row| row.shortcut == shortcuts::Shortcut::Controls)
            .expect("controls row should exist");

        assert_eq!(row.source, Source::UserOverride);
    }

    #[test]
    fn detects_duplicate_effective_bindings() {
        let config = toml::from_str::<config::Configuration>(
            r#"
            [shortcuts.controls]
            key = "C"
            modifiers = ["logo", "shift"]
            "#,
        )
        .expect("config should parse");

        let error = super::validate_unique_bindings(&config.shortcuts)
            .expect_err("duplicate binding should fail validation");

        assert!(matches!(error, super::Error::Conflict { .. }));
    }

    #[test]
    fn load_command_does_not_write() {
        assert!(matches!(Command::Load.shortcut(), None));
    }

    #[test]
    fn writer_uses_configured_shortcut_table_shape_for_every_shortcut() {
        for shortcut in shortcuts::Shortcut::ALL {
            let path = test_config_path(shortcut.config_key());
            let binding =
                Binding::from_parts(Phase::Press, [], "F13").expect("test binding should be valid");

            config::edit_path(&path, |document| {
                set_binding(document, *shortcut, &binding).expect("valid shortcut fixture")
            })
            .expect("shortcut config should be written");

            let source = fs::read_to_string(&path).expect("config should be readable");
            assert!(
                source.contains(&format!("[shortcuts.{}]", shortcut.config_key())),
                "config should use the canonical shortcuts table for {shortcut}: {source}"
            );
            assert!(
                !source.contains("[top-level.shortcuts."),
                "config should not write a nested top-level shortcuts table: {source}"
            );

            let config = toml::from_str::<config::Configuration>(&source)
                .expect("written shortcut config should parse through serde");
            let snapshot = snapshot(&config).expect("written config should project");
            let row = snapshot
                .rows
                .iter()
                .find(|row| row.shortcut == *shortcut)
                .expect("shortcut row should exist");

            assert_eq!(
                row.source,
                Source::UserOverride,
                "serde should recognize the table written for {shortcut}: {source}"
            );
            assert!(matches!(
                &row.effective_mapping,
                ViewMapping::Bound(binding) if binding.key == "F13"
            ));

            remove_test_config(path);
        }
    }

    #[test]
    fn writer_uses_configured_disabled_table_shape() {
        let path = test_config_path("disabled");

        config::edit_path(&path, |document| {
            disable(document, shortcuts::Shortcut::Controls);
        })
        .expect("disabled shortcut config should be written");

        let source = fs::read_to_string(&path).expect("config should be readable");
        assert!(
            source.contains("[shortcuts.controls]"),
            "config should use the canonical disabled shortcut table: {source}"
        );
        assert!(
            source.contains(r#"state = "disabled""#),
            "config should spell the serde disabled state: {source}"
        );

        let config = toml::from_str::<config::Configuration>(&source)
            .expect("disabled shortcut config should parse through serde");
        let snapshot = snapshot(&config).expect("disabled config should project");
        let row = snapshot
            .rows
            .iter()
            .find(|row| row.shortcut == shortcuts::Shortcut::Controls)
            .expect("controls row should exist");

        assert_eq!(row.source, Source::Disabled);
        assert_eq!(row.effective_mapping, ViewMapping::Disabled);

        remove_test_config(path);
    }

    #[test]
    fn reset_removes_the_canonical_shortcut_table_only() {
        let path = test_config_path("reset");
        let binding = Binding::from_parts(Phase::Press, [Modifier::Logo], "P")
            .expect("test binding should be valid");

        config::edit_path(&path, |document| {
            set_binding(document, shortcuts::Shortcut::Controls, &binding);
            disable(document, shortcuts::Shortcut::LockSession);
        })
        .expect("shortcut config should be written");
        config::edit_path(&path, |document| {
            reset(document, shortcuts::Shortcut::Controls);
        })
        .expect("shortcut config should be reset");

        let source = fs::read_to_string(&path).expect("config should be readable");
        assert!(
            !source.contains("[shortcuts.controls]"),
            "reset should remove only the controls table: {source}"
        );
        assert!(
            source.contains("[shortcuts.lock_session]"),
            "reset should preserve sibling shortcut tables: {source}"
        );

        let config = toml::from_str::<config::Configuration>(&source)
            .expect("reset shortcut config should parse through serde");
        let snapshot = snapshot(&config).expect("reset config should project");
        let controls = snapshot
            .rows
            .iter()
            .find(|row| row.shortcut == shortcuts::Shortcut::Controls)
            .expect("controls row should exist");
        let lock_session = snapshot
            .rows
            .iter()
            .find(|row| row.shortcut == shortcuts::Shortcut::LockSession)
            .expect("lock session row should exist");

        assert_eq!(controls.source, Source::Default);
        assert_eq!(lock_session.source, Source::Disabled);

        remove_test_config(path);
    }

    fn test_config_path(name: &str) -> PathBuf {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("system time should be after epoch")
            .as_nanos();
        std::env::temp_dir().join(format!(
            "hyprbaric-shortcut-settings-{name}-{}-{nanos}.toml",
            std::process::id()
        ))
    }

    fn remove_test_config(path: PathBuf) {
        let _ = fs::remove_file(path);
    }
}
