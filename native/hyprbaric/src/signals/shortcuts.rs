use rinf::{DartSignal, RustSignal, SignalPiece};
use serde::{Deserialize, Serialize};

/// A shortcut effect handled by the Flutter bar.
///
/// Native shortcut actions stay inside Rust. Only this closed UI event
/// vocabulary crosses the RINF boundary.
#[derive(Serialize, RustSignal, Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum HotkeyEvent {
    ToggleAppLauncher {},
    ToggleControls {},
    OpenBarSettings {},
    ToggleSessionLauncher {},
    VolumeUp { step: u8 },
    VolumeDown { step: u8 },
    ToggleMute {},
    BrightnessUp {},
    BrightnessDown {},
    ColorPick {},
    ToggleRecording {},
    ToggleDoNotDisturb {},
    ToggleNightLight {},
    ToggleCaffeine {},
}

/// A shortcut known by Hyprbaric's settings surface.
#[derive(Serialize, Deserialize, SignalPiece, Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum ShortcutSettingId {
    AppLauncher,
    Controls,
    BarSettings,
    SessionLauncher,
    LockSession,
    CaptureRegion,
    CaptureWindow,
    CaptureFullScreen,
    ColorPick,
    ToggleRecording,
    ToggleDoNotDisturb,
    ToggleNightLight,
    ToggleCaffeine,
    VolumeUp,
    VolumeDown,
    ToggleMute,
    BrightnessUp,
    BrightnessDown,
}

/// Shortcut grouping used by the settings panel.
#[derive(Serialize, Deserialize, SignalPiece, Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum ShortcutSettingCategory {
    Bar,
    Session,
    Capture,
    Audio,
    Display,
}

/// Shortcut activation phase.
#[derive(Serialize, Deserialize, SignalPiece, Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum ShortcutBindingPhase {
    Press,
    Release,
}

/// Supported shortcut modifiers.
#[derive(Serialize, Deserialize, SignalPiece, Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum ShortcutModifier {
    Logo,
    Ctrl,
    Shift,
    Alt,
    Num,
}

/// A user-selected shortcut binding without derived display copy.
#[derive(Serialize, Deserialize, SignalPiece, Clone, Debug, PartialEq, Eq, Hash)]
pub struct ShortcutBindingInput {
    pub phase: ShortcutBindingPhase,
    pub modifiers: Vec<ShortcutModifier>,
    pub key: String,
}

/// A shortcut binding projected for display.
#[derive(Serialize, Deserialize, SignalPiece, Clone, Debug, PartialEq, Eq, Hash)]
pub struct ShortcutBindingView {
    pub phase: ShortcutBindingPhase,
    pub modifiers: Vec<ShortcutModifier>,
    pub key: String,
    pub display: String,
}

/// A shortcut mapping projected for display.
#[derive(Serialize, Deserialize, SignalPiece, Clone, Debug, PartialEq, Eq, Hash)]
pub enum ShortcutMappingView {
    Bound { binding: ShortcutBindingView },
    Disabled,
}

/// Where the current shortcut mapping came from.
#[derive(Serialize, Deserialize, SignalPiece, Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum ShortcutMappingSource {
    Builtin,
    UserOverride,
    Disabled,
}

/// One keybinding row in the settings panel.
#[derive(Serialize, Deserialize, SignalPiece, Clone, Debug, PartialEq, Eq, Hash)]
pub struct ShortcutSettingsRow {
    pub shortcut: ShortcutSettingId,
    pub label: String,
    pub description: String,
    pub category: ShortcutSettingCategory,
    pub default_mapping: ShortcutMappingView,
    pub effective_mapping: ShortcutMappingView,
    pub source: ShortcutMappingSource,
    pub conflict: Option<ShortcutSettingId>,
}

/// Current shortcut settings snapshot.
#[derive(Serialize, RustSignal)]
pub struct ShortcutSettingsSnapshot {
    pub rows: Vec<ShortcutSettingsRow>,
    pub writable_path: String,
    pub message: Option<String>,
}

/// A shortcut settings command.
#[derive(Serialize, Deserialize, DartSignal, SignalPiece, Clone, Debug, PartialEq, Eq, Hash)]
pub enum ShortcutSettingsRequest {
    Load,
    SetBinding {
        shortcut: ShortcutSettingId,
        binding: ShortcutBindingInput,
    },
    Disable {
        shortcut: ShortcutSettingId,
    },
    Reset {
        shortcut: ShortcutSettingId,
    },
}

/// Shortcut settings command outcome.
#[derive(Serialize, Deserialize, SignalPiece, Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum ShortcutSettingsCommandOutcome {
    Started,
    Saved,
    Failed,
}

/// Result for a shortcut settings command.
#[derive(Serialize, RustSignal)]
pub struct ShortcutSettingsCommandResult {
    pub command: ShortcutSettingsRequest,
    pub outcome: ShortcutSettingsCommandOutcome,
    pub shortcut: Option<ShortcutSettingId>,
    pub message: Option<String>,
}
