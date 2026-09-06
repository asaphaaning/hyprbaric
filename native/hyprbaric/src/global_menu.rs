//! Focused-application menu reader.
//!
//! The compositor companion owns the Wayland-specific association. This module
//! reads its typed JSON projection, selects the focused window's endpoint, and
//! converts the D-BusMenu and GTK menu boundaries into one menu-bar vocabulary.
//!
//! Windows that only register through `com.canonical.AppMenu.Registrar` — the
//! X11 `appmenu-gtk-module` path — never appear in that projection. Those
//! resolve through the registrar table, matching the companion's X11 window
//! identifier when it has one and the registering process otherwise.
//!
//! GTK often publishes `gtk_shell1` before Hyprland has a window for that
//! surface, so a companion row can have a D-Bus endpoint and no compositor
//! address. The plugin resolves the surface again when it snapshots. If that
//! still has no address, a unique process-id match against the focused window
//! is enough; two address-less menus from the same process are not guessed.
//!
//! A dialog that takes focus — Save As, Print, Preferences — usually exports
//! no menu of its own. The companion also snapshots Hyprland's mapped
//! `parent()` for each window (XDG `set_parent` / X11 `WM_TRANSIENT_FOR`).
//! Headings then come from the first ancestor that published a menu, so File /
//! Edit stay on the bar while the dialog is up.
//!
//! Headings are a cheap layout of the menubar. GTK3 can also publish an
//! application menu on a second `org.gtk.Menus` object; that becomes one
//! leading heading so its `(group, menu)` ids do not collide with the
//! menubar's. GTK rows can be served from that snapshot: action names are
//! stable. Availability, check/radio marks, and Activate parameters come from
//! `org.gtk.Actions` on the application and window paths, which is the same
//! join GTK's menu tracker performs.
//! D-BusMenu rows are announced to the application on every open
//! (`AboutToShow` / `opened`). Firefox rebuilds native identifiers and
//! enabled flags after a click, so a cached View menu still holds the ids
//! from before Zoom In; Actual Size then talks to a node that is no longer
//! in the tree. KDE marks section captions with `x-kde-title`; those become
//! [`ItemKind::Group`], the same projection as a named GTK `:section`.

mod gtk;
mod live;
mod plugin;
pub(crate) mod publish;
mod registrar;

pub use plugin::{Configuration, Readiness};
pub use registrar::Registrar;

use std::{
    collections::{HashMap, HashSet},
    env,
    process::Stdio,
    time::{Duration, SystemTime, UNIX_EPOCH},
};

use futures_util::StreamExt;
use hyprland::{data::Client, prelude::HyprDataActiveOptional};
use serde::Deserialize;
use tokio::process::Command;
use tracing::instrument;
use zbus::{
    proxy,
    zvariant::{OwnedValue, Structure, Type, Value},
};

/// Installs the compositor companion, rebuilding it if the bundle no longer fits.
///
/// This can take minutes when hyprpm has to compile, so callers run it away
/// from startup and report its outcome when it settles.
#[instrument(name = "hyprbaric::global_menu::install", skip_all, err)]
pub async fn install_companion(configuration: &Configuration) -> Result<Readiness, plugin::Error> {
    plugin::install(configuration).await
}

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
    fn gtk(group: u32, menu: u32, app_menu: bool) -> Self {
        if app_menu {
            Self::GtkAppMenu { group, menu }
        } else {
            Self::Gtk { group, menu }
        }
    }

    fn as_gtk(&self) -> Option<(u32, u32, bool)> {
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

/// Reads the headings the focused application currently exports.
#[instrument(name = "hyprbaric::global_menu::read")]
pub async fn read() -> Result<Menu, Error> {
    live::headings().await
}

/// Reads the rows beneath one heading of the focused application.
#[instrument(name = "hyprbaric::global_menu::section")]
pub async fn section(id: &SectionId) -> Result<Vec<Item>, Error> {
    live::items(id).await
}

/// Tells the application a heading or submenu is no longer shown.
///
/// D-BusMenu `opened` / `AboutToShow` pair with `closed`. Firefox and Qt
/// keep popup state across that pair; skipping `closed` leaves the last
/// heading thinking it is still open. GTK has no equivalent.
#[instrument(name = "hyprbaric::global_menu::dismiss", err)]
pub async fn dismiss(id: &SectionId) -> Result<(), Error> {
    match id {
        SectionId::Gtk { .. } | SectionId::GtkAppMenu { .. } => Ok(()),
        SectionId::DbusMenu { id } => dbusmenu_closed(*id).await,
    }
}

/// Activates one row of the focused application's menu.
#[instrument(name = "hyprbaric::global_menu::activate", err)]
pub async fn activate(id: &ItemId) -> Result<(), Error> {
    let (connection, endpoint) = focused().await?;

    match id {
        ItemId::DbusMenu { id } => dbusmenu_activate(&connection, &endpoint, *id).await,
        ItemId::Gtk { action, target } => {
            gtk_activate(&connection, &endpoint, action, target.as_deref()).await
        }
    }?;

    live::refresh();
    Ok(())
}

/// Resolves the focused window's endpoint and a bus to reach it on.
async fn focused() -> Result<(zbus::Connection, Endpoint), Error> {
    let endpoint = focused_endpoint().await?;
    let connection = zbus::Connection::session().await.map_err(Error::Connect)?;

    Ok((connection, endpoint))
}

async fn dbusmenu<'a>(
    connection: &zbus::Connection,
    endpoint: &Endpoint,
) -> Result<DBusMenuProxy<'a>, Error> {
    DBusMenuProxy::builder(connection)
        .destination(endpoint.service().to_owned())
        .map_err(Error::CreateProxy)?
        .path(endpoint.path().to_owned())
        .map_err(Error::CreateProxy)?
        .build()
        .await
        .map_err(Error::CreateProxy)
}

/// How deep a D-BusMenu fetch walks: the menubar, a heading, one nested menu,
/// and that menu's rows. Enough to reopen a heading after an application
/// rebuilds its tree under new identifiers.
const DBUSMENU_DEPTH: i32 = 4;

/// How long to wait for an application to fill a menu it has just been told
/// is opening. Firefox runs `popupshowing` on the Gecko thread and then
/// rebuilds the native tree; Qt usually returns the rows with `AboutToShow`.
const DBUSMENU_RELAYOUT: Duration = Duration::from_millis(400);

/// Reads one D-BusMenu subtree, announcing the open first.
///
/// Qt fills a menu's rows in response to `AboutToShow`. Firefox also listens
/// for the `opened` event, and its `AboutToShow` handler mutates the XUL DOM
/// which then *rebuilds the whole native tree under new identifiers*. The next
/// click still carries the id from the last heading read, which is no longer
/// in the tree: `GetLayout` for that id is empty, and `AboutToShow` on it is
/// ignored. [known_path] is the heading (and submenu) labels from that last
/// read, which is the address that survives the rebuild.
async fn dbusmenu_items(
    connection: &zbus::Connection,
    endpoint: &Endpoint,
    id: i32,
    known_path: &[String],
) -> Result<Vec<Item>, Error> {
    let proxy = dbusmenu(connection, endpoint).await?;
    let layout = proxy
        .get_layout(0, DBUSMENU_DEPTH, &[])
        .await
        .map_err(Error::Layout)?;
    let path = path_to(&layout.root, id)?
        .filter(|path| !path.is_empty())
        .unwrap_or_else(|| known_path.to_vec());
    let dest = destination(&layout.root, id, &path)?;
    let mut updates = match proxy.receive_layout_updated().await {
        Ok(updates) => Some(updates),
        Err(error) => {
            tracing::debug!(%error, "Cannot watch D-BusMenu layout updates");
            None
        }
    };

    if dest != id {
        tracing::debug!(
            requested = id,
            live = dest,
            "Opening a D-BusMenu heading under a new identifier"
        );
    }

    if let Err(error) = dbusmenu_event(&proxy, dest, DbusMenuEvent::Opened).await {
        tracing::debug!(%error, id = dest, "Menu declined the opened event");
    }
    live::remember_opened(
        endpoint.clone(),
        dest,
        path.clone(),
        SectionId::DbusMenu { id },
    );
    if let Err(error) = proxy.about_to_show(dest).await {
        tracing::debug!(
            %error,
            id = dest,
            "Menu declined to announce that it was opening"
        );
    }

    let mut items = dbusmenu_section(&proxy, dest, &path).await?;
    if items.is_empty() {
        if let Some(updates) = updates.as_mut() {
            let wait = tokio::time::sleep(DBUSMENU_RELAYOUT);
            tokio::pin!(wait);
            loop {
                tokio::select! {
                    _ = &mut wait => break,
                    next = updates.next() => {
                        let Some(signal) = next else { break };
                        let Ok(args) = signal.args() else { continue };
                        if *args.parent() == 0 || *args.parent() == dest || *args.parent() == id {
                            break;
                        }
                    }
                }
            }
        }
        items = dbusmenu_section(&proxy, dest, &path).await?;
    }

    Ok(items)
}

/// Clicks a D-BusMenu row, following the label path if Firefox has issued new
/// identifiers since the bar last read the menu.
async fn dbusmenu_activate(
    connection: &zbus::Connection,
    endpoint: &Endpoint,
    id: i32,
) -> Result<(), Error> {
    let proxy = dbusmenu(connection, endpoint).await?;
    let layout = proxy
        .get_layout(0, DBUSMENU_DEPTH, &[])
        .await
        .map_err(Error::Layout)?;
    let path = path_to(&layout.root, id)?
        .filter(|path| !path.is_empty())
        .unwrap_or_else(|| live::item_path(id));
    let dest = destination(&layout.root, id, &path)?;

    if dest != id {
        tracing::debug!(
            requested = id,
            live = dest,
            "Activating a D-BusMenu row under a new identifier"
        );
    }

    if find_by_id(&layout.root, dest)?.is_some() {
        return dbusmenu_event(&proxy, dest, DbusMenuEvent::Clicked)
            .await
            .map_err(Error::Activate);
    }

    let Some((label, parent_path)) = path.split_last() else {
        return dbusmenu_event(&proxy, dest, DbusMenuEvent::Clicked)
            .await
            .map_err(Error::Activate);
    };

    let parent = destination(&layout.root, i32::MIN, parent_path)?;
    let items = dbusmenu_items(connection, endpoint, parent, parent_path).await?;
    let dest = activation_id(&items, label).unwrap_or(dest);

    dbusmenu_event(&proxy, dest, DbusMenuEvent::Clicked)
        .await
        .map_err(Error::Activate)
}

/// D-BusMenu `Event` names. `opened` and `closed` are only valid on items
/// that contain a submenu, which is every heading and flyout we announce.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum DbusMenuEvent {
    Opened,
    Closed,
    Clicked,
}

impl DbusMenuEvent {
    fn as_str(self) -> &'static str {
        match self {
            Self::Opened => "opened",
            Self::Closed => "closed",
            Self::Clicked => "clicked",
        }
    }
}

async fn dbusmenu_event(
    proxy: &DBusMenuProxy<'_>,
    id: i32,
    event: DbusMenuEvent,
) -> Result<(), zbus::Error> {
    proxy
        .event(id, event.as_str(), &Value::I32(0), timestamp())
        .await
}

