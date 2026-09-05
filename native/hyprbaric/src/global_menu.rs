//! Focused-application menu reader.
//!
//! The compositor companion owns the Wayland-specific association. This module
//! reads its typed JSON projection, selects the focused window's endpoint, and
//! converts the D-BusMenu and GTK menu boundaries into one menu-bar vocabulary.
//!
//! Reads are deliberately shallow. Qt populates a menu's rows only once
//! something signals it is about to be shown, so a section read before then
//! reports placeholder separators rather than its real contents. Headings load
//! with the bar, rows load when a heading opens, which is both what the
//! protocol wants and what a menu bar needs.

mod plugin;
mod registrar;

pub use plugin::Configuration;
pub use registrar::Registrar;

use std::{
    collections::HashMap,
    env,
    process::Stdio,
    time::{SystemTime, UNIX_EPOCH},
};

use hyprland::{data::Client, prelude::HyprDataActiveOptional};
use serde::Deserialize;
use tokio::process::Command;
use tracing::instrument;
use zbus::{
    proxy,
    zvariant::{OwnedValue, Structure, Type, Value},
};

/// Loads the configured compositor companion before any menu is read.
#[instrument(name = "hyprbaric::global_menu::plugin::load", err)]
pub async fn load_companion(configuration: &Configuration) -> Result<(), plugin::Error> {
    plugin::load(configuration).await
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
    /// A checkable row and its current state.
    Checkmark { checked: bool },
    /// One option of a mutually exclusive group.
    Radio { selected: bool },
}

/// Addresses a menu whose rows can be read.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SectionId {
    /// A D-BusMenu subtree, addressed by item identifier.
    DbusMenu { id: i32 },
    /// A GTK menu, addressed by the group and menu it lives in.
    Gtk { group: u32, menu: u32 },
}

/// Addresses a row that can be activated.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ItemId {
    /// A D-BusMenu row, addressed by item identifier.
    DbusMenu { id: i32 },
    /// A GTK action, named with its `app.` or `win.` scope.
    Gtk { action: String },
}

/// Reads the headings the focused application currently exports.
#[instrument(name = "hyprbaric::global_menu::read", err)]
pub async fn read() -> Result<Menu, Error> {
    let (connection, endpoint) = focused().await?;

    match endpoint.kind {
        EndpointKind::DbusMenu => read_dbusmenu(&connection, &endpoint).await,
        EndpointKind::Gtk => read_gtk(&connection, &endpoint).await,
    }
}

/// Reads the rows beneath one heading of the focused application.
#[instrument(name = "hyprbaric::global_menu::section", err)]
pub async fn section(id: &SectionId) -> Result<Vec<Item>, Error> {
    let (connection, endpoint) = focused().await?;

    match id {
        SectionId::DbusMenu { id } => dbusmenu_items(&connection, &endpoint, *id).await,
        SectionId::Gtk { group, menu } => gtk_items(&connection, &endpoint, *group, *menu).await,
    }
}

/// Activates one row of the focused application's menu.
#[instrument(name = "hyprbaric::global_menu::activate", err)]
pub async fn activate(id: &ItemId) -> Result<(), Error> {
    let (connection, endpoint) = focused().await?;

    match id {
        ItemId::DbusMenu { id } => {
            let proxy = dbusmenu(&connection, &endpoint).await?;
            proxy
                .event(*id, "clicked", &Value::I32(0), timestamp())
                .await
                .map_err(Error::Activate)
        }
        ItemId::Gtk { action } => gtk_activate(&connection, &endpoint, action).await,
    }
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
        .destination(endpoint.service.clone())
        .map_err(Error::CreateProxy)?
        .path(endpoint.path.clone())
        .map_err(Error::CreateProxy)?
        .build()
        .await
        .map_err(Error::CreateProxy)
}

async fn read_dbusmenu(connection: &zbus::Connection, endpoint: &Endpoint) -> Result<Menu, Error> {
    let proxy = dbusmenu(connection, endpoint).await?;
    let layout = proxy.get_layout(0, 1, &[]).await.map_err(Error::Layout)?;

    let sections = layout
        .root
        .children
        .iter()
        .map(Node::try_from)
        .collect::<Result<Vec<_>, _>>()?
        .into_iter()
        .filter(Node::visible)
        .map(|node| Section {
            id: SectionId::DbusMenu { id: node.id },
            label: node.label(),
            enabled: node.enabled(),
        })
        .collect();

    Ok(Menu { sections })
}

