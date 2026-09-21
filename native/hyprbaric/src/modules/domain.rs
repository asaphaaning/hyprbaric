//! Bar module visibility settings.

use serde::Deserialize;

#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "snake_case")]
pub enum Module {
    ActiveWindowTitle,
    SystemTray,
    Notifications,
    AudioDisplay,
    GlobalMenu,
    SystemOccupancy,
}

#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Eq)]
#[serde(default)]
pub struct ModuleSettings {
    enabled: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Entry {
    pub module: Module,
    pub enabled: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Snapshot {
    pub entries: Vec<Entry>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Command {
    SetEnabled { module: Module, enabled: bool },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Report {
    Started(Command),
    Saved(Command),
    Failed { command: Command, message: String },
}

impl Default for ModuleSettings {
    fn default() -> Self {
        Self::ENABLED
    }
}

impl ModuleSettings {
    /// A module the user has not turned off.
    pub const ENABLED: Self = Self { enabled: true };

    /// A module the user has not yet asked for.
    pub const DISABLED: Self = Self { enabled: false };

    pub const fn enabled(self) -> bool {
        self.enabled
    }

    pub const fn with_enabled(self, enabled: bool) -> Self {
        Self { enabled, ..self }
    }
}

impl Module {
    pub const ALL: [Self; 6] = [
        Self::ActiveWindowTitle,
        Self::SystemTray,
        Self::SystemOccupancy,
        Self::Notifications,
        Self::AudioDisplay,
        Self::GlobalMenu,
    ];

    pub const fn config_key(self) -> &'static str {
        match self {
            Self::ActiveWindowTitle => "active_window_title",
            Self::SystemTray => "system_tray",
            Self::SystemOccupancy => "system_occupancy",
            Self::Notifications => "notifications",
            Self::AudioDisplay => "audio_display",
            Self::GlobalMenu => "global_menu",
        }
    }

    /// Whether the module is on for someone who has never configured it.
    ///
    /// Modules show by default because showing one costs nothing. The global
    /// menu waits to be asked for, because it takes ownership of the desktop's
    /// menu bar.
    pub const fn default_enabled(self) -> bool {
        !matches!(self, Self::GlobalMenu)
    }
}