/// Sends `closed` to every D-BusMenu we announced as open under this heading.
///
/// Nested flyouts are closed first, then the heading. Firefox rebuilds native
/// identifiers after `AboutToShow`, so the live node is resolved by the label
/// path recorded when it opened, not by the id Dart still holds.
async fn dbusmenu_closed(id: i32) -> Result<(), Error> {
    let path = live::dismiss_path(id);
    let opened = live::take_opened(id, &path);
    if opened.is_empty() {
        return dbusmenu_closed_at(id, &path).await;
    }

    for menu in opened {
        if let Err(error) = dbusmenu_closed_announced(menu).await {
            tracing::debug!(%error, "Menu declined the closed event");
        }
    }

    Ok(())
}

async fn dbusmenu_closed_announced(opened: live::Opened) -> Result<(), Error> {
    let connection = zbus::Connection::session().await.map_err(Error::Connect)?;
    let proxy = dbusmenu(&connection, &opened.endpoint).await?;
    let layout = proxy
        .get_layout(0, DBUSMENU_DEPTH, &[])
        .await
        .map_err(Error::Layout)?;
    let dest = destination(&layout.root, opened.id, &opened.path)?;
    dbusmenu_event(&proxy, dest, DbusMenuEvent::Closed)
        .await
        .map_err(Error::Event)
}

async fn dbusmenu_closed_at(id: i32, path: &[String]) -> Result<(), Error> {
    let (connection, endpoint) = focused().await?;
    if !matches!(endpoint, Endpoint::DbusMenu { .. }) {
        return Ok(());
    }

    let proxy = dbusmenu(&connection, &endpoint).await?;
    let layout = proxy
        .get_layout(0, DBUSMENU_DEPTH, &[])
        .await
        .map_err(Error::Layout)?;
    let dest = destination(&layout.root, id, path)?;
    if let Err(error) = dbusmenu_event(&proxy, dest, DbusMenuEvent::Closed).await {
        tracing::debug!(%error, id = dest, "Menu declined the closed event");
    }
    Ok(())
}

/// Closes every D-BusMenu still announced against an exporter that went away.
#[instrument(name = "hyprbaric::global_menu::close_opened", skip_all)]
async fn close_opened(opened: Vec<live::Opened>) {
    for menu in opened {
        if let Err(error) = dbusmenu_closed_announced(menu).await {
            tracing::debug!(%error, "Could not close a menu after its window left");
        }
    }
}

fn activation_id(items: &[Item], label: &str) -> Option<i32> {
    items.iter().find_map(|item| {
        if item.label != label {
            return None;
        }
        match item.activation {
            Some(ItemId::DbusMenu { id }) => Some(id),
            _ => None,
        }
    })
}

async fn dbusmenu_section(
    proxy: &DBusMenuProxy<'_>,
    id: i32,
    path: &[String],
) -> Result<Vec<Item>, Error> {
    let layout = proxy
        .get_layout(0, DBUSMENU_DEPTH, &[])
        .await
        .map_err(Error::Layout)?;
    let Some(section) = resolve_section(&layout.root, id, path)? else {
        let layout = proxy.get_layout(id, 1, &[]).await.map_err(Error::Layout)?;
        return items_from(&layout.root);
    };

    items_from(&section)
}

/// Rows of an already-open D-BusMenu, without announcing `opened` again.
///
/// A layout or property update while the panel is up (View → Toolbars) has
/// to be read from the live tree. `AboutToShow` would rebuild Firefox under
/// new identifiers in the middle of an open menu.
async fn dbusmenu_live_items(
    connection: &zbus::Connection,
    endpoint: &Endpoint,
    id: i32,
    path: &[String],
) -> Result<Vec<Item>, Error> {
    let proxy = dbusmenu(connection, endpoint).await?;
    dbusmenu_section(&proxy, id, path).await
}

async fn gtk_items(
    connection: &zbus::Connection,
    endpoint: &Endpoint,
    id: &SectionId,
) -> Result<Vec<Item>, Error> {
    let Some((group, menu, app_menu)) = id.as_gtk() else {
        return Err(Error::NoMenuForFocusedWindow);
    };
    let path = if app_menu {
        endpoint
            .app_menu_path()
            .ok_or(Error::NoMenuForFocusedWindow)?
    } else {
        endpoint.path()
    };
    let proxy = gtk_menus_at(connection, endpoint.service(), path).await?;
    let (groups, subscribed) = gtk_subscribe(&proxy, &[group]).await?;
    let actions = gtk_describe(connection, endpoint).await;
    let items = gtk_menu_items(&groups, GtkLink { group, menu }, 0, &actions, app_menu)?;

    if let Err(error) = proxy.end(&subscribed).await {
        tracing::debug!(%error, "GTK menu declined to end the subscription");
    }

    Ok(items)
}

/// Subscribes to `org.gtk.Menus` group 0, then every group a `:submenu` or
/// `:section` link names. GTK4 puts File's rows in group 1; Start([0]) only
/// returns the menubar, so a reader that stops there sees File and then fails
/// looking up the group it points at.
#[instrument(name = "hyprbaric::global_menu::gtk_layout", skip(proxy), err)]
async fn gtk_layout(proxy: &GtkMenusProxy<'_>) -> Result<Vec<GtkGroup>, Error> {
    let (groups, subscribed) = gtk_subscribe(proxy, &[0]).await?;
    if let Err(error) = proxy.end(&subscribed).await {
        tracing::debug!(%error, "GTK menu declined to end the subscription");
    }
    Ok(groups)
}

async fn gtk_subscribe(
    proxy: &GtkMenusProxy<'_>,
    roots: &[u32],
) -> Result<(Vec<GtkGroup>, Vec<u32>), Error> {
    let mut subscribed = HashSet::new();
    let mut groups = Vec::new();
    let mut pending = roots.to_vec();

    while !pending.is_empty() {
        for group in &pending {
            subscribed.insert(*group);
        }
        groups.extend(proxy.start(&pending).await.map_err(Error::GtkLayout)?);
        pending = gtk_unfetched_groups(&groups, &subscribed);
    }

    Ok((groups, subscribed.into_iter().collect()))
}

/// Flattens one GTK menu, inlining the sections it is built from.
///
/// GTK expresses a divided menu as links to sections rather than as a list
/// with separators in it, and names some of them. The rows of a section belong
/// to the menu that links it, so they are read in place: a named section
/// becomes a caption, and an unnamed one that follows another becomes the
/// divider the menu was drawn with.
fn gtk_menu_items(
    groups: &[GtkGroup],
    link: GtkLink,
    depth: u8,
    actions: &gtk::Actions,
    app_menu: bool,
) -> Result<Vec<Item>, Error> {
    // Sections nest, and a malformed menu could link itself. The protocol has
    // no notion of depth, so the reader supplies the bound.
    const MAX_DEPTH: u8 = 8;

    let Ok(group) = gtk_group(groups, link) else {
        return Ok(Vec::new());
    };

    let mut items = Vec::new();
    for entry in &group.items {
        let Some(section) = gtk_link(entry, ":section") else {
            if gtk_optional_label(entry).is_none() && gtk_link(entry, ":submenu").is_none() {
                continue;
            }
            items.push(gtk::item(entry, actions, app_menu));
            continue;
        };

        if depth >= MAX_DEPTH {
            continue;
        }

        match gtk_optional_label(entry) {
            Some(label) => items.push(Item {
                label,
                enabled: false,
                kind: ItemKind::Group,
                shortcut: None,
                activation: None,
                submenu: None,
            }),
            None if !items.is_empty() => items.push(Item {
                label: String::new(),
                enabled: false,
                kind: ItemKind::Separator,
                shortcut: None,
                activation: None,
                submenu: None,
            }),
            None => {}
        }

        items.extend(gtk_menu_items(
            groups,
            section,
            depth + 1,
            actions,
            app_menu,
        )?);
    }

    Ok(without_empty_dividers(items))
}

async fn gtk_menus<'a>(
    connection: &zbus::Connection,
    endpoint: &Endpoint,
) -> Result<GtkMenusProxy<'a>, Error> {
    gtk_menus_at(connection, endpoint.service(), endpoint.path()).await
}

async fn gtk_menus_at<'a>(
    connection: &zbus::Connection,
    service: &str,
    path: &str,
) -> Result<GtkMenusProxy<'a>, Error> {
    GtkMenusProxy::builder(connection)
        .destination(service.to_owned())
        .map_err(Error::CreateGtkProxy)?
        .path(path.to_owned())
        .map_err(Error::CreateGtkProxy)?
        .build()
        .await
        .map_err(Error::CreateGtkProxy)
}

/// Activates a GTK action on whichever object group owns its scope.
///
/// GTK splits its actions between the application and the window, and the
/// prefix on the action name says which one to ask. The menu item's `target`
/// is the Activate parameter; without it the array is empty, which is how
/// GLib's action exporter treats a parameterless activation.
async fn gtk_activate(
    connection: &zbus::Connection,
    endpoint: &Endpoint,
    action: &str,
    target: Option<&[u8]>,
) -> Result<(), Error> {
    let (scope, name) = action
        .split_once('.')
        .ok_or_else(|| Error::UnscopedGtkAction {
            action: action.to_owned(),
        })?;
    let path = match scope {
        "app" => endpoint.application_path(),
        "win" => endpoint.window_path(),
        _ => None,
    }
    .ok_or_else(|| Error::UnscopedGtkAction {
        action: action.to_owned(),
    })?;

    let proxy = gtk_actions(connection, endpoint, path).await?;
    let decoded = match target {
        Some(bytes) => Some(gtk::decode_target(bytes).ok_or(Error::InvalidGtkTarget)?),
        None => None,
    };

    match decoded.as_deref() {
        Some(value) => proxy
            .activate(name, std::slice::from_ref(value), HashMap::new())
            .await
            .map_err(Error::Activate),
        None => proxy
            .activate(name, &[], HashMap::new())
            .await
            .map_err(Error::Activate),
    }
}

#[instrument(name = "hyprbaric::global_menu::gtk_describe", skip_all)]
async fn gtk_describe(connection: &zbus::Connection, endpoint: &Endpoint) -> gtk::Actions {
    let mut actions = gtk::Actions::default();
    gtk_describe_at(
        &mut actions,
        connection,
        endpoint,
        endpoint.application_path(),
        "app",
    )
    .await;
    gtk_describe_at(
        &mut actions,
        connection,
        endpoint,
        endpoint.window_path(),
        "win",
    )
    .await;
    gtk_describe_at(
        &mut actions,
        connection,
        endpoint,
        Some(endpoint.path()),
        "",
    )
    .await;
    actions
}

