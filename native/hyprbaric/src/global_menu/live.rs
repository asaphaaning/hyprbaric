//! Live snapshot of the focused application's menus.
//!
//! ```text
//! vacant ──capture──► occupied
//!    ▲                    │
//!    └── window gone ─────┘
//!                         │
//!              D-Bus change ──capture─┘
//! ```
//!
//! Occupied serves headings without another round trip. Headings are a depth-1
//! layout of the menubar: no `AboutToShow`, no wait for a relayout. D-BusMenu
//! rows are not served from that snapshot. Firefox rebuilds every native
//! identifier after `AboutToShow`, so the next click still carries the ids
//! from the last heading read. Those ids are gone. The snapshot keeps the
//! heading labels so the open can announce the live node instead.
//!
//! A quiet layout that only changed identifiers must not replace the headings
//! Dart still holds, and an empty section must not be published over rows a
//! heading already had.

use std::{
    collections::HashMap,
    future::pending,
    sync::{Mutex, MutexGuard, OnceLock, PoisonError},
};

use futures_util::StreamExt;
use tokio::sync::{Notify, watch};
use tracing::instrument;
use zbus::Connection;

use super::{
    DBUSMENU_RELAYOUT, Endpoint, EndpointKind, Error, Item, Menu, SectionId, dbusmenu,
    dbusmenu_items, dbusmenu_tree, focused, gtk_groups_of, gtk_items, gtk_menus, gtk_tree, publish,
};

const DEBOUNCE: std::time::Duration = std::time::Duration::from_millis(80);

/// Menubar and its headings, not the rows beneath them.
const HEADINGS_DEPTH: i32 = 1;

/// Identity of the exporter this snapshot belongs to.
#[derive(Clone, Debug, PartialEq, Eq)]
struct Exporter {
    kind: EndpointKind,
    service: String,
    path: String,
}

impl Exporter {
    fn of(endpoint: &Endpoint) -> Self {
        Self {
            kind: endpoint.kind.clone(),
            service: endpoint.service.clone(),
            path: endpoint.path.clone(),
        }
    }
}

/// Headings and every nested section taken in one round trip.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
struct Snapshot {
    headings: Menu,
    sections: HashMap<SectionId, Vec<Item>>,
    /// D-BusMenu ids the bar has served, mapped to the label path that
    /// survives Firefox rebuilding the native tree.
    paths: HashMap<i32, Vec<String>>,
}

impl Snapshot {
    fn section(&self, id: &SectionId) -> Option<Vec<Item>> {
        self.sections
            .get(id)
            .filter(|items| !items.is_empty())
            .cloned()
    }

