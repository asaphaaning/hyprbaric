//! StatusNotifier watcher boundary.

use std::sync::{Arc, Mutex, MutexGuard};

use system_tray::{
    client::{Client, Event},
    data::BaseMap,
    item::{Status as NotifierStatus, StatusNotifierItem, Tooltip},
    menu::{self as dbus_menu, TrayMenu},
};
use tokio::sync::broadcast;
use tracing::instrument;

use super::{
    Menu, MenuItem, MenuItemId, MenuItemKind, Position, Snapshot,
    domain::{Item, ItemId, Order, OrderEvent, Status},
    icons, replace_snapshot,
};

pub(super) type ClientHandle = Arc<Client>;

/// Connects to the system-tray client.
#[instrument(skip_all, err)]
pub(super) async fn connect() -> Result<ClientHandle, super::Error> {
    Client::new()
        .await
        .map(Arc::new)
        .map_err(super::Error::Watcher)
}

/// Reads the initial display order from the current item registry.
fn initial_order(client: &ClientHandle) -> Order {
    let items = client.items();
    let lock = lock_items(&items);
    Order::sorted(lock.keys().cloned().map(ItemId::new).collect())
}

/// Builds a snapshot from the current item registry.
fn snapshot(client: &ClientHandle, order: &Order, icons: &mut icons::Index) -> Snapshot {
    snapshot_from_items(&client.items(), order, icons)
}

/// Starts forwarding tray item changes into snapshots.
#[instrument(skip_all)]
pub(super) fn spawn(
    events: broadcast::Sender<Snapshot>,
    client: ClientHandle,
    mut icons: icons::Index,
    latest: Arc<Mutex<Snapshot>>,
) -> Snapshot {
    let mut receiver = client.subscribe();
    let mut order = initial_order(&client);
    let initial_snapshot = snapshot(&client, &order, &mut icons);
    replace_snapshot(&latest, initial_snapshot.clone());
    debug_snapshot("initial", &initial_snapshot);
    let task_snapshot = initial_snapshot.clone();

    tokio::spawn(async move {
        let items = client.items();
        let mut previous = task_snapshot;

        loop {
            let event = match receiver.recv().await {
                Ok(event) => event,
                Err(tokio::sync::broadcast::error::RecvError::Lagged(skipped)) => {
                    tracing::warn!("Tray listener lagged by {skipped} events");
                    rebuild_order(&mut order, &items);
                    let snapshot = snapshot_from_items(&items, &order, &mut icons);
                    if snapshot != previous {
                        replace_snapshot(&latest, snapshot.clone());
                        debug_snapshot("lagged", &snapshot);
                        drop(events.send(snapshot.clone()));
                        previous = snapshot;
                    }
                    continue;
                }
                Err(tokio::sync::broadcast::error::RecvError::Closed) => return,
            };

            order.apply(order_event(&event));
            let snapshot = snapshot_from_items(&items, &order, &mut icons);
            if snapshot != previous {
                replace_snapshot(&latest, snapshot.clone());
                debug_snapshot("changed", &snapshot);
                drop(events.send(snapshot.clone()));
                previous = snapshot;
            }
        }
    });

    initial_snapshot
}

fn debug_snapshot(label: &str, snapshot: &Snapshot) {
    tracing::debug!(
        item_count = snapshot.items.len(),
        items = ?snapshot
            .items
            .iter()
            .map(|item| (item.id.as_str(), item.title.as_str(), item.status))
            .collect::<Vec<_>>(),
        "Tray snapshot {label}"
    );
}

pub(super) fn item_is_menu(client: &ClientHandle, address: &str) -> bool {
    let items = client.items();
    let lock = lock_items(&items);
    lock.get(address)
        .map(|(item, _)| item.item_is_menu)
        .unwrap_or(false)
}

pub(super) fn menu(client: &ClientHandle, address: &str, position: Position) -> Option<Menu> {
    let destination = destination(address);
    let items = client.items();
    let lock = lock_items(&items);
    let (_, menu) = lock.get(destination)?;
    let menu = menu.as_ref()?;
    Some(project_menu(address, position, menu))
}

pub(super) fn menu_path(client: &ClientHandle, address: &str) -> Option<String> {
    let destination = destination(address);
    let items = client.items();
    let lock = lock_items(&items);
    lock.get(destination)
        .and_then(|(item, _)| item.menu.as_ref())
        .cloned()
}

fn destination(address: &str) -> &str {
    address
        .split_once('/')
        .map_or(address, |(destination, _)| destination)
}

fn project_menu(address: &str, position: Position, menu: &TrayMenu) -> Menu {
    let mut items = Vec::new();
    for item in &menu.submenus {
        push_menu_item(&mut items, item, 0);
    }
    Menu {
        item_id: ItemId::new(address),
        position,
        items,
    }
}

fn push_menu_item(items: &mut Vec<MenuItem>, item: &dbus_menu::MenuItem, depth: u8) {
    if !item.visible {
        return;
    }

    let kind = match item.menu_type {
        dbus_menu::MenuType::Separator => MenuItemKind::Separator,
        dbus_menu::MenuType::Standard => MenuItemKind::Standard,
    };
    let label = item
        .label
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .unwrap_or(if kind == MenuItemKind::Separator {
            ""
        } else {
            "Untitled"
        });

    items.push(MenuItem {
        id: MenuItemId::new(item.id),
        label: label.to_string(),
        enabled: item.enabled,
        kind,
        depth,
    });

    for child in &item.submenu {
        push_menu_item(items, child, depth.saturating_add(1));
    }
}

