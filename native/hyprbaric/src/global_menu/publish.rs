//! Dart projection of the focused application's menu.
//!
//! Domain types stay in [`super`]. This module is the transport edge: each
//! status is a [`From`] of the menu it describes, then a RINF signal.

use crate::signals::{
    GlobalMenuItem, GlobalMenuItemId, GlobalMenuItemKind, GlobalMenuSection, GlobalMenuSectionId,
    GlobalMenuSectionStatus, GlobalMenuStatus,
};
use rinf::RustSignal;

use super::{Error, Item, ItemId, ItemKind, Menu, Section, SectionId};

pub(crate) fn headings(menu: &Menu) {
    GlobalMenuStatus::from(menu).send_signal_to_dart();
}

pub(crate) fn no_headings(error: &Error) {
    GlobalMenuStatus::from(error).send_signal_to_dart();
}

pub(crate) fn section_items(id: &SectionId, items: &[Item]) {
    GlobalMenuSectionStatus::from((id, items)).send_signal_to_dart();
}

pub(crate) fn section_failed(id: &SectionId, error: &Error) {
    GlobalMenuSectionStatus::from((id, error)).send_signal_to_dart();
}

impl From<&Menu> for GlobalMenuStatus {
    fn from(menu: &Menu) -> Self {
        Self {
            sections: menu.sections.iter().map(GlobalMenuSection::from).collect(),
            message: None,
        }
    }
}

impl From<&Error> for GlobalMenuStatus {
    fn from(error: &Error) -> Self {
        Self {
            sections: Vec::new(),
            message: Some(error.to_string()),
        }
    }
}

impl From<&Section> for GlobalMenuSection {
    fn from(section: &Section) -> Self {
        Self {
            id: GlobalMenuSectionId::from(&section.id),
            label: section.label.clone(),
            enabled: section.enabled,
        }
    }
}

impl From<(&SectionId, &[Item])> for GlobalMenuSectionStatus {
    fn from((id, items): (&SectionId, &[Item])) -> Self {
        Self {
            section: GlobalMenuSectionId::from(id),
            items: items.iter().map(GlobalMenuItem::from).collect(),
            message: None,
        }
    }
}

impl From<(&SectionId, &Error)> for GlobalMenuSectionStatus {
    fn from((id, error): (&SectionId, &Error)) -> Self {
        Self {
            section: GlobalMenuSectionId::from(id),
            items: Vec::new(),
            message: Some(error.to_string()),
        }
    }
}

impl From<&Item> for GlobalMenuItem {
    fn from(item: &Item) -> Self {
        Self {
            label: item.label.clone(),
            enabled: item.enabled,
            kind: GlobalMenuItemKind::from(&item.kind),
            shortcut: item.shortcut.clone(),
            activation: item.activation.as_ref().map(GlobalMenuItemId::from),
            submenu: item.submenu.as_ref().map(GlobalMenuSectionId::from),
        }
    }
}

impl From<&ItemKind> for GlobalMenuItemKind {
    fn from(kind: &ItemKind) -> Self {
        match kind {
            ItemKind::Standard => Self::Standard,
            ItemKind::Separator => Self::Separator,
            ItemKind::Group => Self::Group,
            ItemKind::Checkmark { checked } => Self::Checkmark { checked: *checked },
            ItemKind::Radio { selected } => Self::Radio {
                selected: *selected,
            },
        }
    }
}

impl From<&SectionId> for GlobalMenuSectionId {
    fn from(id: &SectionId) -> Self {
        match id {
            SectionId::DbusMenu { id } => Self::DbusMenu { id: *id },
            SectionId::Gtk { group, menu } => Self::Gtk {
                group: *group,
                menu: *menu,
            },
        }
    }
}

impl From<&ItemId> for GlobalMenuItemId {
    fn from(id: &ItemId) -> Self {
        match id {
            ItemId::DbusMenu { id } => Self::DbusMenu { id: *id },
            ItemId::Gtk { action } => Self::Gtk {
                action: action.clone(),
            },
        }
    }
}
