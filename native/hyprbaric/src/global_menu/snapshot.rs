//! Immutable menu snapshots and stable identifier lookup.
use super::{Item, Menu, SectionId, endpoint::Endpoint};
use std::collections::HashMap;
/// Identity of the exporter this snapshot belongs to.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(in crate::global_menu) struct Exporter {
    pub(in crate::global_menu) endpoint: Endpoint,
}

impl Exporter {
    pub(in crate::global_menu) fn of(endpoint: &Endpoint) -> Self {
        Self {
            endpoint: endpoint.clone(),
        }
    }
}

/// Headings and every nested section taken in one round trip.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub(in crate::global_menu) struct Snapshot {
    pub(in crate::global_menu) headings: Menu,
    pub(in crate::global_menu) sections: HashMap<SectionId, Vec<Item>>,
    /// D-BusMenu ids the bar has served, mapped to the label path that
    /// survives Firefox rebuilding the native tree.
    pub(in crate::global_menu) paths: HashMap<i32, Vec<String>>,
}

impl Snapshot {
    pub(in crate::global_menu) fn section(&self, id: &SectionId) -> Option<Vec<Item>> {
        self.sections
            .get(id)
            .filter(|items| !items.is_empty())
            .cloned()
    }

    pub(in crate::global_menu) fn remember(&mut self, id: SectionId, items: Vec<Item>) {
        let prefix = self.path_hint(&id);
        for item in &items {
            let mut path = prefix.clone();
            path.push(item.label.clone());
            if let Some(super::ItemId::DbusMenu { id }) = item.activation {
                self.paths.insert(id, path.clone());
            }
            if let Some(SectionId::DbusMenu { id }) = item.submenu {
                self.paths.insert(id, path);
            }
        }
        self.sections.insert(id, items);
    }

    /// Labels from the headings Dart was given, so a later open can find the
    /// live node after Firefox has issued new identifiers.
    pub(in crate::global_menu) fn path_hint(&self, id: &SectionId) -> Vec<String> {
        for heading in &self.headings.sections {
            if heading.id == *id {
                return vec![heading.label.clone()];
            }
            if let Some(path) = walk_hint(
                self,
                self.sections.get(&heading.id),
                id,
                vec![heading.label.clone()],
            ) {
                return path;
            }
        }
        Vec::new()
    }

    pub(in crate::global_menu) fn same_labels(left: &Menu, right: &Menu) -> bool {
        left.sections
            .iter()
            .map(|section| (section.label.as_str(), section.enabled))
            .eq(right
                .sections
                .iter()
                .map(|section| (section.label.as_str(), section.enabled)))
    }

    /// Quiet layouts keep the headings Dart already has when only identifiers
    /// changed. Rows do not ride along: Firefox rebuilds native identifiers
    /// and enabled flags under `AboutToShow`, and a depth-1 read in the middle
    /// of that rebuild is often blank. Restoring the previous View menu would
    /// republish dead ids, so Actual Size still talks to Zoom In's old node.
    pub(in crate::global_menu) fn merge(self, incoming: Self) -> Self {
        let headings = if incoming.headings.sections.is_empty() {
            self.headings.clone()
        } else if Self::same_labels(&self.headings, &incoming.headings) {
            self.headings.clone()
        } else {
            incoming.headings.clone()
        };

        Self {
            headings,
            sections: incoming.sections,
            paths: {
                let mut paths = self.paths;
                paths.extend(incoming.paths);
                paths
            },
        }
    }

    /// Label path of a D-BusMenu row the bar already served, used when Firefox
    /// has issued a new identifier for the same item.
    pub(in crate::global_menu) fn item_path(&self, id: i32) -> Vec<String> {
        if let Some(path) = self.paths.get(&id) {
            return path.clone();
        }
        for heading in &self.headings.sections {
            if let Some(path) = walk_item(
                self,
                self.sections.get(&heading.id),
                id,
                vec![heading.label.clone()],
            ) {
                return path;
            }
        }
        Vec::new()
    }
}

pub(in crate::global_menu) fn walk_item(
    snapshot: &Snapshot,
    items: Option<&Vec<Item>>,
    id: i32,
    prefix: Vec<String>,
) -> Option<Vec<String>> {
    let items = items?;
    for item in items {
        let mut path = prefix.clone();
        path.push(item.label.clone());
        match item.activation {
            Some(super::ItemId::DbusMenu { id: item_id }) if item_id == id => {
                return Some(path);
            }
            _ => {}
        }
        if let Some(submenu) = &item.submenu
            && let Some(found) = walk_item(snapshot, snapshot.sections.get(submenu), id, path)
        {
            return Some(found);
        }
    }
    None
}

pub(in crate::global_menu) fn walk_hint(
    snapshot: &Snapshot,
    items: Option<&Vec<Item>>,
    target: &SectionId,
    prefix: Vec<String>,
) -> Option<Vec<String>> {
    let items = items?;
    for item in items {
        let Some(submenu) = &item.submenu else {
            continue;
        };
        let mut path = prefix.clone();
        path.push(item.label.clone());
        if submenu == target {
            return Some(path);
        }
        if let Some(found) = walk_hint(snapshot, snapshot.sections.get(submenu), target, path) {
            return Some(found);
        }
    }
    None
}