async fn gtk_describe_at(
    actions: &mut gtk::Actions,
    connection: &zbus::Connection,
    endpoint: &Endpoint,
    path: Option<&str>,
    scope: &str,
) {
    let Some(path) = path.filter(|path| !path.is_empty()) else {
        return;
    };

    let proxy = match gtk_actions(connection, endpoint, path).await {
        Ok(proxy) => proxy,
        Err(error) => {
            tracing::debug!(%error, path, scope, "Could not open the GTK action group");
            return;
        }
    };

    let descriptions = match proxy.describe_all().await {
        Ok(descriptions) => descriptions,
        Err(error) => {
            tracing::debug!(%error, path, scope, "Could not describe GTK actions");
            return;
        }
    };

    actions.mark_described(scope);
    for (name, description) in descriptions {
        let scoped = if scope.is_empty() {
            name
        } else {
            format!("{scope}.{name}")
        };
        actions.insert(
            scoped,
            gtk::Action::from_description(
                description.enabled,
                description.parameter_type,
                description.state,
            ),
        );
    }
}

async fn gtk_actions<'a>(
    connection: &zbus::Connection,
    endpoint: &Endpoint,
    path: &str,
) -> Result<gtk::GtkActionsProxy<'a>, Error> {
    gtk::GtkActionsProxy::builder(connection)
        .destination(endpoint.service().to_owned())
        .map_err(Error::CreateGtkProxy)?
        .path(path.to_owned())
        .map_err(Error::CreateGtkProxy)?
        .build()
        .await
        .map_err(Error::CreateGtkProxy)
}

#[instrument(name = "hyprbaric::global_menu::focused_endpoint")]
async fn focused_endpoint() -> Result<Endpoint, Error> {
    let client = Client::get_active_async()
        .await
        .map_err(Error::FocusedWindow)?
        .ok_or(Error::NoFocusedWindow)?;
    let address = client.address.to_string();
    let pid = u32::try_from(client.pid).ok().filter(|pid| *pid > 0);
    let (endpoints, companion_missing) = match companion_endpoints().await {
        Ok(endpoints) => (endpoints, false),
        Err(Error::CompanionUnavailable) => (Vec::new(), true),
        Err(error) => return Err(error),
    };

    for window in lineage(&address, &endpoints) {
        if let Some(endpoint) = menu_for_address(&endpoints, window) {
            if window != address {
                tracing::debug!(
                    focused = %address,
                    parent = %window,
                    service = %endpoint.service(),
                    path = %endpoint.path(),
                    "Resolved the focused dialog through its parent window"
                );
            }
            return Ok(endpoint.clone());
        }

        let xid = xid_of(&endpoints, window);
        if let Some(registration) = registrar::lookup(xid.map(registrar::WindowId), None) {
            tracing::debug!(
                focused = %address,
                %window,
                xid,
                service = %registration.service,
                path = %registration.path,
                "Resolved the window through the AppMenu registrar"
            );
            return Ok(Endpoint::from_registrar(window.to_owned(), registration));
        }
    }

    if let Some(registration) = registrar::lookup(None, pid) {
        tracing::debug!(
            %address,
            pid,
            service = %registration.service,
            path = %registration.path,
            "Resolved the focused window through the AppMenu registrar"
        );
        return Ok(Endpoint::from_registrar(address, registration));
    }

    if let Some(pid) = pid {
        if let Some(endpoint) = menu_for_process(&endpoints, pid).await {
            tracing::debug!(
                %address,
                pid,
                service = %endpoint.service(),
                path = %endpoint.path(),
                "Resolved the focused window through its D-Bus process"
            );
            return Ok(endpoint);
        }
    }

    if companion_missing {
        return Err(Error::CompanionUnavailable);
    }

    Err(Error::NoMenuForFocusedWindow)
}

fn menu_for_address<'a>(endpoints: &'a [Endpoint], address: &str) -> Option<&'a Endpoint> {
    endpoints
        .iter()
        .find(|endpoint| endpoint.exposes_menu() && endpoint.address() == Some(address))
}

/// Focused window, then each mapped parent the companion named.
///
/// Cycles are cut. A dialog with no `parent()` row stays a one-element line.
fn lineage<'a>(start: &'a str, endpoints: &'a [Endpoint]) -> Vec<&'a str> {
    let mut line = Vec::new();
    let mut seen = HashSet::new();
    let mut current = start;

    loop {
        if !seen.insert(current) {
            break;
        }
        line.push(current);
        match parent_of(endpoints, current) {
            Some(parent) => current = parent,
            None => break,
        }
    }

    line
}

fn parent_of<'a>(endpoints: &'a [Endpoint], address: &str) -> Option<&'a str> {
    endpoints.iter().find_map(|endpoint| {
        (endpoint.address() == Some(address))
            .then_some(endpoint.parent())
            .flatten()
            .filter(|parent| !parent.is_empty() && *parent != address)
    })
}

fn xid_of(endpoints: &[Endpoint], address: &str) -> Option<u32> {
    endpoints.iter().find_map(|endpoint| {
        (endpoint.address() == Some(address))
            .then_some(endpoint.xid())
            .flatten()
    })
}

/// GTK often publishes a menu before Hyprland has named the window, so the
/// companion snapshot has the D-Bus address and no compositor address. When
/// exactly one such menu belongs to the focused process, that is the window.
async fn menu_for_process(endpoints: &[Endpoint], pid: u32) -> Option<Endpoint> {
    let connection = zbus::Connection::session().await.ok()?;
    let mut pids = HashMap::new();
    for endpoint in endpoints {
        if !endpoint.exposes_menu() || endpoint.address().is_some() {
            continue;
        }
        if let std::collections::hash_map::Entry::Vacant(entry) =
            pids.entry(endpoint.service().to_owned())
        {
            if let Some(found) = process_id(&connection, endpoint.service()).await {
                entry.insert(found);
            }
        }
    }

    unique_unaddressed(endpoints, pid, |service| pids.get(service).copied()).cloned()
}

async fn process_id(connection: &zbus::Connection, service: &str) -> Option<u32> {
    let proxy = zbus::fdo::DBusProxy::new(connection).await.ok()?;
    let name = zbus::names::BusName::try_from(service).ok()?;
    proxy.get_connection_unix_process_id(name).await.ok()
}

fn unique_unaddressed<'a>(
    endpoints: &'a [Endpoint],
    pid: u32,
    pid_of: impl Fn(&str) -> Option<u32>,
) -> Option<&'a Endpoint> {
    let mut matches = endpoints.iter().filter(|endpoint| {
        endpoint.exposes_menu()
            && endpoint.address().is_none()
            && pid_of(endpoint.service()) == Some(pid)
    });
    let first = matches.next()?;
    matches.next().is_none().then_some(first)
}

async fn companion_endpoints() -> Result<Vec<Endpoint>, Error> {
    let mut command = Command::new("hyprctl");
    if let Ok(signature) = env::var("HYPRLAND_INSTANCE_SIGNATURE") {
        command.args(["-i", signature.as_str()]);
    }
    let output = command
        .args(["-j", "hyprbaric-appmenu"])
        .stdin(Stdio::null())
        .output()
        .await
        .map_err(Error::QueryPlugin)?;

    if !output.status.success() {
        return Err(Error::PluginRejected {
            status: output.status.code(),
        });
    }

    if String::from_utf8_lossy(&output.stdout)
        .trim()
        .starts_with("unknown request")
    {
        return Err(Error::CompanionUnavailable);
    }

    serde_json::from_slice(&output.stdout).map_err(Error::DecodeEndpoints)
}

impl Item {
    fn from(node: Node) -> Self {
        let kind = node.item_kind();
        let chrome = matches!(kind, ItemKind::Separator | ItemKind::Group);
        let submenu =
            (!chrome && node.opens_submenu()).then_some(SectionId::DbusMenu { id: node.id });

        Self {
            label: match kind {
                ItemKind::Separator => String::new(),
                ItemKind::Group => node.titled().unwrap_or_default(),
                _ => node.label(),
            },
            enabled: !chrome && node.enabled(),
            kind,
            shortcut: if chrome { None } else { node.shortcut() },
            activation: (!chrome && submenu.is_none()).then_some(ItemId::DbusMenu { id: node.id }),
            submenu,
            ..Self::empty()
        }
    }

    /// The neutral row every projection starts from.
    fn empty() -> Self {
        Self {
            label: String::new(),
            enabled: false,
            kind: ItemKind::Standard,
            shortcut: None,
            activation: None,
            submenu: None,
        }
    }
}

impl Node {
    fn property(&self, name: &str) -> Option<&str> {
        self.properties
            .get(name)
            .and_then(|value| value.downcast_ref::<&str>().ok())
    }

    fn flag(&self, name: &str) -> Option<bool> {
        self.properties
            .get(name)
            .and_then(|value| value.downcast_ref::<bool>().ok())
    }

    fn titled(&self) -> Option<String> {
        self.property("label")
            .map(strip_mnemonics)
            .filter(|label| !label.is_empty())
            .or_else(|| self.kde_title())
    }

    /// KDE section captions: a string `x-kde-title`, or boolean true with `label`.
    fn kde_title(&self) -> Option<String> {
        if self.flag("x-kde-title") == Some(true) {
            return self
                .property("label")
                .map(strip_mnemonics)
                .filter(|label| !label.is_empty());
        }

        self.property("x-kde-title")
            .map(strip_mnemonics)
            .filter(|label| !label.is_empty())
    }

    fn label(&self) -> String {
        self.titled().unwrap_or_else(|| "Untitled".to_owned())
    }

    fn enabled(&self) -> bool {
        self.flag("enabled").unwrap_or(true)
    }

    fn kind(&self) -> Option<&str> {
        self.property("type")
    }

    fn opens_submenu(&self) -> bool {
        self.property("children-display") == Some("submenu")
    }

    /// A menubar heading is a labeled submenu, not a command, divider, or caption.
    fn is_menubar_heading(&self) -> bool {
        self.visible()
            && !self.is_placeholder()
            && !matches!(self.item_kind(), ItemKind::Separator | ItemKind::Group)
            && self.titled().is_some()
            && (self.opens_submenu() || !self.children.is_empty())
    }

    /// Rows need a label unless they are a divider.
    fn is_row(&self) -> bool {
        self.visible()
            && !self.is_placeholder()
            && (self.item_kind() == ItemKind::Separator || self.titled().is_some())
    }

    fn visible(&self) -> bool {
        self.flag("visible").unwrap_or(true)
    }

    /// Firefox inserts an unlabeled dummy row so a still-empty popup counts as
    /// a submenu. It is not a real entry.
    fn is_placeholder(&self) -> bool {
        self.property("label").is_none()
            && self.kind().is_none()
            && self.property("children-display").is_none()
            && self.properties.get("x-kde-title").is_none()
    }

    fn child_nodes(&self) -> Result<Vec<Self>, Error> {
        self.children.iter().map(Self::try_from).collect()
    }

    fn item_kind(&self) -> ItemKind {
        if self.kde_title().is_some() {
            return ItemKind::Group;
        }

        if self.kind() == Some("separator") {
            return ItemKind::Separator;
        }

        // Absent toggle state means "unknown", which reads the same as off.
        let toggled = self
            .properties
            .get("toggle-state")
            .and_then(|value| value.downcast_ref::<i32>().ok())
            == Some(1);

        match self.property("toggle-type") {
            Some("checkmark") => ItemKind::Checkmark { checked: toggled },
            Some("radio") => ItemKind::Radio { selected: toggled },
            _ => ItemKind::Standard,
        }
    }