    fn remember(&mut self, id: SectionId, items: Vec<Item>) {
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
    fn path_hint(&self, id: &SectionId) -> Vec<String> {
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

    fn same_labels(left: &Menu, right: &Menu) -> bool {
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
    fn merge(self, incoming: Self) -> Self {
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
    fn item_path(&self, id: i32) -> Vec<String> {
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

fn walk_item(
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

fn walk_hint(
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
enum Held {
    #[default]
    Vacant,
    Occupied {
        exporter: Exporter,
        snapshot: Snapshot,
    },
}

impl Held {
    fn headings_for(&self, exporter: &Exporter) -> Option<Menu> {
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

    fn section_for(&self, exporter: &Exporter, id: &SectionId) -> Option<Vec<Item>> {
        match self {
            Self::Occupied {
                exporter: held,
                snapshot,
            } if held == exporter => snapshot.section(id),
            _ => None,
        }
    }

    fn holds(&self, exporter: &Exporter) -> bool {
        matches!(self, Self::Occupied { exporter: held, .. } if held == exporter)
    }

    fn path_hint(&self, exporter: &Exporter, id: &SectionId) -> Vec<String> {
        match self {
            Self::Occupied {
                exporter: held,
                snapshot,
            } if held == exporter => snapshot.path_hint(id),
            _ => Vec::new(),
        }
    }

    fn item_path(&self, id: i32) -> Vec<String> {
        match self {
            Self::Occupied { snapshot, .. } => snapshot.item_path(id),
            Self::Vacant => Vec::new(),
        }
    }

    fn occupy(exporter: Exporter, snapshot: Snapshot) -> Self {
        Self::Occupied { exporter, snapshot }
    }
}

/// Label path of a D-BusMenu row the bar already served.
pub(super) fn item_path(id: i32) -> Vec<String> {
    held().item_path(id)
}

struct Store {
    generation: watch::Sender<u64>,
    populated: Notify,
    held: Mutex<Held>,
}

fn store() -> &'static Store {
    static STORE: OnceLock<Store> = OnceLock::new();
    STORE.get_or_init(|| {
        let (generation, _) = watch::channel(0);
        Store {
            generation,
            populated: Notify::new(),
            held: Mutex::new(Held::Vacant),
        }
    })
}

fn held() -> MutexGuard<'static, Held> {
    store().held.lock().unwrap_or_else(PoisonError::into_inner)
}

fn generation() -> u64 {
    *store().generation.borrow()
}

fn bump() -> u64 {
    store()
        .generation
        .send_replace(generation().wrapping_add(1))
        .wrapping_add(1)
}

#[instrument(name = "hyprbaric::global_menu::live::headings", err)]
pub(super) async fn headings() -> Result<Menu, Error> {
    let (connection, endpoint) = match focused().await {
        Ok(focused) => focused,
        Err(error) => {
            clear();
            return Err(error);
        }
    };
    let exporter = Exporter::of(&endpoint);

    if let Some(menu) = held().headings_for(&exporter) {
        return Ok(menu);
    }

    if held().holds(&exporter) {
        wait_until_populated(&exporter).await;
        return match held().headings_for(&exporter) {
            Some(menu) => Ok(menu),
            // Still empty, or this exporter was replaced while we waited.
            // Recapturing here would bump generation and steal the snapshot
            // of whatever window is focused now.
            None => Err(Error::NoMenuForFocusedWindow),
        };
    }

    take(connection, endpoint, exporter).await
}

#[instrument(name = "hyprbaric::global_menu::live::items", err)]
pub(super) async fn items(id: &SectionId) -> Result<Vec<Item>, Error> {
    let (connection, endpoint) = focused().await?;
    let exporter = Exporter::of(&endpoint);

    if !held().holds(&exporter) {
        take(connection.clone(), endpoint.clone(), exporter.clone()).await?;
    } else if held().headings_for(&exporter).is_none() {
        wait_until_populated(&exporter).await;
    }

    if !held().holds(&exporter) {
        return Err(Error::NoMenuForFocusedWindow);
    }

    match id {
        SectionId::DbusMenu { id: dbus_id } => {
            // Always announce. Firefox rebuilds native identifiers after a
            // click, so a cached View menu still holds Zoom In's old ids.
            let path = held().path_hint(&exporter, id);
            let items = dbusmenu_items(&connection, &endpoint, *dbus_id, &path).await?;
            remember(&exporter, id.clone(), items.clone());
            Ok(items)
        }
        SectionId::Gtk { group, menu } => {
            if let Some(items) = held().section_for(&exporter, id) {
                return Ok(items);
            }

            if let Some(items) = wait_for(id, &exporter).await {
                return Ok(items);
            }

            let items = gtk_items(&connection, &endpoint, *group, *menu).await?;
            remember(&exporter, id.clone(), items.clone());
            Ok(items)
        }
    }
}

fn remember(exporter: &Exporter, id: SectionId, items: Vec<Item>) {
    if let Held::Occupied {
        exporter: held,
        snapshot,
    } = &mut *held()
        && held == exporter
    {
        snapshot.remember(id, items);
    }
}

/// Rebuilds the cache after an activation, without blocking the click.
pub(super) fn refresh() {
    tokio::spawn(async {
        if let Err(error) = refresh_now().await {
            tracing::debug!(%error, "Could not refresh the focused menu after activation");
        }
    });
}

#[instrument(name = "hyprbaric::global_menu::live::refresh", err)]
async fn refresh_now() -> Result<(), Error> {
    let (connection, endpoint) = focused().await?;
    let exporter = Exporter::of(&endpoint);
    take(connection, endpoint, exporter).await?;
    Ok(())
}

async fn take(
    connection: Connection,
    endpoint: Endpoint,
    exporter: Exporter,
) -> Result<Menu, Error> {
    let epoch = bump();
    {
        let mut held = held();
        if !held.holds(&exporter) {
            *held = Held::occupy(exporter.clone(), Snapshot::default());
        }
    }

    let snapshot = match capture_now(&connection, &endpoint).await {
        Ok(snapshot) => snapshot,
        Err(error) => {
            if generation() == epoch {
                let mut held = held();
                if matches!(
                    &*held,
                    Held::Occupied {
                        exporter: held_exporter,
                        snapshot,
                    } if held_exporter == &exporter && snapshot.headings.sections.is_empty()
                ) {
                    *held = Held::Vacant;
                }
                store().populated.notify_waiters();
            }
            return Err(error);
        }
    };

    install(epoch, exporter.clone(), snapshot);
    watch_from(epoch, connection, endpoint);
    Ok(held().headings_for(&exporter).unwrap_or_default())
}

async fn capture_now(connection: &Connection, endpoint: &Endpoint) -> Result<Snapshot, Error> {
    match endpoint.kind {
        EndpointKind::DbusMenu => capture_dbusmenu(connection, endpoint).await,
        EndpointKind::Gtk => capture_gtk(connection, endpoint).await,
        EndpointKind::X11 => Err(Error::NoMenuForFocusedWindow),
    }
}

async fn capture_dbusmenu(connection: &Connection, endpoint: &Endpoint) -> Result<Snapshot, Error> {
    let proxy = dbusmenu(connection, endpoint).await?;
    let layout = proxy
        .get_layout(0, HEADINGS_DEPTH, &[])
        .await
        .map_err(Error::Layout)?;
    let (headings, sections) = dbusmenu_tree(&layout.root)?;
    Ok(Snapshot {
        headings,
        sections,
        ..Default::default()
    })
}

async fn capture_gtk(connection: &Connection, endpoint: &Endpoint) -> Result<Snapshot, Error> {
    let proxy = gtk_menus(connection, endpoint).await?;
    let groups = proxy.start(&[0]).await.map_err(Error::GtkLayout)?;
    let extra = gtk_groups_of(&groups)
        .into_iter()
        .filter(|group| *group != 0)
        .collect::<Vec<_>>();
    let groups = if extra.is_empty() {
        groups
    } else {
        let mut all = groups;
        all.extend(proxy.start(&extra).await.map_err(Error::GtkLayout)?);
        all
    };
    let ids = gtk_groups_of(&groups);
    if let Err(error) = proxy.end(&ids).await {
        tracing::debug!(%error, "GTK menu declined to end the subscription");
    }
    let (headings, sections) = gtk_tree(&groups)?;
    Ok(Snapshot {
        headings,
        sections,
        ..Default::default()
    })
}

fn install(epoch: u64, exporter: Exporter, incoming: Snapshot) {
    if generation() != epoch {
        return;
    }

    let snapshot = match &*held() {
        Held::Occupied {
            exporter: held,
            snapshot,
        } if held == &exporter => snapshot.clone().merge(incoming),
        _ => incoming,
    };

    publish::headings(&snapshot.headings);
    for (id, items) in &snapshot.sections {
        if items.is_empty() {
            continue;
        }
        publish::section_items(id, items);
    }

    *held() = Held::occupy(exporter, snapshot);
    store().populated.notify_waiters();
}

fn clear() {
    bump();
    *held() = Held::Vacant;
}

async fn wait_until_populated(exporter: &Exporter) {
    let mut current = store().generation.subscribe();
    let start = *current.borrow();

    loop {
        let notified = store().populated.notified();
        {
            let held = held();
            if !held.holds(exporter) || held.headings_for(exporter).is_some() {
                return;
            }
        }

        tokio::select! {
            _ = notified => {}
            _ = current.changed() => {
                if *current.borrow() != start {
                    return;
                }
            }
            _ = tokio::time::sleep(DBUSMENU_RELAYOUT) => return,
        }
    }
}

async fn wait_for(id: &SectionId, exporter: &Exporter) -> Option<Vec<Item>> {
    let mut current = store().generation.subscribe();
    let start = *current.borrow();

    loop {
        {
            let held = held();
            if !held.holds(exporter) {
                return None;
            }
            if let Some(items) = held.section_for(exporter, id) {
                return Some(items);
            }
        }

        tokio::select! {
            _ = store().populated.notified() => {}
            _ = current.changed() => {
                if *current.borrow() != start {
                    return None;
                }
            }
            _ = tokio::time::sleep(DBUSMENU_RELAYOUT) => return None,
        }
    }
}

fn watch_from(epoch: u64, connection: Connection, endpoint: Endpoint) {
    tokio::spawn(async move {
        if let Err(error) = watch(epoch, connection, endpoint).await {
            tracing::debug!(%error, "Focused menu watch ended");
        }
    });
}

#[instrument(name = "hyprbaric::global_menu::live::watch", skip_all, err)]
async fn watch(epoch: u64, connection: Connection, endpoint: Endpoint) -> Result<(), Error> {
    let mut current = store().generation.subscribe();
    if *current.borrow() != epoch {
        return Ok(());
    }

    match endpoint.kind {
        EndpointKind::DbusMenu => watch_dbusmenu(epoch, &mut current, &connection, &endpoint).await,
        EndpointKind::Gtk => watch_gtk(epoch, &mut current, &connection, &endpoint).await,
        EndpointKind::X11 => Ok(()),
    }
}

async fn watch_dbusmenu(
    epoch: u64,
    current: &mut watch::Receiver<u64>,
    connection: &Connection,
    endpoint: &Endpoint,
) -> Result<(), Error> {
    let proxy = dbusmenu(connection, endpoint).await?;
    let mut layout = proxy.receive_layout_updated().await.ok();
    let mut properties = proxy.receive_items_properties_updated().await.ok();

    loop {
        tokio::select! {
            _ = current.changed() => {
                if *current.borrow() != epoch {
                    return Ok(());
                }
            }
            _ = recv(&mut layout) => {}
            _ = recv(&mut properties) => {}
        }

        if !settle(current, epoch, &mut layout, &mut properties).await {
            return Ok(());
        }

        replace(epoch, connection, endpoint).await?;
    }
}

/// Whether the next GTK `Changed` is the echo of our own `Start`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum GtkEcho {
    Listen,
    Ignore,
}

async fn watch_gtk(
    epoch: u64,
    current: &mut watch::Receiver<u64>,
    connection: &Connection,
    endpoint: &Endpoint,
) -> Result<(), Error> {
    let menus = gtk_menus(connection, endpoint).await?;
    let mut changed = menus.receive_changed().await.ok();
    let mut none = Option::<futures_util::stream::Empty<()>>::None;
    let mut echo = GtkEcho::Listen;

    loop {
        tokio::select! {
            _ = current.changed() => {
                if *current.borrow() != epoch {
                    return Ok(());
                }
            }
            _ = recv(&mut changed) => {}
        }

        match echo {
            GtkEcho::Ignore => {
                echo = GtkEcho::Listen;
                continue;
            }
            GtkEcho::Listen => {}
        }

        if !settle(current, epoch, &mut changed, &mut none).await {
            return Ok(());
        }

        replace(epoch, connection, endpoint).await?;
        echo = GtkEcho::Ignore;
    }
}

async fn replace(epoch: u64, connection: &Connection, endpoint: &Endpoint) -> Result<(), Error> {
    let snapshot = capture_now(connection, endpoint).await?;
    if snapshot.headings.sections.is_empty() {
        return Ok(());
    }
    install(epoch, Exporter::of(endpoint), snapshot);
    Ok(())
}

async fn settle<A: StreamExt + Unpin, B: StreamExt + Unpin>(
    current: &mut watch::Receiver<u64>,
    epoch: u64,
    first: &mut Option<A>,
    second: &mut Option<B>,
) -> bool {
    let wait = tokio::time::sleep(DEBOUNCE);
    tokio::pin!(wait);
    loop {
        tokio::select! {
            _ = current.changed() => {
                if *current.borrow() != epoch {
                    return false;
                }
            }
            _ = recv(first) => {}
            _ = recv(second) => {}
            _ = &mut wait => return true,
        }
    }
}

async fn recv<S: StreamExt + Unpin>(stream: &mut Option<S>) {
    match stream.as_mut() {
        Some(stream) => {
            let _ = stream.next().await;
        }
        None => pending::<()>().await,
    }
}

#[cfg(test)]
mod tests {
    use super::super::{EndpointKind, Item, ItemId, ItemKind, Menu, Section, SectionId};
    use super::{Exporter, Held, Snapshot};

    fn exporter() -> Exporter {
        Exporter {
            kind: EndpointKind::DbusMenu,
            service: ":1.40".to_owned(),
            path: "/MenuBar".to_owned(),
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
            path: "/Other".to_owned(),
            ..exporter()
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

    #[test]
    fn empty_headings_are_not_served_as_a_hit() {
        let held = Held::occupy(exporter(), Snapshot::default());
        assert!(held.headings_for(&exporter()).is_none());
        assert!(held.holds(&exporter()));
    }

    #[test]
    fn a_headings_read_does_not_walk_into_the_rows() {
        assert_eq!(super::HEADINGS_DEPTH, 1);
    }
}
