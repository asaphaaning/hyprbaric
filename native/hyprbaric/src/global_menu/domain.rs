//! Application-menu values, independent of transport and runtime.

/// The headings the focused application exports.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Menu {
    /// Top-level headings, in application-defined order.
    pub sections: Vec<Section>,
}

/// One heading, whose rows are read when it opens.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Section {
    /// Address of the rows beneath this heading.
    pub id: SectionId,
    /// User-visible heading.
    pub label: String,
    /// Whether the heading can be opened.
    pub enabled: bool,
}

/// One row of an opened menu.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Item {
    /// User-visible text.
    pub label: String,
    /// Whether the application currently allows activation.
    pub enabled: bool,
    /// What kind of row this is.
    pub kind: ItemKind,
    /// Accelerator text, as the application spells it.
    pub shortcut: Option<String>,
    /// Present when activating the row does something.
    pub activation: Option<ItemId>,
    /// Present when the row opens a nested menu.
    pub submenu: Option<SectionId>,
}

/// The shape of one row.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ItemKind {
    /// An ordinary row.
    Standard,
    /// A divider carrying no action.
    Separator,
    /// A caption naming the rows beneath it, carrying no action of its own.
    ///
    /// GTK named `:section` links and D-BusMenu `x-kde-title` both project here.
    Group,
    /// A checkable row and its current state.
    Checkmark { checked: bool },
    /// One option of a mutually exclusive group.
    Radio { selected: bool },
}

/// Addresses a menu whose rows can be read.
#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub enum SectionId {
    /// A D-BusMenu subtree, addressed by item identifier.
    DbusMenu { id: i32 },
    /// A GTK menubar menu, addressed by the group and menu it lives in.
    Gtk { group: u32, menu: u32 },
    /// A GTK application menu, on a different object path than the menubar.
    GtkAppMenu { group: u32, menu: u32 },
}

impl SectionId {
    pub(in crate::global_menu) fn gtk(group: u32, menu: u32, app_menu: bool) -> Self {
        if app_menu {
            Self::GtkAppMenu { group, menu }
        } else {
            Self::Gtk { group, menu }
        }
    }

    pub(in crate::global_menu) fn as_gtk(&self) -> Option<(u32, u32, bool)> {
        match self {
            Self::Gtk { group, menu } => Some((*group, *menu, false)),
            Self::GtkAppMenu { group, menu } => Some((*group, *menu, true)),
            Self::DbusMenu { .. } => None,
        }
    }
}

/// Addresses a row that can be activated.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ItemId {
    /// A D-BusMenu row, addressed by item identifier.
    DbusMenu { id: i32 },
    /// A GTK action, named with its `app.` or `win.` scope.
    Gtk {
        action: String,
        /// D-Bus-marshalled GVariant for `Activate`, when the item names a target.
        target: Option<Vec<u8>>,
    },
}

/// A live menu change; the application chooses how to deliver it.
#[derive(Clone, Debug)]
pub enum Update {
    /// Top-level headings for one session.
    Headings { session: super::Session, menu: Menu },
    /// Rows for a section already associated with the session.
    Section {
        session: super::Session,
        section: SectionId,
        items: Vec<Item>,
    },
}