    /// Formats the first chord the application offers, as `Ctrl+Shift+N`.
    fn shortcut(&self) -> Option<String> {
        let chords = self.properties.get("shortcut")?;
        let chords = chords.downcast_ref::<&zbus::zvariant::Array>().ok()?;
        let first = chords.first()?;
        let keys = first.downcast_ref::<&zbus::zvariant::Array>().ok()?;

        let chord = keys
            .iter()
            .filter_map(|key| key.downcast_ref::<&str>().ok())
            .map(|key| match key {
                "Control" => "Ctrl",
                "Meta" => "Super",
                other => other,
            })
            .collect::<Vec<_>>()
            .join("+");

        (!chord.is_empty()).then_some(chord)
    }
}

impl TryFrom<&OwnedValue> for Node {
    type Error = Error;

    fn try_from(value: &OwnedValue) -> Result<Self, Self::Error> {
        let structure = value
            .downcast_ref::<&Structure>()
            .map_err(Error::DecodeLayout)?;
        let mut fields = structure.fields().iter();
        let id = match fields.next() {
            Some(Value::I32(id)) => *id,
            _ => return Err(Error::InvalidNode),
        };
        let properties = match fields.next() {
            Some(Value::Dict(properties)) => properties
                .iter()
                .filter_map(|(key, value)| {
                    let key = key.downcast_ref::<&str>().ok()?;
                    let value = OwnedValue::try_from(value).ok()?;
                    Some((key.to_owned(), value))
                })
                .collect(),
            _ => return Err(Error::InvalidNode),
        };
        let children = match fields.next() {
            Some(Value::Array(children)) => children
                .iter()
                .map(OwnedValue::try_from)
                .collect::<Result<Vec<_>, _>>()
                .map_err(Error::DecodeLayout)?,
            _ => return Err(Error::InvalidNode),
        };

        Ok(Self {
            id,
            properties,
            children,
        })
    }
}

fn items_from(parent: &Node) -> Result<Vec<Item>, Error> {
    Ok(without_empty_dividers(
        parent
            .child_nodes()?
            .into_iter()
            .filter(Node::is_row)
            .map(Item::from)
            .collect(),
    ))
}

/// Drops separators that do not sit between two real rows.
///
/// Applications pad menus with leading, trailing, and stacked dividers —
/// often because the rows beside them are hidden. A divider with nothing
/// before or after it is not a grouping, it is leftover chrome.
fn without_empty_dividers(items: Vec<Item>) -> Vec<Item> {
    let mut rows = Vec::with_capacity(items.len());
    for item in items {
        if item.kind == ItemKind::Separator
            && matches!(
                rows.last(),
                None | Some(Item {
                    kind: ItemKind::Separator,
                    ..
                })
            )
        {
            continue;
        }
        rows.push(item);
    }
    while matches!(
        rows.last(),
        Some(Item {
            kind: ItemKind::Separator,
            ..
        })
    ) {
        rows.pop();
    }
    rows
}

fn dbusmenu_tree(root: &Node) -> Result<(Menu, HashMap<SectionId, Vec<Item>>), Error> {
    let children = root.child_nodes()?;
    let mut sections = HashMap::new();
    let mut headings = Vec::new();

    for node in children.iter().filter(|node| node.is_menubar_heading()) {
        let id = SectionId::DbusMenu { id: node.id };
        headings.push(Section {
            id: id.clone(),
            label: node.titled().unwrap_or_default(),
            enabled: node.enabled(),
        });
        let items = items_from(node)?;
        dbusmenu_submenus(&items, root, &mut sections)?;
        sections.insert(id, items);
    }

    if headings.is_empty() {
        return dbusmenu_list(root);
    }

    Ok((Menu { sections: headings }, sections))
}

/// Root children are commands, not File/Edit/View. One menu, not one heading
/// per row.
fn dbusmenu_list(root: &Node) -> Result<(Menu, HashMap<SectionId, Vec<Item>>), Error> {
    let items = items_from(root)?;
    if items.is_empty() {
        return Ok((Menu::default(), HashMap::new()));
    }

    let mut sections = HashMap::new();
    let id = SectionId::DbusMenu { id: root.id };
    dbusmenu_submenus(&items, root, &mut sections)?;
    sections.insert(id.clone(), items);

    Ok((
        Menu {
            sections: vec![Section {
                id,
                label: root.titled().unwrap_or_default(),
                enabled: true,
            }],
        },
        sections,
    ))
}

/// Names a command list that the tree exported without a heading of its own.
fn entitle_anonymous_list(menu: &mut Menu, title: String) {
    if let [section] = menu.sections.as_mut_slice() {
        if section.label.is_empty() {
            section.label = title;
        }
    }
}

async fn focused_list_title() -> String {
    match Client::get_active_async().await {
        Ok(Some(client)) => {
            let class = client.class.trim();
            if !class.is_empty() {
                return class.to_owned();
            }
            let title = client.title.trim();
            if !title.is_empty() {
                return title.to_owned();
            }
        }
        _ => {}
    }

    "Menu".to_owned()
}

fn dbusmenu_submenus(
    items: &[Item],
    root: &Node,
    sections: &mut HashMap<SectionId, Vec<Item>>,
) -> Result<(), Error> {
    for item in items {
        let Some(SectionId::DbusMenu { id }) = item.submenu else {
            continue;
        };
        let submenu = SectionId::DbusMenu { id };
        if sections.contains_key(&submenu) {
            continue;
        }
        let Some(node) = find_by_id(root, id)? else {
            continue;
        };
        let nested = items_from(&node)?;
        dbusmenu_submenus(&nested, root, sections)?;
        sections.insert(submenu, nested);
    }

    Ok(())
}

fn gtk_tree(
    groups: &[GtkGroup],
    actions: &gtk::Actions,
) -> Result<(Menu, HashMap<SectionId, Vec<Item>>), Error> {
    let mut sections = HashMap::new();
    let mut headings = Vec::new();
    gtk_collect_headings(
        groups,
        GtkLink::ROOT,
        0,
        actions,
        &mut headings,
        &mut sections,
    )?;

    if headings.is_empty() {
        return gtk_list(groups, actions, false);
    }

    Ok((Menu { sections: headings }, sections))
}

/// One GTK application menu as a single titled heading in front of the menubar.
///
/// GTK3 can publish both. They are different `org.gtk.Menus` objects that both
/// start at `(group=0, menu=0)`, so the app-menu rows keep [`SectionId::GtkAppMenu`].
fn prepend_gtk_app_menu(
    mut menubar: Menu,
    mut sections: HashMap<SectionId, Vec<Item>>,
    app_groups: &[GtkGroup],
    actions: &gtk::Actions,
    title: String,
) -> Result<(Menu, HashMap<SectionId, Vec<Item>>), Error> {
    let (mut app_menu, app_sections) = gtk_list(app_groups, actions, true)?;
    if app_menu.sections.is_empty() {
        return Ok((menubar, sections));
    }

    entitle_anonymous_list(&mut app_menu, title);
    menubar.sections.splice(0..0, app_menu.sections);
    sections.extend(app_sections);
    Ok((menubar, sections))
}

/// Menubar headings, walking `:section` wrappers GIMP and LibreOffice use.
fn gtk_collect_headings(
    groups: &[GtkGroup],
    link: GtkLink,
    depth: u8,
    actions: &gtk::Actions,
    headings: &mut Vec<Section>,
    sections: &mut HashMap<SectionId, Vec<Item>>,
) -> Result<(), Error> {
    const MAX_DEPTH: u8 = 8;

    let Ok(root) = gtk_group(groups, link) else {
        return Ok(());
    };

    for item in &root.items {
        if let Some(section) = gtk_link(item, ":section") {
            if depth < MAX_DEPTH {
                gtk_collect_headings(groups, section, depth + 1, actions, headings, sections)?;
            }
            continue;
        }

        let Some(link) = gtk_link(item, ":submenu") else {
            continue;
        };
        let Some(label) = gtk_optional_label(item) else {
            continue;
        };
        let id = SectionId::gtk(link.group, link.menu, false);
        headings.push(Section {
            id: id.clone(),
            label,
            enabled: true,
        });
        gtk_cache(groups, link, actions, sections, false)?;
    }

    Ok(())
}

fn gtk_list(
    groups: &[GtkGroup],
    actions: &gtk::Actions,
    app_menu: bool,
) -> Result<(Menu, HashMap<SectionId, Vec<Item>>), Error> {
    let items = gtk_menu_items(groups, GtkLink::ROOT, 0, actions, app_menu)?;
    if items.is_empty() {
        return Ok((Menu::default(), HashMap::new()));
    }

    let mut sections = HashMap::new();
    let id = SectionId::gtk(0, 0, app_menu);
    for item in &items {
        if let Some((group, menu, nested)) = item.submenu.as_ref().and_then(SectionId::as_gtk) {
            gtk_cache(
                groups,
                GtkLink { group, menu },
                actions,
                &mut sections,
                nested,
            )?;
        }
    }
    sections.insert(id.clone(), items);

    Ok((
        Menu {
            sections: vec![Section {
                id,
                label: String::new(),
                enabled: true,
            }],
        },
        sections,
    ))
}

fn gtk_cache(
    groups: &[GtkGroup],
    link: GtkLink,
    actions: &gtk::Actions,
    sections: &mut HashMap<SectionId, Vec<Item>>,
    app_menu: bool,
) -> Result<(), Error> {
    let id = SectionId::gtk(link.group, link.menu, app_menu);
    if sections.contains_key(&id) {
        return Ok(());
    }

    let items = gtk_menu_items(groups, link, 0, actions, app_menu)?;
    for item in &items {
        if let Some((group, menu, nested)) = item.submenu.as_ref().and_then(SectionId::as_gtk) {
            gtk_cache(groups, GtkLink { group, menu }, actions, sections, nested)?;
        }
    }
    sections.insert(id, items);

    Ok(())
}

/// Groups a `:submenu` or `:section` names that have not been Start'd yet.
fn gtk_unfetched_groups(groups: &[GtkGroup], subscribed: &HashSet<u32>) -> Vec<u32> {
    let mut extra = HashSet::new();
    for group in groups {
        for item in &group.items {
            for relation in [":submenu", ":section"] {
                if let Some(link) = gtk_link(item, relation)
                    && !subscribed.contains(&link.group)
                {
                    extra.insert(link.group);
                }
            }
        }
    }
    extra.into_iter().collect()
}

fn resolve_section(root: &Node, id: i32, path: &[String]) -> Result<Option<Node>, Error> {
    if let Some(node) = find_by_id(root, id)? {
        return Ok(Some(node));
    }

    at_path(root, path)
}

/// The id to announce: the one we were given, or the node now sitting at the
/// same label path after Firefox rebuilt the tree.
fn destination(root: &Node, id: i32, path: &[String]) -> Result<i32, Error> {
    if find_by_id(root, id)?.is_some() {
        return Ok(id);
    }

    Ok(at_path(root, path)?.map(|node| node.id).unwrap_or(id))
}

fn find_by_id(root: &Node, id: i32) -> Result<Option<Node>, Error> {
    if root.id == id {
        return Ok(Some(root.clone()));
    }

    for child in root.child_nodes()? {
        if let Some(found) = find_by_id(&child, id)? {
            return Ok(Some(found));
        }
    }

    Ok(None)
}

