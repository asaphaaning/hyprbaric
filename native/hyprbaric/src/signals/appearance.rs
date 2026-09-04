use rinf::{DartSignal, RustSignal, SignalPiece};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, SignalPiece, Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum AppearancePosition {
    Top,
    Bottom,
}

/// Which outputs an appearance setting applies to.
#[derive(Serialize, Deserialize, SignalPiece, Clone, Debug, PartialEq, Eq, Hash)]
pub enum AppearanceMonitorTarget {
    Primary,
    All,
    Named { name: String },
}

#[derive(Serialize, Deserialize, DartSignal, SignalPiece, Clone, Debug, PartialEq, Eq, Hash)]
pub enum AppearanceCommand {
    SetPosition { position: AppearancePosition },
    SetOpacity { opacity: u8 },
    SetCornerRadius { corner_radius: u8 },
    SetAccentHue { accent_hue: u16 },
    RestoreDefaults,
}

#[derive(Serialize, RustSignal)]
pub struct AppearanceStatus {
    pub position: AppearancePosition,
    pub monitor: AppearanceMonitorTarget,
    pub opacity: u8,
    pub corner_radius: u8,
    pub accent_hue: u16,
}

#[derive(Serialize, RustSignal)]
pub enum AppearanceCommandResult {
    Started {
        command: AppearanceCommand,
    },
    Saved {
        command: AppearanceCommand,
    },
    Failed {
        command: AppearanceCommand,
        message: String,
    },
}
