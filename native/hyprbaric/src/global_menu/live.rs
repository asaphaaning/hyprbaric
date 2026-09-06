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
    dbusmenu_items, dbusmenu_live_items, dbusmenu_tree, focused, gtk_actions, gtk_describe,
    gtk_groups_of, gtk_items, gtk_menus, gtk_tree, publish,
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

    fn path_of(&self, id: &SectionId) -> Vec<String> {
        match self {
            Self::Occupied { snapshot, .. } => snapshot.path_hint(id),
            Self::Vacant => Vec::new(),
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

/// A D-BusMenu the bar announced as open, so dismiss can send `closed`
/// to the same exporter even after focus has moved on.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) struct Opened {
    pub endpoint: Endpoint,
    pub id: i32,
    pub path: Vec<String>,
    /// The address Dart is watching. Firefox may have issued a new `id`.
    pub section: SectionId,
}

impl Opened {
    fn belongs(&self, id: i32, path: &[String]) -> bool {
        self.id == id || (!path.is_empty() && self.path.starts_with(path))
    }
}

/// Which announced menus close with this heading, nested flyouts first.
fn closing(opened: Vec<Opened>, id: i32, path: &[String]) -> (Vec<Opened>, Vec<Opened>) {
    let mut close = Vec::new();
    let mut keep = Vec::new();
    for menu in opened {
        if menu.belongs(id, path) {
            close.push(menu);
        } else {
            keep.push(menu);
        }
    }
    close.sort_by(|left, right| right.path.len().cmp(&left.path.len()));
    (close, keep)
}

pub(super) fn remember_opened(endpoint: Endpoint, id: i32, path: Vec<String>, section: SectionId) {
    let mut opened = opened();
    opened.retain(|menu| menu.id != id && menu.path != path);
    opened.push(Opened {
        endpoint,
        id,
        path,
        section,
    });
}

pub(super) fn take_opened(id: i32, path: &[String]) -> Vec<Opened> {
    let mut opened = opened();
    let current = std::mem::take(&mut *opened);
    let (close, keep) = closing(current, id, path);
    *opened = keep;
    close
}

pub(super) fn drain_opened() -> Vec<Opened> {
    std::mem::take(&mut *opened())
}

fn announced() -> Vec<Opened> {
    opened().clone()
}

/// Label path of a D-BusMenu row the bar already served.
pub(super) fn item_path(id: i32) -> Vec<String> {
    held().item_path(id)
}

/// Path used to close a heading or flyout, including after Firefox rebuilds ids.
///
/// Dart still holds the identifier from the last read. The live node may now
/// have a different id, so `closed` follows the heading labels: the snapshot's
/// hint, then the last served row path, then whatever we announced as open.
pub(super) fn dismiss_path(id: i32) -> Vec<String> {
    {
        let held = held();
        let hinted = held.path_of(&SectionId::DbusMenu { id });
        if !hinted.is_empty() {
            return hinted;
        }
        let served = held.item_path(id);
        if !served.is_empty() {
            return served;
        }
    }
    opened()
        .iter()
        .find(|menu| menu.id == id)
        .map(|menu| menu.path.clone())
        .unwrap_or_default()
}

struct Store {
    generation: watch::Sender<u64>,
    populated: Notify,
    held: Mutex<Held>,
    opened: Mutex<Vec<Opened>>,
}

fn store() -> &'static Store {
    static STORE: OnceLock<Store> = OnceLock::new();
    STORE.get_or_init(|| {
        let (generation, _) = watch::channel(0);
        Store {
            generation,
            populated: Notify::new(),
            held: Mutex::new(Held::Vacant),
            opened: Mutex::new(Vec::new()),
        }
    })
}

fn held() -> MutexGuard<'static, Held> {
    store().held.lock().unwrap_or_else(PoisonError::into_inner)
}

fn opened() -> MutexGuard<'static, Vec<Opened>> {
    store()
        .opened
        .lock()
        .unwrap_or_else(PoisonError::into_inner)
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

#[instrument(name = "hyprbaric::global_menu::live::headings")]
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

