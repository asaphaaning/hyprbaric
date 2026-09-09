use rinf::{DartSignal, RustSignal, SignalPiece};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, SignalPiece, Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum ModuleId {
    ActiveWindowTitle,
    SystemTray,
    Notifications,
    AudioDisplay,
    GlobalMenu,
}

#[derive(Serialize, Deserialize, DartSignal, SignalPiece, Clone, Debug, PartialEq, Eq, Hash)]
pub enum ModuleCommand {
    SetEnabled { module: ModuleId, enabled: bool },
}

#[derive(Serialize, Deserialize, SignalPiece, Clone, Debug, PartialEq, Eq, Hash)]
pub struct ModuleEntry {
    pub module: ModuleId,
    pub enabled: bool,
}

#[derive(Serialize, RustSignal)]
pub struct ModulesStatus {
    pub entries: Vec<ModuleEntry>,
}

#[derive(Serialize, RustSignal)]
pub enum ModuleCommandResult {
    Started {
        command: ModuleCommand,
    },
    Saved {
        command: ModuleCommand,
    },
    Failed {
        command: ModuleCommand,
        message: String,
    },
}