/// Reads one D-BusMenu subtree, announcing the open first.
///
/// Qt fills a menu's rows in response to `AboutToShow` and not before, so a
/// section read without it reports the placeholder separators it was built
/// with. A refusal is not fatal: some applications answer only that no
/// relayout was needed, and their rows are already correct.
async fn dbusmenu_items(
    connection: &zbus::Connection,
    endpoint: &Endpoint,
    id: i32,
) -> Result<Vec<Item>, Error> {
    let proxy = dbusmenu(connection, endpoint).await?;
    if let Err(error) = proxy.about_to_show(id).await {
        tracing::debug!(%error, id, "Menu declined to announce that it was opening");
    }

    let layout = proxy.get_layout(id, 1, &[]).await.map_err(Error::Layout)?;

    Ok(layout
        .root
        .children
        .iter()
        .map(Node::try_from)
        .collect::<Result<Vec<_>, _>>()?
        .into_iter()
        .filter(Node::visible)
        .map(Item::from)
        .collect())
}

async fn read_gtk(connection: &zbus::Connection, endpoint: &Endpoint) -> Result<Menu, Error> {
    let proxy = gtk_menus(connection, endpoint).await?;
    let groups = proxy.start(&[0]).await.map_err(Error::GtkLayout)?;
    let root = gtk_group(&groups, GtkLink::ROOT)?;

    let sections = root
        .items
        .iter()
        .filter_map(|item| {
            let link = gtk_link(item, ":submenu")?;
            Some(Section {
                id: SectionId::Gtk {
                    group: link.group,
                    menu: link.menu,
                },
                label: gtk_label(item),
                enabled: true,
            })
        })
        .collect();

    proxy.end(&[0]).await.map_err(Error::GtkLayout)?;

    Ok(Menu { sections })
}

async fn gtk_items(
    connection: &zbus::Connection,
    endpoint: &Endpoint,
    group: u32,
    menu: u32,
) -> Result<Vec<Item>, Error> {
    let proxy = gtk_menus(connection, endpoint).await?;
    let groups = proxy.start(&[group]).await.map_err(Error::GtkLayout)?;
    let items = gtk_group(&groups, GtkLink { group, menu })?
        .items
        .iter()
        .map(gtk_item)
        .collect();

    proxy.end(&[group]).await.map_err(Error::GtkLayout)?;

    Ok(items)
}

async fn gtk_menus<'a>(
    connection: &zbus::Connection,
    endpoint: &Endpoint,
) -> Result<GtkMenusProxy<'a>, Error> {
    GtkMenusProxy::builder(connection)
        .destination(endpoint.service.clone())
        .map_err(Error::CreateGtkProxy)?
        .path(endpoint.path.clone())
        .map_err(Error::CreateGtkProxy)?
        .build()
        .await
        .map_err(Error::CreateGtkProxy)
}

/// Activates a GTK action on whichever object group owns its scope.
///
/// GTK splits its actions between the application and the window, and the
/// prefix on the action name says which one to ask.
async fn gtk_activate(
    connection: &zbus::Connection,
    endpoint: &Endpoint,
    action: &str,
) -> Result<(), Error> {
    let (scope, name) = action
        .split_once('.')
        .ok_or_else(|| Error::UnscopedGtkAction {
            action: action.to_owned(),
        })?;
    let path = match scope {
        "app" => endpoint.application_path.as_deref(),
        "win" => endpoint.window_path.as_deref(),
        _ => None,
    }
    .ok_or_else(|| Error::UnscopedGtkAction {
        action: action.to_owned(),
    })?;

    let proxy = GtkActionsProxy::builder(connection)
        .destination(endpoint.service.clone())
        .map_err(Error::CreateGtkProxy)?
        .path(path.to_owned())
        .map_err(Error::CreateGtkProxy)?
        .build()
        .await
        .map_err(Error::CreateGtkProxy)?;

    proxy
        .activate(name, &[], HashMap::new())
        .await
        .map_err(Error::Activate)
}

async fn focused_endpoint() -> Result<Endpoint, Error> {
    let address = Client::get_active_async()
        .await
        .map_err(Error::FocusedWindow)?
        .ok_or(Error::NoFocusedWindow)?
        .address
        .to_string();
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

    let endpoints: Vec<Endpoint> =
        serde_json::from_slice(&output.stdout).map_err(Error::DecodeEndpoints)?;
    endpoints
        .into_iter()
        .find(|endpoint| endpoint.address.as_deref() == Some(address.as_str()))
        .ok_or(Error::NoMenuForFocusedWindow)
}

