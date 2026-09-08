use rinf::{DartSignal, RustSignal, SignalPiece};
use serde::{Deserialize, Serialize};

/// Addresses a menu whose rows Flutter can ask for.
///
/// The address stays in the vocabulary of the protocol that owns it, so the
/// bar never has to know which one a window speaks.
#[derive(Serialize, Deserialize, SignalPiece, Clone, Debug, PartialEq, Eq, Hash)]
pub enum GlobalMenuSectionId {
    DbusMenu {
        id: i32,
    },
    /// A GTK menubar menu, addressed by the group and menu it lives in.
    Gtk {
        group: u32,
        menu: u32,
    },
    /// A GTK application menu, on a different object path than the menubar.
    GtkAppMenu {
        group: u32,
        menu: u32,
    },
}

/// Addresses a row that can be activated.
#[derive(Serialize, Deserialize, SignalPiece, Clone, Debug, PartialEq, Eq, Hash)]
pub enum GlobalMenuItemId {
    DbusMenu {
        id: i32,
    },
    Gtk {
        action: String,
        target: Option<Vec<u8>>,
    },
}

/// The shape of one row.
#[derive(Serialize, Deserialize, SignalPiece, Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum GlobalMenuItemKind {
    Standard,
    Separator,
    Group,
    Checkmark { checked: bool },
    Radio { selected: bool },
}

/// One native menu session, bound to a focused compositor window.
#[derive(Serialize, Deserialize, SignalPiece, Clone, Debug, PartialEq, Eq, Hash)]
pub struct GlobalMenuSession {
    /// Opaque native generation, never reused during this process.
    pub generation: u64,
    /// Compositor window this menu was captured for.
    pub window: String,
}

/// A section address is meaningful only inside its owning session.
#[derive(Serialize, Deserialize, SignalPiece, Clone, Debug, PartialEq, Eq, Hash)]
pub struct GlobalMenuAddress {
    /// Session that exported the section.
    pub session: GlobalMenuSession,
    /// Exporter-local menu identifier.
    pub section: GlobalMenuSectionId,
}

/// Ordered menu operations. One RINF route preserves open/activate/close order.
#[derive(Deserialize, DartSignal)]
pub enum GlobalMenuCommand {
    /// Read headings for the requested focus observation.
    Read { window: Option<String> },
    /// Announce and read a popup in its originating session.
    Open { address: GlobalMenuAddress },
    /// Close an announced popup, even if focus has subsequently changed.
    Dismiss { address: GlobalMenuAddress },
    /// Activate a row only in the session that supplied it.
    Activate {
        session: GlobalMenuSession,
        item: GlobalMenuItemId,
    },
}

/// The focused window's headings, or why there are none.
#[derive(Serialize, RustSignal)]
pub struct GlobalMenuStatus {
    /// Requested focus observation, also present for an absent menu.
    pub window: Option<String>,
    /// Present only when an exporter was captured.
    pub session: Option<GlobalMenuSession>,
    pub sections: Vec<GlobalMenuSection>,
    pub message: Option<String>,
}

/// The rows of one heading, reported against the heading that asked.
#[derive(Serialize, RustSignal)]
pub struct GlobalMenuSectionStatus {
    /// Session that owns these rows.
    pub session: GlobalMenuSession,
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

/// How the compositor-side half of the global menu is doing.
///
/// Installing the companion can take minutes and can end somewhere only the
/// user can take further, so the bar reports the state rather than failing
/// quietly.
#[derive(Serialize, RustSignal)]
pub enum GlobalMenuIntegrationStatus {
    /// The global menu module is switched off.
    Disabled,
    /// The companion is being installed or rebuilt.
    Preparing,
    /// The companion is loaded and menus can be read.
    Ready,
    /// Installation stopped on something the bar cannot resolve itself.
    Blocked {
        message: String,
        instruction: Option<String>,
    },
}