/// What the process currently holds for the focused window.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub(in crate::global_menu) enum Held {
    #[default]
    Vacant,
    Occupied {
        exporter: Exporter,
        snapshot: Snapshot,
    },
}

impl Held {
    pub(in crate::global_menu) fn headings_for(&self, exporter: &Exporter) -> Option<Menu> {
        match self {
            Self::Occupied {
                exporter: held,
                snapshot,
            } if held == exporter && !snapshot.headings.sections.is_empty() => {
                Some(snapshot.headings.clone())
            }
            _ => None,
        }
    }

    pub(in crate::global_menu) fn section_for(
        &self,
        exporter: &Exporter,
        id: &SectionId,
    ) -> Option<Vec<Item>> {
        match self {
            Self::Occupied {
                exporter: held,
                snapshot,
            } if held == exporter => snapshot.section(id),
            _ => None,
        }
    }

    pub(in crate::global_menu) fn holds(&self, exporter: &Exporter) -> bool {
        matches!(self, Self::Occupied { exporter: held, .. } if held == exporter)
    }

    pub(in crate::global_menu) fn path_hint(
        &self,
        exporter: &Exporter,
        id: &SectionId,
    ) -> Vec<String> {
        match self {
            Self::Occupied {
                exporter: held,
                snapshot,
            } if held == exporter => snapshot.path_hint(id),
            _ => Vec::new(),
        }
    }

    pub(in crate::global_menu) fn path_of(&self, id: &SectionId) -> Vec<String> {
        match self {
            Self::Occupied { snapshot, .. } => snapshot.path_hint(id),
            Self::Vacant => Vec::new(),
        }
    }

    pub(in crate::global_menu) fn item_path(&self, id: i32) -> Vec<String> {
        match self {
            Self::Occupied { snapshot, .. } => snapshot.item_path(id),
            Self::Vacant => Vec::new(),
        }
    }

    pub(in crate::global_menu) fn occupy(exporter: Exporter, snapshot: Snapshot) -> Self {
        Self::Occupied { exporter, snapshot }
    }
}

#[cfg(test)]
mod tests {
    use super::{Exporter, Held, Snapshot};
    use crate::global_menu::{Item, ItemId, ItemKind, Menu, Section, SectionId};
    use crate::global_menu::{
        endpoint::Endpoint,
        popup::{Opened, closing},
    };

    fn exporter() -> Exporter {
        Exporter {
            endpoint: Endpoint::DbusMenu {
                service: ":1.40".to_owned(),
                path: "/MenuBar".to_owned(),
                address: None,
                xid: None,
            },
        }
    }

    fn file() -> SectionId {
        SectionId::DbusMenu { id: 1 }
    }

    fn snapshot() -> Snapshot {
        let id = file();
        Snapshot {
            headings: Menu {
                sections: vec![Section {
                    id: id.clone(),
                    label: "File".to_owned(),
                    enabled: true,
                }],
            },
            sections: [(
                id,
                vec![Item {
                    label: "New".to_owned(),
                    enabled: true,
                    kind: ItemKind::Standard,
                    shortcut: None,
                    activation: None,
                    submenu: None,
                }],
            )]
            .into(),
            ..Default::default()
        }
    }

    #[test]
    fn an_occupied_cache_serves_only_the_exporter_it_holds() {
        let held = Held::occupy(exporter(), snapshot());
        let other = Exporter {
            endpoint: Endpoint::DbusMenu {
                service: ":1.40".into(),
                path: "/Other".into(),
                address: None,
                xid: None,
            },
        };

        assert_eq!(
            held.headings_for(&exporter()).expect("held").sections[0].label,
            "File"
        );
        assert!(held.headings_for(&other).is_none());
        assert_eq!(
            held.section_for(&exporter(), &file()).expect("section")[0].label,
            "New"
        );
        assert!(held.section_for(&other, &file()).is_none());
    }

    #[test]
    fn a_vacant_cache_serves_nothing() {
        let held = Held::Vacant;
        assert!(held.headings_for(&exporter()).is_none());
        assert!(held.section_for(&exporter(), &file()).is_none());
        assert!(!held.holds(&exporter()));
    }

    fn empty_file() -> Snapshot {
        Snapshot {
            headings: Menu {
                sections: vec![Section {
                    id: file(),
                    label: "File".to_owned(),
                    enabled: true,
                }],
            },
            sections: [(file(), Vec::new())].into(),
            ..Default::default()
        }
    }

    fn rebuilt_empty_file() -> Snapshot {
        let id = SectionId::DbusMenu { id: 99 };
        Snapshot {
            headings: Menu {
                sections: vec![Section {
                    id: id.clone(),
                    label: "File".to_owned(),
                    enabled: true,
                }],
            },
            sections: [(id, Vec::new())].into(),
            ..Default::default()
        }
    }