fn path_to(root: &Node, id: i32) -> Result<Option<Vec<String>>, Error> {
    fn walk(node: &Node, id: i32, path: &mut Vec<String>) -> Result<bool, Error> {
        if node.id == id {
            return Ok(true);
        }

        for child in node.child_nodes()? {
            path.push(child.label());
            if walk(&child, id, path)? {
                return Ok(true);
            }
            path.pop();
        }

        Ok(false)
    }

    let mut path = Vec::new();
    Ok(walk(root, id, &mut path)?.then_some(path))
}

fn at_path(root: &Node, path: &[String]) -> Result<Option<Node>, Error> {
    if path.is_empty() {
        return Ok(None);
    }

    let mut current = None;
    let mut nodes = root.child_nodes()?;
    for (index, label) in path.iter().enumerate() {
        let Some(node) = nodes.into_iter().find(|child| child.label() == *label) else {
            return Ok(None);
        };
        if index + 1 == path.len() {
            current = Some(node);
            break;
        }
        nodes = node.child_nodes()?;
    }

    Ok(current)
}

fn strip_mnemonics(value: &str) -> String {
    value
        .replace("__", "\0")
        .replace('_', "")
        .replace('\0', "_")
}

fn timestamp() -> u32 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|elapsed| elapsed.as_secs() as u32)
        .unwrap_or_default()
}

fn gtk_group(groups: &[GtkGroup], link: GtkLink) -> Result<&GtkGroup, Error> {
    groups
        .iter()
        .find(|group| group.group == link.group && group.menu == link.menu)
        .ok_or(Error::MissingGtkGroup {
            group: link.group,
            menu: link.menu,
        })
}

fn gtk_label(item: &HashMap<String, OwnedValue>) -> String {
    gtk_optional_label(item).unwrap_or_else(|| "Untitled".to_owned())
}

fn gtk_optional_label(item: &HashMap<String, OwnedValue>) -> Option<String> {
    item.get("label")
        .and_then(|value| value.downcast_ref::<&str>().ok())
        .map(strip_mnemonics)
        .filter(|label| !label.is_empty())
}

fn gtk_link(item: &HashMap<String, OwnedValue>, name: &str) -> Option<GtkLink> {
    let structure = item.get(name)?.downcast_ref::<&Structure>().ok()?;
    let mut fields = structure.fields().iter();
    let group = match fields.next()? {
        Value::U32(group) => *group,
        _ => return None,
    };
    let menu = match fields.next()? {
        Value::U32(menu) => *menu,
        _ => return None,
    };

    Some(GtkLink { group, menu })
}

#[proxy(interface = "com.canonical.dbusmenu", assume_defaults = true)]
trait DBusMenu {
    fn get_layout(
        &self,
        parent_id: i32,
        recursion_depth: i32,
        property_names: &[&str],
    ) -> zbus::Result<Layout>;

    fn about_to_show(&self, id: i32) -> zbus::Result<bool>;

    fn event(&self, id: i32, event_id: &str, data: &Value<'_>, timestamp: u32) -> zbus::Result<()>;

    #[zbus(signal)]
    fn layout_updated(&self, revision: u32, parent: i32) -> zbus::Result<()>;

    #[zbus(signal)]
    fn items_properties_updated(
        &self,
        updated_props: Vec<(i32, HashMap<String, OwnedValue>)>,
        removed_props: Vec<(i32, Vec<String>)>,
    ) -> zbus::Result<()>;
}

#[proxy(interface = "org.gtk.Menus", assume_defaults = true)]
trait GtkMenus {
    fn start(&self, groups: &[u32]) -> zbus::Result<Vec<GtkGroup>>;

    fn end(&self, groups: &[u32]) -> zbus::Result<()>;

    #[zbus(signal)]
    fn changed(&self, group: u32, menus: Vec<GtkGroup>) -> zbus::Result<()>;
}

#[derive(Deserialize, Type)]
struct Layout {
    #[allow(dead_code)]
    revision: u32,
    root: Node,
}

#[derive(Clone, Deserialize, Type)]
struct Node {
    id: i32,
    properties: HashMap<String, OwnedValue>,
    children: Vec<OwnedValue>,
}

#[derive(Clone, Debug, Deserialize, Type)]
struct GtkGroup {
    group: u32,
    menu: u32,
    items: Vec<HashMap<String, OwnedValue>>,
}

#[derive(Clone, Copy, Debug)]
struct GtkLink {
    group: u32,
    menu: u32,
}

impl GtkLink {
    const ROOT: Self = Self { group: 0, menu: 0 };
}

/// One companion row, in the shape of the protocol it speaks.
///
/// The plugin JSON is a tagged bag. That is decoded into this enum immediately,
/// so an X11 association cannot be asked for rows and a D-BusMenu cannot carry
/// GTK action paths.
#[derive(Clone, Debug, PartialEq, Eq)]
enum Endpoint {
    DbusMenu {
        address: Option<String>,
        service: String,
        path: String,
        xid: Option<u32>,
    },
    Gtk {
        address: Option<String>,
        service: String,
        path: String,
        /// Set only when GTK published both a menubar and a distinct app menu.
        app_menu_path: Option<String>,
        application_path: Option<String>,
        window_path: Option<String>,
        xid: Option<u32>,
    },
    /// Wayland address joined to an X11 window, with no menu of its own.
    X11 {
        address: Option<String>,
        xid: Option<u32>,
    },
    /// A mapped window and the owner Hyprland reports for it.
    Parent {
        address: Option<String>,
        parent: String,
    },
}

/// Companion JSON before it is sorted into [`Endpoint`].
#[derive(Clone, Debug, Deserialize, PartialEq, Eq)]
struct PluginEndpoint {
    #[serde(default)]
    kind: EndpointKind,
    address: Option<String>,
    #[serde(default)]
    service: String,
    #[serde(default)]
    path: String,
    #[serde(default)]
    app_menu_path: Option<String>,
    #[serde(default)]
    application_path: Option<String>,
    #[serde(default)]
    window_path: Option<String>,
    #[serde(default)]
    xid: Option<u32>,
    #[serde(default)]
    parent: Option<String>,
}

impl From<PluginEndpoint> for Endpoint {
    fn from(row: PluginEndpoint) -> Self {
        match row.kind {
            EndpointKind::DbusMenu => Self::DbusMenu {
                address: row.address,
                service: row.service,
                path: row.path,
                xid: row.xid,
            },
            EndpointKind::Gtk => Self::Gtk {
                address: row.address,
                service: row.service,
                path: row.path,
                app_menu_path: row.app_menu_path.filter(|path| !path.is_empty()),
                application_path: row.application_path,
                window_path: row.window_path,
                xid: row.xid,
            },
            EndpointKind::X11 => Self::X11 {
                address: row.address,
                xid: row.xid,
            },
            EndpointKind::Parent => Self::Parent {
                address: row.address,
                parent: row.parent.unwrap_or_default(),
            },
        }
    }
}

impl<'de> Deserialize<'de> for Endpoint {
    fn deserialize<D: serde::Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        PluginEndpoint::deserialize(deserializer).map(Self::from)
    }
}

impl Endpoint {
    fn from_registrar(address: String, registration: registrar::Registration) -> Self {
        Self::DbusMenu {
            address: Some(address),
            service: registration.service,
            path: registration.path,
            xid: None,
        }
    }

    fn exposes_menu(&self) -> bool {
        match self {
            Self::DbusMenu { service, path, .. } | Self::Gtk { service, path, .. } => {
                !service.is_empty() && !path.is_empty()
            }
            Self::X11 { .. } | Self::Parent { .. } => false,
        }
    }

    fn address(&self) -> Option<&str> {
        match self {
            Self::DbusMenu { address, .. }
            | Self::Gtk { address, .. }
            | Self::X11 { address, .. }
            | Self::Parent { address, .. } => address.as_deref(),
        }
    }

    fn xid(&self) -> Option<u32> {
        match self {
            Self::DbusMenu { xid, .. } | Self::Gtk { xid, .. } | Self::X11 { xid, .. } => *xid,
            Self::Parent { .. } => None,
        }
    }

    fn parent(&self) -> Option<&str> {
        match self {
            Self::Parent { parent, .. } => Some(parent.as_str()),
            Self::DbusMenu { .. } | Self::Gtk { .. } | Self::X11 { .. } => None,
        }
    }

    fn service(&self) -> &str {
        match self {
            Self::DbusMenu { service, .. } | Self::Gtk { service, .. } => service,
            Self::X11 { .. } | Self::Parent { .. } => "",
        }
    }

    fn path(&self) -> &str {
        match self {
            Self::DbusMenu { path, .. } | Self::Gtk { path, .. } => path,
            Self::X11 { .. } | Self::Parent { .. } => "",
        }
    }

    fn app_menu_path(&self) -> Option<&str> {
        match self {
            Self::Gtk { app_menu_path, .. } => app_menu_path.as_deref(),
            Self::DbusMenu { .. } | Self::X11 { .. } | Self::Parent { .. } => None,
        }
    }

    fn application_path(&self) -> Option<&str> {
        match self {
            Self::Gtk {
                application_path, ..
            } => application_path.as_deref(),
            Self::DbusMenu { .. } | Self::X11 { .. } | Self::Parent { .. } => None,
        }
    }

    fn window_path(&self) -> Option<&str> {
        match self {
            Self::Gtk { window_path, .. } => window_path.as_deref(),
            Self::DbusMenu { .. } | Self::X11 { .. } | Self::Parent { .. } => None,
        }
    }
}

#[derive(Clone, Debug, Default, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
enum EndpointKind {
    #[default]
    DbusMenu,
    Gtk,
    X11,
    Parent,
}