#[instrument(name = "hyprbaric::global_menu::live::items")]
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
    let leftover = {
        let mut held = held();
        let leftover = if held.holds(&exporter) {
            Vec::new()
        } else {
            drain_opened()
        };
        if !held.holds(&exporter) {
            *held = Held::occupy(exporter.clone(), Snapshot::default());
        }
        leftover
    };
    if !leftover.is_empty() {
        super::close_opened(leftover).await;
    }

    let epoch = bump();

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
    if let Err(error) = refresh_opened(&connection, &endpoint).await {
        tracing::debug!(%error, "Could not refresh an open menu after recapture");
    }
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
    let actions = gtk_describe(connection, endpoint).await;
    let (headings, sections) = gtk_tree(&groups, &actions)?;
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
    let leftover = drain_opened();
    if leftover.is_empty() {
        return;
    }
    tokio::spawn(async move {
        super::close_opened(leftover).await;
    });
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
    let app = match endpoint.application_path.as_deref() {
        Some(path) => gtk_actions(connection, endpoint, path).await.ok(),
        None => None,
    };
    let win = match endpoint.window_path.as_deref() {
        Some(path) => gtk_actions(connection, endpoint, path).await.ok(),
        None => None,
    };
    let mut app_changed = match &app {
        Some(proxy) => proxy.receive_changed().await.ok(),
        None => None,
    };
    let mut win_changed = match &win {
        Some(proxy) => proxy.receive_changed().await.ok(),
        None => None,
    };
    let mut echo = GtkEcho::Listen;

    loop {
        tokio::select! {
            _ = current.changed() => {
                if *current.borrow() != epoch {
                    return Ok(());
                }
            }
            _ = recv(&mut changed) => {
                if echo == GtkEcho::Ignore {
                    echo = GtkEcho::Listen;
                    continue;
                }
            }
            _ = recv(&mut app_changed) => {}
            _ = recv(&mut win_changed) => {}
        }

        if !settle3(
            current,
            epoch,
            &mut changed,
            &mut app_changed,
            &mut win_changed,
        )
        .await
        {
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
    if let Err(error) = refresh_opened(connection, endpoint).await {
        tracing::debug!(%error, "Could not refresh an open menu after a layout update");
    }
    Ok(())
}

/// Re-reads every D-BusMenu the bar is currently showing.
///
/// Watch recaptures headings only. That is enough after Zoom In closes the
/// panel; View → Toolbars is still up, and its checkmarks live on the rows.
#[instrument(name = "hyprbaric::global_menu::live::refresh_opened", skip_all, err)]
async fn refresh_opened(connection: &Connection, endpoint: &Endpoint) -> Result<(), Error> {
    if endpoint.kind != EndpointKind::DbusMenu {
        return Ok(());
    }

    let exporter = Exporter::of(endpoint);
    for menu in announced() {
        if Exporter::of(&menu.endpoint) != exporter {
            continue;
        }
        let items = match dbusmenu_live_items(connection, endpoint, menu.id, &menu.path).await {
            Ok(items) => items,
            Err(error) => {
                tracing::debug!(%error, "Could not re-read an open menu");
                continue;
            }
        };
        if items.is_empty() {
            continue;
        }
        remember(&exporter, menu.section.clone(), items.clone());
        publish::section_items(&menu.section, &items);
    }
    Ok(())
}

async fn settle3<A: StreamExt + Unpin, B: StreamExt + Unpin, C: StreamExt + Unpin>(
    current: &mut watch::Receiver<u64>,
    epoch: u64,
    first: &mut Option<A>,
    second: &mut Option<B>,
    third: &mut Option<C>,
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
            _ = recv(third) => {}
            _ = &mut wait => return true,
        }
    }
}

async fn settle<A: StreamExt + Unpin, B: StreamExt + Unpin>(
    current: &mut watch::Receiver<u64>,
    epoch: u64,
    first: &mut Option<A>,
    second: &mut Option<B>,
) -> bool {
    let mut none = Option::<futures_util::stream::Empty<()>>::None;
    settle3(current, epoch, first, second, &mut none).await
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
    use super::{Exporter, Held, Opened, Snapshot, closing};

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

    #[test]
    fn a_headings_read_does_not_walk_into_the_rows() {
        assert_eq!(super::HEADINGS_DEPTH, 1);
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
