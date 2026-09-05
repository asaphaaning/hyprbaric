use rinf::{DartSignal, RustSignal, SignalPiece};
use serde::{Deserialize, Serialize};

/// Addresses a menu whose rows Flutter can ask for.
///
/// The address stays in the vocabulary of the protocol that owns it, so the
/// bar never has to know which one a window speaks.
#[derive(Serialize, Deserialize, SignalPiece, Clone, Debug, PartialEq, Eq, Hash)]
pub enum GlobalMenuSectionId {
    DbusMenu { id: i32 },
    Gtk { group: u32, menu: u32 },
}

/// Addresses a row that can be activated.
#[derive(Serialize, Deserialize, SignalPiece, Clone, Debug, PartialEq, Eq, Hash)]
pub enum GlobalMenuItemId {
    DbusMenu { id: i32 },
    Gtk { action: String },
}

/// The shape of one row.
#[derive(Serialize, Deserialize, SignalPiece, Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum GlobalMenuItemKind {
    Standard,
    Separator,
    Checkmark { checked: bool },
    Radio { selected: bool },
}

/// Asks for the focused window's headings.
#[derive(Deserialize, DartSignal)]
pub struct GlobalMenuRequest;

/// Asks for the rows beneath one heading.
#[derive(Deserialize, DartSignal)]
pub struct GlobalMenuSectionRequest {
    pub section: GlobalMenuSectionId,
}

/// Asks the focused application to run one row.
#[derive(Deserialize, DartSignal)]
pub struct GlobalMenuActivateRequest {
    pub item: GlobalMenuItemId,
}

/// The focused window's headings, or why there are none.
#[derive(Serialize, RustSignal)]
pub struct GlobalMenuStatus {
    pub sections: Vec<GlobalMenuSection>,
    pub message: Option<String>,
}

/// The rows of one heading, reported against the heading that asked.
#[derive(Serialize, RustSignal)]
pub struct GlobalMenuSectionStatus {
    pub section: GlobalMenuSectionId,
    pub items: Vec<GlobalMenuItem>,
    pub message: Option<String>,
}

#[derive(Serialize, SignalPiece, Clone, Debug, PartialEq, Eq)]
pub struct GlobalMenuSection {
    pub id: GlobalMenuSectionId,
    pub label: String,
    pub enabled: bool,
}

#[derive(Serialize, SignalPiece, Clone, Debug, PartialEq, Eq)]
pub struct GlobalMenuItem {
    pub label: String,
    pub enabled: bool,
    pub kind: GlobalMenuItemKind,
    pub shortcut: Option<String>,
    pub activation: Option<GlobalMenuItemId>,
    pub submenu: Option<GlobalMenuSectionId>,
}