impl Item {
    fn from(node: Node) -> Self {
        let separator = node.kind() == Some("separator");
        let submenu = (node.property("children-display") == Some("submenu"))
            .then_some(SectionId::DbusMenu { id: node.id });

        Self {
            label: node.label(),
            enabled: node.enabled(),
            kind: node.item_kind(),
            shortcut: node.shortcut(),
            activation: (!separator && submenu.is_none())
                .then_some(ItemId::DbusMenu { id: node.id }),
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

    fn label(&self) -> String {
        self.property("label")
            .map(strip_mnemonics)
            .filter(|label| !label.is_empty())
            .unwrap_or_else(|| "Untitled".to_owned())
    }

    fn enabled(&self) -> bool {
        self.flag("enabled").unwrap_or(true)
    }

    fn kind(&self) -> Option<&str> {
        self.property("type")
    }

    fn visible(&self) -> bool {
        self.flag("visible").unwrap_or(true)
    }

    fn item_kind(&self) -> ItemKind {
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

fn gtk_item(item: &HashMap<String, OwnedValue>) -> Item {
    let submenu = gtk_link(item, ":submenu").map(|link| SectionId::Gtk {
        group: link.group,
        menu: link.menu,
    });
    let action = item
        .get("action")
        .and_then(|value| value.downcast_ref::<&str>().ok())
        .map(|action| ItemId::Gtk {
            action: action.to_owned(),
        });

    Item {
        label: gtk_label(item),
        // GTK reports availability through its action group rather than the
        // menu, which this does not subscribe to; rows read as available.
        enabled: true,
        kind: ItemKind::Standard,
        shortcut: None,
        activation: action,
        submenu,
    }
}

fn gtk_label(item: &HashMap<String, OwnedValue>) -> String {
    item.get("label")
        .and_then(|value| value.downcast_ref::<&str>().ok())
        .map(strip_mnemonics)
        .filter(|label| !label.is_empty())
        .unwrap_or_else(|| "Untitled".to_owned())
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
}

#[proxy(interface = "org.gtk.Menus", assume_defaults = true)]
trait GtkMenus {
    fn start(&self, groups: &[u32]) -> zbus::Result<Vec<GtkGroup>>;

    fn end(&self, groups: &[u32]) -> zbus::Result<()>;
}

#[proxy(interface = "org.gtk.Actions", assume_defaults = true)]
trait GtkActions {
    fn activate(
        &self,
        action: &str,
        parameter: &[Value<'_>],
        platform_data: HashMap<&str, Value<'_>>,
    ) -> zbus::Result<()>;
}

#[derive(Deserialize, Type)]
struct Layout {
    #[allow(dead_code)]
    revision: u32,
    root: Node,
}

#[derive(Deserialize, Type)]
struct Node {
    id: i32,
    properties: HashMap<String, OwnedValue>,
    children: Vec<OwnedValue>,
}

#[derive(Deserialize, Type)]
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

#[derive(Debug, Deserialize)]
struct Endpoint {
    #[serde(default)]
    kind: EndpointKind,
    address: Option<String>,
    service: String,
    path: String,
    /// GTK only: where `app.` actions live.
    #[serde(default)]
    application_path: Option<String>,
    /// GTK only: where `win.` actions live.
    #[serde(default)]
    window_path: Option<String>,
}

#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "lowercase")]
enum EndpointKind {
    #[default]
    DbusMenu,
    Gtk,
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
    #[error("the application refused the activation")]
    Activate(#[source] zbus::Error),
    #[error("the D-BusMenu layout used an unsupported value")]
    DecodeLayout(#[source] zbus::zvariant::Error),
    #[error("the D-BusMenu layout contained an invalid item")]
    InvalidNode,
}

#[cfg(test)]
mod tests {
    use std::collections::HashMap;

    use zbus::zvariant::{OwnedValue, Value};

    use super::{Item, ItemId, ItemKind, Node, SectionId, strip_mnemonics};

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
    fn a_row_without_a_label_is_named_rather_than_blank() {
        assert_eq!(node(1, &[]).label(), "Untitled");
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
    fn a_separator_neither_activates_nor_opens() {
        let item = Item::from(node(4, &[("type", Value::from("separator"))]));

        assert_eq!(item.kind, ItemKind::Separator);
        assert_eq!(item.activation, None);
        assert_eq!(item.submenu, None);
    }
}