fn rebuild_order(order: &mut Order, items: &Arc<Mutex<BaseMap>>) {
    let lock = lock_items(items);
    order.sync(lock.keys().cloned().map(ItemId::new).collect());
}

fn order_event(event: &Event) -> OrderEvent {
    match event {
        Event::Add(address, _) => OrderEvent::Add(ItemId::new(address)),
        Event::Remove(address) => OrderEvent::Remove(ItemId::new(address)),
        Event::Update(_, _) => OrderEvent::Update,
    }
}

fn snapshot_from_items(
    items: &Arc<Mutex<BaseMap>>,
    order: &Order,
    icons: &mut icons::Index,
) -> Snapshot {
    let lock = lock_items(items);
    let mut seen = std::collections::HashSet::new();
    let mut ordered = Vec::new();

    for id in order.as_slice() {
        if let Some((item, _)) = lock.get(id.as_str()) {
            ordered.push(normalize_item(id.as_str(), item, icons));
            seen.insert(id.clone());
        }
    }

    let mut remaining = lock
        .iter()
        .filter(|(address, _)| !seen.contains(&ItemId::new(address.as_str())))
        .map(|(address, (item, _))| normalize_item(address, item, icons))
        .collect::<Vec<_>>();
    remaining.sort_by(|left, right| left.id.as_str().cmp(right.id.as_str()));
    ordered.extend(remaining);
    icons.retain(|address| lock.contains_key(address));

    Snapshot {
        items: ordered,
        message: None,
    }
}

fn lock_items(items: &Arc<Mutex<BaseMap>>) -> MutexGuard<'_, BaseMap> {
    match items.lock() {
        Ok(lock) => lock,
        Err(poisoned) => {
            tracing::warn!("Tray item registry lock was poisoned; recovering current state");
            poisoned.into_inner()
        }
    }
}

fn normalize_item(address: &str, item: &StatusNotifierItem, icons: &mut icons::Index) -> Item {
    Item {
        id: item_id(address, item),
        title: display_title(item),
        description: display_description(item.tool_tip.as_ref()),
        status: status(item.status),
        icon: icons::resolve(address, item, icons),
    }
}

fn item_id(address: &str, item: &StatusNotifierItem) -> ItemId {
    let path = item
        .menu
        .as_deref()
        .and_then(|menu| menu.strip_suffix("/Menu"))
        .filter(|path| path.starts_with('/'))
        .filter(|path| *path != "/StatusNotifierItem");

    match path {
        Some(path) => ItemId::new(format!("{address}{path}")),
        None => ItemId::new(address),
    }
}

fn display_title(item: &StatusNotifierItem) -> String {
    item.tool_tip
        .as_ref()
        .map(|tooltip| tooltip.title.trim())
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned)
        .or_else(|| {
            item.title
                .as_deref()
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(ToOwned::to_owned)
        })
        .unwrap_or_else(|| item.id.clone())
}

fn display_description(tooltip: Option<&Tooltip>) -> Option<String> {
    tooltip
        .map(|value| value.description.trim())
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned)
}

fn status(value: NotifierStatus) -> Status {
    match value {
        NotifierStatus::Passive => Status::Passive,
        NotifierStatus::Active => Status::Active,
        NotifierStatus::NeedsAttention => Status::NeedsAttention,
        NotifierStatus::Unknown => Status::Unknown,
    }
}

#[cfg(test)]
mod tests {
    use system_tray::item::{Status as NotifierStatus, StatusNotifierItem, Tooltip};

    use super::{display_title, item_id};

    #[test]
    fn title_prefers_tooltip_title_then_item_title_then_id() {
        let tooltip_title = display_title(&item(
            Some("Item Title"),
            Some(Tooltip {
                icon_name: String::new(),
                icon_data: Vec::new(),
                title: " Tooltip ".to_string(),
                description: String::new(),
            }),
        ));
        assert_eq!(tooltip_title, "Tooltip");

        let item_title = display_title(&item(Some(" Item Title "), None));
        assert_eq!(item_title, "Item Title");

        let fallback = display_title(&item(None, None));
        assert_eq!(fallback, "example-item");
    }

    #[test]
    fn item_id_preserves_non_default_appindicator_path() {
        let mut item = item(Some("Solaar"), None);
        item.menu = Some("/org/ayatana/NotificationItem/indicator_solaar/Menu".to_string());

        assert_eq!(
            item_id(":1.42", &item).as_str(),
            ":1.42/org/ayatana/NotificationItem/indicator_solaar"
        );
    }

    #[test]
    fn item_id_keeps_destination_for_default_status_notifier_path() {
        let mut item = item(Some("Default"), None);
        item.menu = Some("/StatusNotifierItem/Menu".to_string());

        assert_eq!(item_id(":1.42", &item).as_str(), ":1.42");
    }

    fn item(title: Option<&str>, tool_tip: Option<Tooltip>) -> StatusNotifierItem {
        StatusNotifierItem {
            id: "example-item".to_string(),
            category: Default::default(),
            title: title.map(ToOwned::to_owned),
            status: NotifierStatus::Active,
            window_id: 0,
            icon_theme_path: None,
            icon_name: None,
            icon_pixmap: None,
            overlay_icon_name: None,
            overlay_icon_pixmap: None,
            attention_icon_name: None,
            attention_icon_pixmap: None,
            attention_movie_name: None,
            tool_tip,
            item_is_menu: false,
            menu: None,
        }
    }
}
