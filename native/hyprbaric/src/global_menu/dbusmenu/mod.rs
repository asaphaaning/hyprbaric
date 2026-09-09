//! D-BusMenu transport: open/close events, lazy layouts, and activation.
pub(super) mod tree;
use super::{Error, Item, ItemId, SectionId, endpoint::Endpoint, live, popup::Opened};
use futures_util::StreamExt;
use serde::Deserialize;
use std::{
    collections::HashMap,
    time::{Duration, SystemTime, UNIX_EPOCH},
};
use tracing::instrument;
pub(super) use tree::{
    dbusmenu_tree, destination, find_by_id, items_from, path_to, resolve_section,
};
use zbus::{
    proxy,
    zvariant::{OwnedValue, Type, Value},
};
pub(in crate::global_menu) async fn dbusmenu<'a>(
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
pub(in crate::global_menu) const DBUSMENU_DEPTH: i32 = 4;

/// How long to wait for an application to fill a menu it has just been told
/// is opening. Firefox runs `popupshowing` on the Gecko thread and then
/// rebuilds the native tree; Qt usually returns the rows with `AboutToShow`.
pub(in crate::global_menu) const DBUSMENU_RELAYOUT: Duration = Duration::from_millis(400);

/// Reads one D-BusMenu subtree, announcing the open first.
///
/// Qt fills a menu's rows in response to `AboutToShow`. Firefox also listens
/// for the `opened` event, and its `AboutToShow` handler mutates the XUL DOM
/// which then *rebuilds the whole native tree under new identifiers*. The next
/// click still carries the id from the last heading read, which is no longer
/// in the tree: `GetLayout` for that id is empty, and `AboutToShow` on it is
/// ignored. [known_path] is the heading (and submenu) labels from that last
/// read, which is the address that survives the rebuild.
pub(in crate::global_menu) async fn dbusmenu_items(
    state: &live::State,
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
    state.remember_opened(
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
pub(in crate::global_menu) async fn dbusmenu_activate(
    state: &live::State,
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
        .unwrap_or_else(|| state.item_path(id));
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
    let items = dbusmenu_items(state, connection, endpoint, parent, parent_path).await?;
    let dest = activation_id(&items, label).unwrap_or(dest);

    dbusmenu_event(&proxy, dest, DbusMenuEvent::Clicked)
        .await
        .map_err(Error::Activate)
}

/// D-BusMenu `Event` names. `opened` and `closed` are only valid on items
/// that contain a submenu, which is every heading and flyout we announce.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(in crate::global_menu) enum DbusMenuEvent {
    Opened,
    Closed,
    Clicked,
}

impl DbusMenuEvent {
    pub(in crate::global_menu) fn as_str(self) -> &'static str {
        match self {
            Self::Opened => "opened",
            Self::Closed => "closed",
            Self::Clicked => "clicked",
        }
    }
}

pub(in crate::global_menu) async fn dbusmenu_event(
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
pub(in crate::global_menu) async fn dbusmenu_closed(
    state: &live::State,
    id: i32,
) -> Result<(), Error> {
    let path = state.dismiss_path(id);
    let opened = state.take_opened(id, &path);
    if opened.is_empty() {
        return Ok(());
    }

    for menu in opened {
        if let Err(error) = dbusmenu_closed_announced(menu).await {
            tracing::debug!(%error, "Menu declined the closed event");
        }
    }

    Ok(())
}

pub(in crate::global_menu) async fn dbusmenu_closed_announced(opened: Opened) -> Result<(), Error> {
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

/// Closes every D-BusMenu still announced against an exporter that went away.
#[instrument(name = "hyprbaric::global_menu::close_opened", skip_all)]
pub(in crate::global_menu) async fn close_opened(opened: Vec<Opened>) {
    for menu in opened {
        if let Err(error) = dbusmenu_closed_announced(menu).await {
            tracing::debug!(%error, "Could not close a menu after its window left");
        }
    }
}

pub(in crate::global_menu) fn activation_id(items: &[Item], label: &str) -> Option<i32> {
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

pub(in crate::global_menu) async fn dbusmenu_section(
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
pub(in crate::global_menu) async fn dbusmenu_live_items(
    connection: &zbus::Connection,
    endpoint: &Endpoint,
    id: i32,
    path: &[String],
) -> Result<Vec<Item>, Error> {
    let proxy = dbusmenu(connection, endpoint).await?;
    dbusmenu_section(&proxy, id, path).await
}

pub(in crate::global_menu) fn timestamp() -> u32 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|elapsed| elapsed.as_secs() as u32)
        .unwrap_or_default()
}

#[proxy(interface = "com.canonical.dbusmenu", assume_defaults = true)]
pub(in crate::global_menu) trait DBusMenu {
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

#[derive(Deserialize, Type)]
pub(in crate::global_menu) struct Layout {
    #[allow(dead_code)]
    pub(in crate::global_menu) revision: u32,
    pub(in crate::global_menu) root: Node,
}

#[derive(Clone, Deserialize, Type)]
pub(in crate::global_menu) struct Node {
    pub(in crate::global_menu) id: i32,
    pub(in crate::global_menu) properties: HashMap<String, OwnedValue>,
    pub(in crate::global_menu) children: Vec<OwnedValue>,
}

pub(in crate::global_menu) mod watch;
