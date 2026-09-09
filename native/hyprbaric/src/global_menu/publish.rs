//! Dart projection of the focused application's menu.
//!
//! Domain types stay in [`super`]. This module is the transport edge: each
//! status is a [`From`] of the menu it describes, then a RINF signal.

use crate::signals::{
    GlobalMenuItem, GlobalMenuItemId, GlobalMenuItemKind, GlobalMenuSection, GlobalMenuSectionId,
    GlobalMenuSectionStatus, GlobalMenuSession, GlobalMenuStatus,
};
use rinf::RustSignal;

use super::{Error, Item, ItemId, ItemKind, Menu, Section, SectionId, Session};

pub(crate) fn headings(session: &Session, menu: &Menu) {
    GlobalMenuStatus {
        window: Some(session.window.as_str().to_owned()),
        session: Some(GlobalMenuSession::from(session)),
        sections: menu.sections.iter().map(GlobalMenuSection::from).collect(),
        message: None,
    }
    .send_signal_to_dart();
}

pub(crate) fn no_headings(window: Option<String>, error: &Error) {
    GlobalMenuStatus {
        window,
        session: None,
        sections: Vec::new(),
        message: Some(error.to_string()),
    }
    .send_signal_to_dart();
}

pub(crate) fn section_items(session: &Session, id: &SectionId, items: &[Item]) {
    GlobalMenuSectionStatus {
        session: GlobalMenuSession::from(session),
        section: GlobalMenuSectionId::from(id),
        items: items.iter().map(GlobalMenuItem::from).collect(),
        message: None,
    }
    .send_signal_to_dart();
}

pub(crate) fn section_failed(session: &Session, id: &SectionId, error: &Error) {
    GlobalMenuSectionStatus {
        session: GlobalMenuSession::from(session),
        section: GlobalMenuSectionId::from(id),
        items: Vec::new(),
        message: Some(error.to_string()),
    }
    .send_signal_to_dart();
}

impl From<&Session> for GlobalMenuSession {
    fn from(session: &Session) -> Self {
        Self {
            generation: session.generation,
            window: session.window.as_str().to_owned(),
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
            SectionId::GtkAppMenu { group, menu } => Self::GtkAppMenu {
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
            ItemId::Gtk { action, target } => Self::Gtk {
                action: action.clone(),
                target: target.clone(),
            },
        }
    }
}

/// Delivers a domain update over the RINF boundary.
pub(crate) fn update(update: super::Update) {
    match update {
        super::Update::Headings { session, menu } => headings(&session, &menu),
        super::Update::Section {
            session,
            section,
            items,
        } => section_items(&session, &section, &items),
    }
}
