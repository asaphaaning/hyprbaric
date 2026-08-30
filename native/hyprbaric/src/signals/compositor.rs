use rinf::{DartSignal, RustSignal, SignalPiece};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, SignalPiece, Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum WorkspaceSwitchKind {
    Relative,
    Absolute,
}

#[derive(Deserialize, DartSignal)]
pub struct WorkspaceSwitch {
    pub kind: WorkspaceSwitchKind,
    pub value: i32,
}

=======
#[derive(Serialize, SignalPiece, Clone, Debug, PartialEq)]
pub struct MonitorWorkspaceStatus {
    pub name: String,
    pub active_workspace_id: i32,
    pub is_focused: bool,
    pub width: i32,
    pub height: i32,
    pub refresh_hz: i32,
    /// Output scale; the logical size a client sees is width/scale.
    pub scale: f32,
}

#[derive(Serialize, RustSignal)]
pub struct WorkspaceStatus {
    pub id: i32,
    pub name: String,
    pub is_special: bool,
    pub occupied_workspace_ids: Vec<i32>,
    /// What each connected output is displaying, so a bar on an unfocused
    /// output can render its own workspace instead of the focused one.
    pub monitors: Vec<MonitorWorkspaceStatus>,
}

#[derive(Serialize, RustSignal)]
pub struct FocusedWindowStatus {
    pub app_name: Option<String>,
    pub title: Option<String>,
    pub hostname: String,
    pub monitors: Vec<MonitorFocusedWindowStatus>,
}