/// Focused AppMenu read failures.
#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("failed to read the focused Hyprland window")]
    FocusedWindow(#[source] hyprland::error::HyprError),
    #[error("there is no focused Hyprland window")]
    NoFocusedWindow,
    #[error("failed to query the Hyprbaric AppMenu companion")]
    QueryPlugin(#[source] std::io::Error),
    #[error("the Hyprbaric AppMenu companion rejected the query with status {status:?}")]
    PluginRejected { status: Option<i32> },
    #[error("the Hyprbaric AppMenu companion is not loaded")]
    CompanionUnavailable,
    #[error("the Hyprbaric AppMenu companion returned invalid JSON")]
    DecodeEndpoints(#[source] serde_json::Error),
    #[error("the focused window does not expose an AppMenu")]
    NoMenuForFocusedWindow,
    #[error("failed to connect to the session bus")]
    Connect(#[source] zbus::Error),
    #[error("failed to create the D-BusMenu proxy")]
    CreateProxy(#[source] zbus::Error),
    #[error("failed to read the D-BusMenu layout")]
    Layout(#[source] zbus::Error),
    #[error("failed to create the GTK menu proxy")]
    CreateGtkProxy(#[source] zbus::Error),
    #[error("failed to read the GTK menu layout")]
    GtkLayout(#[source] zbus::Error),
    #[error("the GTK menu omitted group {group}, menu {menu}")]
    MissingGtkGroup { group: u32, menu: u32 },
    #[error("the GTK action `{action}` names no reachable action group")]
    UnscopedGtkAction { action: String },
    #[error("the GTK action target could not be decoded")]
    InvalidGtkTarget,
    #[error("the application refused the activation")]
    Activate(#[source] zbus::Error),
    #[error("the application refused the menu event")]
    Event(#[source] zbus::Error),
    #[error("the D-BusMenu layout used an unsupported value")]
    DecodeLayout(#[source] zbus::zvariant::Error),
    #[error("the D-BusMenu layout contained an invalid item")]
    InvalidNode,
}

impl Error {
    /// Empty workspace, or a window that never published a menu.
    ///
    /// The bar asks on every focus change and retries while a new window
    /// catches up. Those answers are the usual ones, not a fault in the bar.
    pub fn is_absence(&self) -> bool {
        matches!(self, Self::NoFocusedWindow | Self::NoMenuForFocusedWindow)
    }
}

#[cfg(test)]
mod tests {
    use std::collections::{HashMap, HashSet};

    use zbus::zvariant::{OwnedValue, Value};

    use super::{
        DbusMenuEvent, Endpoint, Error, GtkGroup, GtkLink, Item, ItemId, ItemKind, Menu, Node,
        SectionId, at_path, dbusmenu_tree, destination, dismiss, entitle_anonymous_list, gtk,
        gtk_menu_items, gtk_tree, gtk_unfetched_groups, items_from, lineage, menu_for_address,
        path_to, prepend_gtk_app_menu, resolve_section, strip_mnemonics, unique_unaddressed,
        without_empty_dividers,
    };

    fn endpoint(json: &str) -> Endpoint {
        serde_json::from_str(json).expect("endpoint should decode")
    }

    fn node(id: i32, properties: &[(&str, Value<'static>)]) -> Node {
        Node {
            id,
            properties: properties
                .iter()
                .map(|(key, value)| {
                    (
                        (*key).to_owned(),
                        OwnedValue::try_from(value.clone()).expect("property should convert"),
                    )
                })
                .collect(),
            children: Vec::new(),
        }
    }

    fn gtk_entry(
        attributes: &[(&str, Value<'static>)],
        section: Option<(u32, u32)>,
    ) -> HashMap<String, OwnedValue> {
        let mut entry = attributes
            .iter()
            .map(|(key, value)| {
                (
                    (*key).to_owned(),
                    OwnedValue::try_from(value.clone()).expect("attribute should convert"),
                )
            })
            .collect::<HashMap<_, _>>();

        if let Some((group, menu)) = section {
            let link = zbus::zvariant::StructureBuilder::new()
                .add_field(group)
                .add_field(menu)
                .build()
                .expect("a section link should build");
            entry.insert(
                ":section".to_owned(),
                OwnedValue::try_from(Value::from(link)).expect("link should convert"),
            );
        }

        entry
    }

    fn gtk_submenu(label: &str, group: u32, menu: u32) -> HashMap<String, OwnedValue> {
        let mut entry = gtk_entry(&[], None);
        entry.insert(
            "label".to_owned(),
            OwnedValue::try_from(Value::from(label.to_owned())).expect("label should convert"),
        );
        let link = zbus::zvariant::StructureBuilder::new()
            .add_field(group)
            .add_field(menu)
            .build()
            .expect("a submenu link should build");
        entry.insert(
            ":submenu".to_owned(),
            OwnedValue::try_from(Value::from(link)).expect("link should convert"),
        );
        entry
    }

    fn shortcut(chord: &[&str]) -> Value<'static> {
        let keys = chord
            .iter()
            .map(|key| (*key).to_owned())
            .collect::<Vec<_>>();

        Value::from(vec![keys])
    }

    #[test]
    fn mnemonic_underscores_are_stripped_but_literal_ones_survive() {
        assert_eq!(strip_mnemonics("_File"), "File");
        assert_eq!(strip_mnemonics("Sele_ction"), "Selection");
        assert_eq!(strip_mnemonics("Save __All"), "Save _All");
    }

    #[test]
    fn dbusmenu_events_use_the_protocol_names() {
        assert_eq!(DbusMenuEvent::Opened.as_str(), "opened");
        assert_eq!(DbusMenuEvent::Closed.as_str(), "closed");
        assert_eq!(DbusMenuEvent::Clicked.as_str(), "clicked");
    }

    #[test]
    fn a_window_without_a_menu_is_an_absence_not_a_fault() {
        assert!(Error::NoFocusedWindow.is_absence());
        assert!(Error::NoMenuForFocusedWindow.is_absence());
        assert!(!Error::CompanionUnavailable.is_absence());
        assert!(!Error::InvalidNode.is_absence());
    }

    #[tokio::test]
    async fn a_gtk_heading_has_nothing_to_close() {
        dismiss(&SectionId::Gtk { group: 0, menu: 1 })
            .await
            .expect("GTK dismiss is a no-op");
        dismiss(&SectionId::GtkAppMenu { group: 0, menu: 0 })
            .await
            .expect("GTK application-menu dismiss is a no-op");
    }

    #[test]
    fn a_row_without_a_label_is_named_rather_than_blank() {
        assert_eq!(node(1, &[]).label(), "Untitled");
        assert_eq!(node(1, &[]).titled(), None);
        assert_eq!(node(1, &[("label", Value::from("_Open"))]).label(), "Open");
    }

    #[test]
    fn a_chord_is_spelled_the_way_the_rest_of_the_bar_spells_one() {
        assert_eq!(
            node(1, &[("shortcut", shortcut(&["Control", "Shift", "N"]))]).shortcut(),
            Some("Ctrl+Shift+N".to_owned())
        );
        assert_eq!(node(1, &[]).shortcut(), None);
    }

    #[test]
    fn toggle_properties_become_the_row_kind_they_describe() {
        let checked = node(
            1,
            &[
                ("toggle-type", Value::from("checkmark")),
                ("toggle-state", Value::from(1i32)),
            ],
        );
        let radio = node(
            1,
            &[
                ("toggle-type", Value::from("radio")),
                ("toggle-state", Value::from(0i32)),
            ],
        );

        assert_eq!(checked.item_kind(), ItemKind::Checkmark { checked: true });
        assert_eq!(radio.item_kind(), ItemKind::Radio { selected: false });
        assert_eq!(node(1, &[]).item_kind(), ItemKind::Standard);
    }

    #[test]
    fn an_unknown_toggle_state_reads_as_off() {
        let unknown = node(
            1,
            &[
                ("toggle-type", Value::from("checkmark")),
                ("toggle-state", Value::from(-1i32)),
            ],
        );

        assert_eq!(unknown.item_kind(), ItemKind::Checkmark { checked: false });
    }

    #[test]
    fn a_row_that_opens_a_menu_leads_there_instead_of_activating() {
        let item = Item::from(node(
            7,
            &[
                ("label", Value::from("Open _Recent")),
                ("children-display", Value::from("submenu")),
            ],
        ));

        assert_eq!(item.submenu, Some(SectionId::DbusMenu { id: 7 }));
        assert_eq!(item.activation, None);
    }

    #[test]
    fn an_ordinary_row_activates_by_its_own_identifier() {
        let item = Item::from(node(9, &[("label", Value::from("_New"))]));

        assert_eq!(item.activation, Some(ItemId::DbusMenu { id: 9 }));
        assert_eq!(item.submenu, None);
    }

    #[test]
    fn a_named_gtk_section_becomes_a_caption_over_its_rows() {
        let groups = vec![
            GtkGroup {
                group: 0,
                menu: 0,
                items: vec![gtk_entry(&[("label", Value::from("Recent"))], Some((0, 1)))],
            },
            GtkGroup {
                group: 0,
                menu: 1,
                items: vec![gtk_entry(&[("label", Value::from("bar.tsx"))], None)],
            },
        ];

        let items = gtk_menu_items(&groups, GtkLink::ROOT, 0, &gtk::Actions::default(), false)
            .expect("menu should read");

        assert_eq!(items.len(), 2);
        assert_eq!(items[0].kind, ItemKind::Group);
        assert_eq!(items[0].label, "Recent");
        assert_eq!(items[1].label, "bar.tsx");
    }

    #[test]
    fn an_unnamed_gtk_section_divides_the_rows_before_it() {
        let groups = vec![
            GtkGroup {
                group: 0,
                menu: 0,
                items: vec![
                    gtk_entry(&[("label", Value::from("New"))], None),
                    gtk_entry(&[], Some((0, 1))),
                ],
            },
            GtkGroup {
                group: 0,
                menu: 1,
                items: vec![gtk_entry(&[("label", Value::from("Quit"))], None)],
            },
        ];

        let items = gtk_menu_items(&groups, GtkLink::ROOT, 0, &gtk::Actions::default(), false)
            .expect("menu should read");

        assert_eq!(items.len(), 3);
        assert_eq!(items[1].kind, ItemKind::Separator);
        assert_eq!(items[2].label, "Quit");
    }

    #[test]
    fn a_leading_unnamed_gtk_section_adds_no_divider() {
        let groups = vec![
            GtkGroup {
                group: 0,
                menu: 0,
                items: vec![gtk_entry(&[], Some((0, 1)))],
            },
            GtkGroup {
                group: 0,
                menu: 1,
                items: vec![gtk_entry(&[("label", Value::from("New"))], None)],
            },
        ];

        let items = gtk_menu_items(&groups, GtkLink::ROOT, 0, &gtk::Actions::default(), false)
            .expect("menu should read");

        assert_eq!(items.len(), 1);
        assert_eq!(items[0].label, "New");
    }

    #[test]
    fn a_trailing_unnamed_gtk_section_adds_no_divider() {
        let groups = vec![
            GtkGroup {
                group: 0,
                menu: 0,
                items: vec![
                    gtk_entry(&[("label", Value::from("New"))], None),
                    gtk_entry(&[], Some((0, 1))),
                ],
            },
            GtkGroup {
                group: 0,
                menu: 1,
                items: vec![],
            },
        ];

        let items = gtk_menu_items(&groups, GtkLink::ROOT, 0, &gtk::Actions::default(), false)
            .expect("menu should read");

        assert_eq!(items.len(), 1);
        assert_eq!(items[0].label, "New");
    }

    #[test]
    fn a_separator_neither_activates_nor_opens() {
        let item = Item::from(node(4, &[("type", Value::from("separator"))]));

        assert_eq!(item.kind, ItemKind::Separator);
        assert_eq!(item.activation, None);
        assert_eq!(item.submenu, None);
    }

    #[test]
    fn a_kde_title_is_a_caption_not_a_command() {
        let item = Item::from(node(
            8,
            &[
                ("type", Value::from("separator")),
                ("x-kde-title", Value::from(true)),
                ("label", Value::from("_Recent")),
            ],
        ));

        assert_eq!(item.kind, ItemKind::Group);
        assert_eq!(item.label, "Recent");
        assert!(!item.enabled);
        assert_eq!(item.activation, None);
        assert_eq!(item.submenu, None);
    }

    #[test]
    fn a_string_kde_title_without_a_label_is_still_a_caption() {
        let item = Item::from(node(8, &[("x-kde-title", Value::from("Sessions"))]));

        assert_eq!(item.kind, ItemKind::Group);
        assert_eq!(item.label, "Sessions");
        assert_eq!(item.activation, None);
    }

    #[test]
    fn a_kde_title_flag_without_text_stays_a_separator() {
        let item = Item::from(node(
            4,
            &[
                ("type", Value::from("separator")),
                ("x-kde-title", Value::from(true)),
            ],
        ));

        assert_eq!(item.kind, ItemKind::Separator);
        assert_eq!(item.label, "");
    }

    #[test]
    fn kde_titles_are_kept_among_the_rows() {
        let parent = Node {
            id: 1,
            properties: HashMap::new(),
            children: vec![
                encoded(2, "New", Vec::new()),
                encoded_with(
                    3,
                    &[
                        ("type", Value::from("separator")),
                        ("x-kde-title", Value::from(true)),
                        ("label", Value::from("Recent")),
                    ],
                    Vec::new(),
                ),
                encoded(4, "notes.txt", Vec::new()),
            ],
        };

        let items = items_from(&parent).expect("rows should decode");

        assert_eq!(
            items
                .iter()
                .map(|item| (item.label.as_str(), item.kind))
                .collect::<Vec<_>>(),
            [
                ("New", ItemKind::Standard),
                ("Recent", ItemKind::Group),
                ("notes.txt", ItemKind::Standard),
            ]
        );
    }

    #[test]
    fn empty_dividers_are_not_kept() {
        let row = |label: &str| Item {
            label: label.to_owned(),
            enabled: true,
            kind: ItemKind::Standard,
            shortcut: None,
            activation: None,
            submenu: None,
        };
        let divider = Item {
            label: String::new(),
            enabled: false,
            kind: ItemKind::Separator,
            shortcut: None,
            activation: None,
            submenu: None,
        };

        let compacted = without_empty_dividers(vec![
            divider.clone(),
            row("Sidebar"),
            divider.clone(),
            divider.clone(),
            row("Zoom"),
            divider,
        ]);

        assert_eq!(compacted.len(), 3);
        assert_eq!(compacted[0].label, "Sidebar");
        assert_eq!(compacted[1].kind, ItemKind::Separator);
        assert_eq!(compacted[2].label, "Zoom");
    }

    #[test]
    fn a_menu_of_only_dividers_is_empty() {
        let divider = Item {
            label: String::new(),
            enabled: false,
            kind: ItemKind::Separator,
            shortcut: None,
            activation: None,
            submenu: None,
        };

        assert!(without_empty_dividers(vec![divider.clone(), divider]).is_empty());
    }

    #[test]
    fn a_companion_x11_record_is_not_a_menu() {
        let endpoint: Endpoint =
            serde_json::from_str(r#"{"kind":"x11","address":"0xabc","xid":4242}"#)
                .expect("an X11 association should decode");

        assert!(matches!(endpoint, Endpoint::X11 { .. }));
        assert_eq!(endpoint.address(), Some("0xabc"));
        assert_eq!(endpoint.xid(), Some(4242));
        assert!(!endpoint.exposes_menu());
    }

    #[test]
    fn a_legacy_dbusmenu_record_still_exposes_a_menu() {
        let decoded = endpoint(r#"{"address":"0xabc","service":":1.9","path":"/MenuBar/1"}"#);

        assert!(matches!(decoded, Endpoint::DbusMenu { .. }));
        assert!(decoded.exposes_menu());
    }

    #[test]
    fn a_gtk_record_keeps_a_separate_application_menu_path() {
        let decoded = endpoint(
            r#"{"kind":"gtk","service":":1.10","path":"/menus/menubar","app_menu_path":"/menus/appmenu"}"#,
        );

        assert_eq!(decoded.path(), "/menus/menubar");
        assert_eq!(decoded.app_menu_path(), Some("/menus/appmenu"));
    }

    #[test]
    fn a_menu_is_chosen_by_the_focused_window_address() {
        let endpoints = vec![
            endpoint(r#"{"kind":"gtk","service":":1.10","path":"/menus/menubar"}"#),
            endpoint(
                r#"{"kind":"dbusmenu","address":"0xabc","service":":1.9","path":"/MenuBar/1"}"#,
            ),
        ];

        let found = menu_for_address(&endpoints, "0xabc").expect("addressed menu should match");
        assert_eq!(found.service(), ":1.9");
    }

    #[test]
    fn a_parent_record_is_not_a_menu() {
        let endpoint: Endpoint =
            serde_json::from_str(r#"{"kind":"parent","address":"0xdialog","parent":"0xwriter"}"#)
                .expect("a parent link should decode");

        assert!(matches!(endpoint, Endpoint::Parent { .. }));
        assert_eq!(endpoint.address(), Some("0xdialog"));
        assert_eq!(endpoint.parent(), Some("0xwriter"));
        assert!(!endpoint.exposes_menu());
    }

    #[test]
    fn a_dialog_uses_the_mapped_parent_menu() {
        let endpoints = vec![
            endpoint(r#"{"kind":"parent","address":"0xdialog","parent":"0xwriter"}"#),
            endpoint(
                r#"{"kind":"dbusmenu","address":"0xwriter","service":":1.9","path":"/MenuBar/1"}"#,
            ),
        ];

        assert!(menu_for_address(&endpoints, "0xdialog").is_none());
        assert_eq!(lineage("0xdialog", &endpoints), ["0xdialog", "0xwriter"]);
        let found = lineage("0xdialog", &endpoints)
            .into_iter()
            .find_map(|window| menu_for_address(&endpoints, window))
            .expect("the writer menu should match");
        assert_eq!(found.service(), ":1.9");
    }

    #[test]
    fn a_parent_cycle_does_not_loop() {
        let endpoints = vec![
            endpoint(r#"{"kind":"parent","address":"0xa","parent":"0xb"}"#),
            endpoint(r#"{"kind":"parent","address":"0xb","parent":"0xa"}"#),
        ];

        assert_eq!(lineage("0xa", &endpoints), ["0xa", "0xb"]);
    }

    #[test]
    fn a_window_without_a_parent_stays_itself() {
        let endpoints = vec![endpoint(
            r#"{"kind":"dbusmenu","address":"0xwriter","service":":1.9","path":"/MenuBar/1"}"#,
        )];

        assert_eq!(lineage("0xwriter", &endpoints), ["0xwriter"]);
    }

    #[test]
    fn an_addressless_menu_matches_when_it_is_the_only_one_for_the_process() {
        let endpoints = vec![
            endpoint(r#"{"kind":"gtk","service":":1.10","path":"/menus/menubar"}"#),
            endpoint(
                r#"{"kind":"dbusmenu","address":"0xabc","service":":1.9","path":"/MenuBar/1"}"#,
            ),
        ];

        let found = unique_unaddressed(&endpoints, 4242, |service| {
            (service == ":1.10").then_some(4242)
        })
        .expect("the gtk export should match");
        assert_eq!(found.service(), ":1.10");
        assert_eq!(found.path(), "/menus/menubar");
    }

    #[test]
    fn two_addressless_menus_for_the_same_process_are_not_guessed() {
        let endpoints = vec![
            endpoint(r#"{"kind":"gtk","service":":1.10","path":"/win1"}"#),
            endpoint(r#"{"kind":"gtk","service":":1.11","path":"/win2"}"#),
        ];

        assert!(unique_unaddressed(&endpoints, 4242, |_| Some(4242)).is_none());
    }

    #[test]
    fn an_addressed_menu_is_not_used_as_a_process_fallback() {
        let endpoints = vec![endpoint(
            r#"{"kind":"gtk","address":"0xother","service":":1.10","path":"/menus/menubar"}"#,
        )];

        assert!(unique_unaddressed(&endpoints, 4242, |_| Some(4242)).is_none());
    }

    fn encoded(id: i32, label: &str, children: Vec<OwnedValue>) -> OwnedValue {
        let mut properties = HashMap::<String, Value<'_>>::new();
        properties.insert("label".to_owned(), Value::from(label.to_owned()));
        OwnedValue::try_from(Value::from((id, properties, children)))
            .expect("a D-BusMenu node should encode")
    }

    fn encoded_separator(id: i32) -> OwnedValue {
        encoded_with(id, &[("type", Value::from("separator"))], Vec::new())
    }

    fn encoded_submenu(id: i32, label: &str) -> OwnedValue {
        let mut properties = HashMap::<String, Value<'_>>::new();
        properties.insert("label".to_owned(), Value::from(label.to_owned()));
        properties.insert("children-display".to_owned(), Value::from("submenu"));
        OwnedValue::try_from(Value::from((id, properties, Vec::<OwnedValue>::new())))
            .expect("a D-BusMenu submenu should encode")
    }

    fn encoded_with(
        id: i32,
        properties: &[(&'static str, Value<'static>)],
        children: Vec<OwnedValue>,
    ) -> OwnedValue {
        let mut map = HashMap::<String, Value<'_>>::new();
        for (key, value) in properties {
            map.insert((*key).to_owned(), value.clone());
        }
        OwnedValue::try_from(Value::from((id, map, children)))
            .expect("a D-BusMenu node should encode")
    }

    fn tree(id: i32, label: &str, children: Vec<OwnedValue>) -> Node {
        Node {
            id,
            properties: {
                let mut properties = HashMap::new();
                properties.insert(
                    "label".to_owned(),
                    OwnedValue::try_from(Value::from(label)).expect("label should encode"),
                );
                properties
            },
            children,
        }
    }

    #[test]
    fn a_heading_is_found_by_label_after_its_identifier_changes() {
        let before = tree(
            0,
            "",
            vec![encoded(5, "Edit", vec![encoded(6, "Undo", Vec::new())])],
        );
        let after = tree(
            0,
            "",
            vec![encoded(50, "Edit", vec![encoded(60, "Undo", Vec::new())])],
        );

        let path = path_to(&before, 5)
            .expect("path should walk")
            .expect("id 5 exists");
        assert_eq!(path, vec!["Edit"]);

        let section = resolve_section(&after, 5, &path)
            .expect("resolve should walk")
            .expect("Edit still exists");
        assert_eq!(section.id, 50);

        let items = items_from(&section).expect("rows should decode");
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].label, "Undo");
    }

    #[test]
    fn a_stale_heading_announces_the_live_identifier() {
        let after = tree(
            0,
            "",
            vec![encoded(50, "Edit", vec![encoded(60, "Undo", Vec::new())])],
        );

        assert_eq!(
            destination(&after, 5, &["Edit".to_owned()]).expect("destination"),
            50
        );
        assert_eq!(
            destination(&after, 50, &["Edit".to_owned()]).expect("still live"),
            50
        );
    }

    #[test]
    fn a_stale_row_activates_at_the_live_identifier() {
        let after = tree(
            0,
            "",
            vec![encoded(
                50,
                "View",
                vec![encoded(60, "Actual Size", Vec::new())],
            )],
        );

        assert_eq!(
            destination(&after, 6, &["View".to_owned(), "Actual Size".to_owned()])
                .expect("destination"),
            60
        );
    }

    #[test]
    fn an_unlabeled_dbusmenu_placeholder_is_not_a_row() {
        let mut edit = node(5, &[("label", Value::from("Edit"))]);
        edit.children.push(
            OwnedValue::try_from(Value::from((
                7i32,
                HashMap::<String, Value<'_>>::new(),
                Vec::<OwnedValue>::new(),
            )))
            .expect("placeholder should encode"),
        );

        assert!(items_from(&edit).expect("rows should decode").is_empty());
    }

    #[test]
    fn a_nested_path_walks_into_a_submenu() {
        let root = tree(
            0,
            "",
            vec![encoded(
                1,
                "File",
                vec![encoded(
                    2,
                    "Recent",
                    vec![encoded(3, "notes.txt", Vec::new())],
                )],
            )],
        );

        let path = path_to(&root, 2)
            .expect("path should walk")
            .expect("Recent exists");
        assert_eq!(path, vec!["File", "Recent"]);
        let recent = at_path(&root, &path)
            .expect("walk should succeed")
            .expect("Recent exists");
        assert_eq!(recent.id, 2);
        assert_eq!(
            items_from(&recent).expect("rows should decode")[0].label,
            "notes.txt"
        );
    }

    #[test]
    fn a_dbusmenu_tree_caches_every_heading_and_its_rows() {
        let root = tree(
            0,
            "",
            vec![
                encoded(1, "File", vec![encoded(2, "New", Vec::new())]),
                encoded(3, "Edit", vec![encoded(4, "Undo", Vec::new())]),
            ],
        );

        let (menu, sections) = dbusmenu_tree(&root).expect("tree should walk");

        assert_eq!(
            menu.sections
                .iter()
                .map(|section| section.label.as_str())
                .collect::<Vec<_>>(),
            ["File", "Edit"]
        );
        assert_eq!(sections[&SectionId::DbusMenu { id: 1 }][0].label, "New");
        assert_eq!(sections[&SectionId::DbusMenu { id: 3 }][0].label, "Undo");
    }

    #[test]
    fn a_menubar_heading_is_a_labeled_submenu() {
        let root = tree(
            0,
            "",
            vec![
                encoded_submenu(1, "File"),
                encoded(2, "New Item", Vec::new()),
                encoded_separator(3),
                encoded_with(
                    4,
                    &[("children-display", Value::from("submenu"))],
                    Vec::new(),
                ),
            ],
        );

        let (menu, _) = dbusmenu_tree(&root).expect("tree should walk");

        assert_eq!(
            menu.sections
                .iter()
                .map(|section| section.label.as_str())
                .collect::<Vec<_>>(),
            ["File"]
        );
    }

    #[test]
    fn a_command_list_at_the_root_is_one_menu() {
        let root = tree(
            0,
            "",
            vec![
                encoded(1, "New Item", Vec::new()),
                encoded_separator(2),
                encoded(3, "Import…", Vec::new()),
                encoded_with(
                    4,
                    &[("children-display", Value::from("submenu"))],
                    Vec::new(),
                ),
                encoded(5, "Zoom", Vec::new()),
            ],
        );

        let (menu, sections) = dbusmenu_tree(&root).expect("tree should walk");

        assert_eq!(menu.sections.len(), 1);
        assert_eq!(menu.sections[0].id, SectionId::DbusMenu { id: 0 });
        assert!(menu.sections[0].label.is_empty());
        assert_eq!(
            sections[&SectionId::DbusMenu { id: 0 }]
                .iter()
                .map(|item| (item.label.as_str(), item.kind))
                .collect::<Vec<_>>(),
            [
                ("New Item", ItemKind::Standard),
                ("", ItemKind::Separator),
                ("Import…", ItemKind::Standard),
                ("Zoom", ItemKind::Standard),
            ]
        );
    }

    #[test]
    fn an_anonymous_list_takes_the_window_title() {
        let mut menu = Menu {
            sections: vec![super::Section {
                id: SectionId::DbusMenu { id: 0 },
                label: String::new(),
                enabled: true,
            }],
        };

        entitle_anonymous_list(&mut menu, "1Password".to_owned());

        assert_eq!(menu.sections[0].label, "1Password");
    }

    #[test]
    fn a_gtk_command_list_at_the_root_is_one_menu() {
        let groups = vec![GtkGroup {
            group: 0,
            menu: 0,
            items: vec![
                gtk_entry(&[("label", Value::from("New Item"))], None),
                gtk_entry(&[], None),
                gtk_entry(&[("label", Value::from("Import…"))], None),
            ],
        }];

        let (menu, sections) =
            gtk_tree(&groups, &gtk::Actions::default()).expect("tree should walk");

        assert_eq!(menu.sections.len(), 1);
        assert_eq!(menu.sections[0].id, SectionId::Gtk { group: 0, menu: 0 });
        assert_eq!(
            sections[&SectionId::Gtk { group: 0, menu: 0 }]
                .iter()
                .map(|item| item.label.as_str())
                .collect::<Vec<_>>(),
            ["New Item", "Import…"]
        );
    }

    #[test]
    fn a_gtk_menubar_still_uses_labeled_submenus() {
        let groups = vec![
            GtkGroup {
                group: 0,
                menu: 0,
                items: vec![
                    gtk_submenu("File", 0, 1),
                    gtk_entry(&[("label", Value::from("New Item"))], None),
                ],
            },
            GtkGroup {
                group: 0,
                menu: 1,
                items: vec![gtk_entry(&[("label", Value::from("New"))], None)],
            },
        ];

        let (menu, sections) =
            gtk_tree(&groups, &gtk::Actions::default()).expect("tree should walk");

        assert_eq!(
            menu.sections
                .iter()
                .map(|section| section.label.as_str())
                .collect::<Vec<_>>(),
            ["File"]
        );
        assert_eq!(
            sections[&SectionId::Gtk { group: 0, menu: 1 }][0].label,
            "New"
        );
    }

    #[test]
    fn a_gtk_app_menu_is_a_leading_heading_beside_the_menubar() {
        let menubar = vec![
            GtkGroup {
                group: 0,
                menu: 0,
                items: vec![gtk_submenu("File", 0, 1), gtk_submenu("Edit", 0, 2)],
            },
            GtkGroup {
                group: 0,
                menu: 1,
                items: vec![gtk_entry(&[("label", Value::from("New"))], None)],
            },
            GtkGroup {
                group: 0,
                menu: 2,
                items: vec![gtk_entry(&[("label", Value::from("Copy"))], None)],
            },
        ];
        let app_menu = vec![GtkGroup {
            group: 0,
            menu: 0,
            items: vec![
                gtk_entry(&[("label", Value::from("About"))], None),
                gtk_entry(&[("label", Value::from("Quit"))], None),
            ],
        }];

        let (headings, sections) =
            gtk_tree(&menubar, &gtk::Actions::default()).expect("menubar should walk");
        let (menu, sections) = prepend_gtk_app_menu(
            headings,
            sections,
            &app_menu,
            &gtk::Actions::default(),
            "Writer".to_owned(),
        )
        .expect("app menu should prepend");

        assert_eq!(
            menu.sections
                .iter()
                .map(|section| section.label.as_str())
                .collect::<Vec<_>>(),
            ["Writer", "File", "Edit"]
        );
        assert_eq!(
            menu.sections[0].id,
            SectionId::GtkAppMenu { group: 0, menu: 0 }
        );
        assert_eq!(menu.sections[1].id, SectionId::Gtk { group: 0, menu: 1 });
        assert_eq!(
            sections[&SectionId::GtkAppMenu { group: 0, menu: 0 }]
                .iter()
                .map(|item| item.label.as_str())
                .collect::<Vec<_>>(),
            ["About", "Quit"]
        );
        assert_eq!(
            sections[&SectionId::Gtk { group: 0, menu: 1 }][0].label,
            "New"
        );
    }

    #[test]
    fn an_app_menu_row_keeps_app_menu_section_ids() {
        let row = gtk::item(&gtk_submenu("About", 0, 1), &gtk::Actions::default(), true);

        assert_eq!(
            row.submenu,
            Some(SectionId::GtkAppMenu { group: 0, menu: 1 })
        );
    }

    #[test]
    fn a_gtk_submenu_in_another_group_is_fetched_next() {
        let groups = vec![GtkGroup {
            group: 0,
            menu: 0,
            items: vec![gtk_submenu("File", 1, 0), gtk_submenu("Edit", 2, 0)],
        }];

        let extra = gtk_unfetched_groups(&groups, &HashSet::from([0]));
        let mut extra = extra;
        extra.sort_unstable();
        assert_eq!(extra, [1, 2]);
    }

    #[test]
    fn a_gtk_menubar_in_another_group_still_names_file() {
        let groups = vec![
            GtkGroup {
                group: 0,
                menu: 0,
                items: vec![gtk_submenu("File", 1, 0), gtk_submenu("Edit", 2, 0)],
            },
            GtkGroup {
                group: 1,
                menu: 0,
                items: vec![gtk_entry(&[("label", Value::from("New"))], None)],
            },
            GtkGroup {
                group: 2,
                menu: 0,
                items: vec![gtk_entry(&[("label", Value::from("Undo"))], None)],
            },
        ];

        let (menu, _) = gtk_tree(&groups, &gtk::Actions::default()).expect("tree should walk");
        assert_eq!(
            menu.sections
                .iter()
                .map(|section| section.label.as_str())
                .collect::<Vec<_>>(),
            ["File", "Edit"]
        );
    }

    #[test]
    fn a_gtk_sectioned_menubar_still_names_file() {
        let groups = vec![
            GtkGroup {
                group: 0,
                menu: 0,
                items: vec![gtk_entry(&[], Some((0, 1))), gtk_entry(&[], Some((0, 2)))],
            },
            GtkGroup {
                group: 0,
                menu: 2,
                items: vec![gtk_entry(&[], Some((0, 3)))],
            },
            GtkGroup {
                group: 0,
                menu: 3,
                items: vec![gtk_submenu("File", 0, 4), gtk_submenu("Edit", 0, 5)],
            },
            GtkGroup {
                group: 0,
                menu: 4,
                items: vec![gtk_entry(&[("label", Value::from("New"))], None)],
            },
            GtkGroup {
                group: 0,
                menu: 5,
                items: vec![gtk_entry(&[("label", Value::from("Undo"))], None)],
            },
        ];

        let (menu, _) = gtk_tree(&groups, &gtk::Actions::default()).expect("tree should walk");
        assert_eq!(
            menu.sections
                .iter()
                .map(|section| section.label.as_str())
                .collect::<Vec<_>>(),
            ["File", "Edit"]
        );
    }
}

/// Where the compositor half of the global menu got to.
///
/// Installation is slow and can end somewhere only the user can take further,
/// so the outcome is a reportable state rather than a silent failure.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Progress {
    /// The module is switched off.
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

impl Progress {
    /// Reports an installation that could not run to a conclusion.
    pub fn failed(error: &plugin::Error) -> Self {
        Self::Blocked {
            message: error.to_string(),
            instruction: None,
        }
    }
}

impl From<Readiness> for Progress {
    fn from(readiness: Readiness) -> Self {
        match readiness {
            Readiness::Ready => Self::Ready,
            Readiness::Blocked(blocker) => Self::Blocked {
                message: blocker.message(),
                instruction: blocker.instruction(),
            },
        }
    }
}