    #[test]
    fn an_empty_section_is_not_a_hit() {
        let held = Held::occupy(exporter(), empty_file());
        assert!(held.section_for(&exporter(), &file()).is_none());
        assert_eq!(held.path_hint(&exporter(), &file()), ["File"]);
    }

    #[test]
    fn a_quiet_rebuild_keeps_the_heading_ids_dart_already_has() {
        let merged = snapshot().merge(rebuilt_empty_file());
        assert_eq!(merged.headings.sections[0].id, file());
        assert!(merged.section(&file()).is_none());
        assert_eq!(merged.path_hint(&file()), ["File"]);
    }

    #[test]
    fn an_empty_quiet_layout_does_not_clear_headings() {
        let merged = snapshot().merge(Snapshot::default());
        assert_eq!(merged.headings.sections[0].label, "File");
        assert!(merged.section(&file()).is_none());
    }

    #[test]
    fn a_served_row_keeps_its_path_after_firefox_rebuilds_the_tree() {
        let mut snapshot = Snapshot {
            headings: snapshot().headings,
            ..Default::default()
        };
        snapshot.remember(
            file(),
            vec![Item {
                label: "Actual Size".to_owned(),
                enabled: false,
                kind: ItemKind::Standard,
                shortcut: None,
                activation: Some(ItemId::DbusMenu { id: 6 }),
                submenu: None,
            }],
        );

        let merged = snapshot.merge(rebuilt_empty_file());
        assert!(merged.section(&file()).is_none());
        assert_eq!(merged.item_path(6), ["File", "Actual Size"]);
    }

    fn toolbar(checked: bool) -> Item {
        Item {
            label: "Bookmarks Toolbar".to_owned(),
            enabled: true,
            kind: ItemKind::Checkmark { checked },
            shortcut: None,
            activation: Some(ItemId::DbusMenu { id: 12 }),
            submenu: None,
        }
    }

    #[test]
    fn remembering_a_section_again_replaces_its_marks() {
        let mut snapshot = snapshot();
        snapshot.remember(file(), vec![toolbar(false)]);
        snapshot.remember(file(), vec![toolbar(true)]);

        assert_eq!(
            snapshot.section(&file()).expect("rows")[0].kind,
            ItemKind::Checkmark { checked: true }
        );
    }

    #[test]
    fn empty_headings_are_not_served_as_a_hit() {
        let held = Held::occupy(exporter(), Snapshot::default());
        assert!(held.headings_for(&exporter()).is_none());
        assert!(held.holds(&exporter()));
    }

    fn opened_menu(id: i32, path: &[&str]) -> Opened {
        Opened {
            endpoint: serde_json::from_str(
                r#"{"kind":"dbusmenu","service":":1.40","path":"/MenuBar"}"#,
            )
            .expect("endpoint"),
            id,
            path: path.iter().map(|label| (*label).to_owned()).collect(),
            section: SectionId::DbusMenu { id },
        }
    }

    #[test]
    fn dismissing_a_heading_closes_its_flyouts_first() {
        let file = opened_menu(1, &["File"]);
        let recent = opened_menu(20, &["File", "Recent"]);
        let edit = opened_menu(2, &["Edit"]);
        let (close, keep) = closing(
            vec![file.clone(), recent.clone(), edit.clone()],
            1,
            &["File".to_owned()],
        );

        assert_eq!(close, vec![recent, file]);
        assert_eq!(keep, vec![edit]);
    }

    #[test]
    fn dismissing_a_flyout_leaves_the_heading_open() {
        let file = opened_menu(1, &["File"]);
        let recent = opened_menu(20, &["File", "Recent"]);
        let (close, keep) = closing(
            vec![file.clone(), recent.clone()],
            20,
            &["File".to_owned(), "Recent".to_owned()],
        );

        assert_eq!(close, vec![recent]);
        assert_eq!(keep, vec![file]);
    }

    #[test]
    fn a_rebuilt_heading_id_still_closes_by_its_label_path() {
        let file = opened_menu(1, &["File"]);
        let (close, keep) = closing(vec![file.clone()], 50, &["File".to_owned()]);

        assert_eq!(close, vec![file]);
        assert!(keep.is_empty());
    }

    #[test]
    fn a_rebuilt_heading_still_closes_nested_flyouts_by_path() {
        let file = opened_menu(50, &["File"]);
        let recent = opened_menu(80, &["File", "Recent"]);
        let (close, keep) = closing(vec![file.clone(), recent.clone()], 1, &["File".to_owned()]);

        assert_eq!(close, vec![recent, file]);
        assert!(keep.is_empty());
    }

    #[test]
    fn an_unknown_id_with_no_path_closes_nothing() {
        let file = opened_menu(1, &["File"]);
        let (close, keep) = closing(vec![file.clone()], 99, &[]);

        assert!(close.is_empty());
        assert_eq!(keep, vec![file]);
    }
}
