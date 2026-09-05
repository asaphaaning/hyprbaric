//! Focused-application D-BusMenu reader.
//!
//! The compositor companion owns the Wayland-specific association. This module
//! reads its typed JSON projection, selects the focused window's endpoint, and
//! converts the D-BusMenu boundary into the compact menu-bar vocabulary used by
//! Flutter.

mod plugin;
mod registrar;

pub use plugin::Configuration;
pub use registrar::Registrar;

use std::{collections::HashMap, env, process::Stdio};

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

/// The visible root menu for the focused application.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Menu {
    /// Top-level menu headings, in application-defined order.
    pub sections: Vec<Section>,
}

/// A top-level heading and the entries it exposes.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Section {
    /// D-BusMenu item identifier.
    pub id: i32,
    /// User-visible heading.
    pub label: String,
    /// Whether the heading can be opened.
    pub enabled: bool,
    /// Direct child entries, suitable for a compact first proof surface.
    pub items: Vec<Item>,
}

/// One D-BusMenu row.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Item {
    /// D-BusMenu item identifier.
    pub id: i32,
    /// User-visible text.
    pub label: String,
    /// Whether the application currently allows activation.
    pub enabled: bool,
    /// Whether this row is a separator.
    pub separator: bool,
}

/// Reads the focused application's currently exported menu.
#[instrument(name = "hyprbaric::global_menu::read", err)]
pub async fn read() -> Result<Menu, Error> {
    let endpoint = focused_endpoint().await?;
    let connection = zbus::Connection::session().await.map_err(Error::Connect)?;

    match endpoint.kind {
        EndpointKind::DbusMenu => read_dbusmenu(&connection, &endpoint).await,
        EndpointKind::Gtk => read_gtk(&connection, &endpoint).await,
    }
}

async fn read_dbusmenu(connection: &zbus::Connection, endpoint: &Endpoint) -> Result<Menu, Error> {
    let proxy = DBusMenuProxy::builder(&connection)
        .destination(endpoint.service.as_str())
        .map_err(Error::CreateProxy)?
        .path(endpoint.path.as_str())
        .map_err(Error::CreateProxy)?
        .build()
        .await
        .map_err(Error::CreateProxy)?;
    let layout = proxy.get_layout(0, -1, &[]).await.map_err(Error::Layout)?;

    menu(layout.root)
}

async fn read_gtk(connection: &zbus::Connection, endpoint: &Endpoint) -> Result<Menu, Error> {
    let proxy = GtkMenusProxy::builder(connection)
        .destination(endpoint.service.as_str())
        .map_err(Error::CreateGtkProxy)?
        .path(endpoint.path.as_str())
        .map_err(Error::CreateGtkProxy)?
        .build()
        .await
        .map_err(Error::CreateGtkProxy)?;
    let groups = proxy.start(&[0]).await.map_err(Error::GtkLayout)?;
    let root = gtk_group(&groups, GtkLink::ROOT)?;

    let mut sections = Vec::new();
    for (index, item) in root.items.iter().enumerate() {
        let Some(link) = gtk_link(item, ":submenu") else {
            continue;
        };

        let groups = proxy.start(&[link.group]).await.map_err(Error::GtkLayout)?;
        let menu = gtk_group(&groups, link)?;
        sections.push(Section {
            id: index as i32,
            label: gtk_label(item),
            enabled: true,
            items: gtk_items(menu),
        });
    }

    proxy.end(&[0]).await.map_err(Error::GtkLayout)?;

    Ok(Menu { sections })
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

fn menu(root: Node) -> Result<Menu, Error> {
    let nodes = root
        .children
        .iter()
        .map(Node::try_from)
        .collect::<Result<Vec<_>, _>>()?;

    let sections = nodes
        .into_iter()
        .filter(Node::visible)
        .map(section)
        .collect::<Result<Vec<_>, _>>()?;

    Ok(Menu { sections })
}

fn section(node: Node) -> Result<Section, Error> {
    Ok(Section {
        id: node.id,
        label: node.label(),
        enabled: node.enabled(),
        items: node
            .children
            .iter()
            .map(Node::try_from)
            .collect::<Result<Vec<_>, _>>()?
            .into_iter()
            .filter(Node::visible)
            .map(Item::from)
            .collect(),
    })
}

impl Item {
    fn from(node: Node) -> Self {
        Self {
            id: node.id,
            label: node.label(),
            enabled: node.enabled(),
            separator: node.kind() == Some("separator"),
        }
    }
}

impl Node {
    fn label(&self) -> String {
        self.properties
            .get("label")
            .and_then(|value| value.downcast_ref::<&str>().ok())
            .map(strip_mnemonics)
            .filter(|label| !label.is_empty())
            .unwrap_or_else(|| "Untitled".to_owned())
    }

    fn enabled(&self) -> bool {
        self.properties
            .get("enabled")
            .and_then(|value| value.downcast_ref::<bool>().ok())
            .unwrap_or(true)
    }

    fn kind(&self) -> Option<&str> {
        self.properties
            .get("type")
            .and_then(|value| value.downcast_ref::<&str>().ok())
    }

    fn visible(&self) -> bool {
        self.properties
            .get("visible")
            .and_then(|value| value.downcast_ref::<bool>().ok())
            .unwrap_or(true)
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

fn gtk_group(groups: &[GtkGroup], link: GtkLink) -> Result<&GtkGroup, Error> {
    groups
        .iter()
        .find(|group| group.group == link.group && group.menu == link.menu)
        .ok_or(Error::MissingGtkGroup {
            group: link.group,
            menu: link.menu,
        })
}

fn gtk_items(group: &GtkGroup) -> Vec<Item> {
    group
        .items
        .iter()
        .enumerate()
        .map(|(index, item)| Item {
            id: index as i32,
            label: gtk_label(item),
            enabled: true,
            separator: false,
        })
        .collect()
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
}

#[proxy(interface = "org.gtk.Menus", assume_defaults = true)]
trait GtkMenus {
    fn start(&self, groups: &[u32]) -> zbus::Result<Vec<GtkGroup>>;

    fn end(&self, groups: &[u32]) -> zbus::Result<()>;
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

#[derive(Deserialize)]
struct Endpoint {
    #[serde(default)]
    kind: EndpointKind,
    address: Option<String>,
    service: String,
    path: String,
}

#[derive(Default, Deserialize)]
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
    #[error("the D-BusMenu layout used an unsupported value")]
    DecodeLayout(#[source] zbus::zvariant::Error),
    #[error("the D-BusMenu layout contained an invalid item")]
    InvalidNode,
}
