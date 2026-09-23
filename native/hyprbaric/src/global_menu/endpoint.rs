//! Parsed compositor facts and exporter addresses.
use super::registrar;
use serde::Deserialize;

/// An action namespace published by a GTK menu exporter.
///
/// Menu items name actions as `scope.name`; the exporter supplies the D-Bus
/// object that owns each scope. Several scopes may share one object.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(in crate::global_menu) struct ActionGroup {
    /// Prefix before the action name's first dot.
    pub(in crate::global_menu) scope: String,
    /// D-Bus object exporting actions in this scope.
    pub(in crate::global_menu) path: String,
}

impl ActionGroup {
    /// Keeps a published path only when the exporter provided one.
    pub(in crate::global_menu) fn at(scope: &str, path: Option<String>) -> Option<Self> {
        path.filter(|path| !path.is_empty()).map(|path| Self {
            scope: scope.to_owned(),
            path,
        })
    }
}

/// One companion row, in the shape of the protocol it speaks.
///
/// The plugin JSON is a tagged bag. That is decoded into this enum immediately,
/// so an X11 association cannot be asked for rows and a D-BusMenu cannot carry
/// GTK action paths.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(in crate::global_menu) enum Endpoint {
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
        /// Action scopes and their exporter-owned D-Bus object paths.
        action_groups: Vec<ActionGroup>,
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
pub(in crate::global_menu) struct PluginEndpoint {
    #[serde(default)]
    pub(in crate::global_menu) kind: EndpointKind,
    pub(in crate::global_menu) address: Option<String>,
    #[serde(default)]
    pub(in crate::global_menu) service: String,
    #[serde(default)]
    pub(in crate::global_menu) path: String,
    #[serde(default)]
    pub(in crate::global_menu) app_menu_path: Option<String>,
    #[serde(default)]
    pub(in crate::global_menu) application_path: Option<String>,
    #[serde(default)]
    pub(in crate::global_menu) window_path: Option<String>,
    #[serde(default)]
    pub(in crate::global_menu) xid: Option<u32>,
    #[serde(default)]
    pub(in crate::global_menu) parent: Option<String>,
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
                action_groups: [
                    ActionGroup::at("app", row.application_path),
                    ActionGroup::at("win", row.window_path),
                ]
                .into_iter()
                .flatten()
                .collect(),
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
    pub(in crate::global_menu) fn from_registrar(
        address: String,
        registration: registrar::Registration,
    ) -> Self {
        Self::DbusMenu {
            address: Some(address),
            service: registration.service,
            path: registration.path,
            xid: None,
        }
    }

    pub(in crate::global_menu) fn exposes_menu(&self) -> bool {
        match self {
            Self::DbusMenu { service, path, .. } | Self::Gtk { service, path, .. } => {
                !service.is_empty() && !path.is_empty()
            }
            Self::X11 { .. } | Self::Parent { .. } => false,
        }
    }

    pub(in crate::global_menu) fn address(&self) -> Option<&str> {
        match self {
            Self::DbusMenu { address, .. }
            | Self::Gtk { address, .. }
            | Self::X11 { address, .. }
            | Self::Parent { address, .. } => address.as_deref(),
        }
    }

    pub(in crate::global_menu) fn xid(&self) -> Option<u32> {
        match self {
            Self::DbusMenu { xid, .. } | Self::Gtk { xid, .. } | Self::X11 { xid, .. } => *xid,
            Self::Parent { .. } => None,
        }
    }

    pub(in crate::global_menu) fn parent(&self) -> Option<&str> {
        match self {
            Self::Parent { parent, .. } => Some(parent.as_str()),
            Self::DbusMenu { .. } | Self::Gtk { .. } | Self::X11 { .. } => None,
        }
    }

    pub(in crate::global_menu) fn service(&self) -> &str {
        match self {
            Self::DbusMenu { service, .. } | Self::Gtk { service, .. } => service,
            Self::X11 { .. } | Self::Parent { .. } => "",
        }
    }

    pub(in crate::global_menu) fn path(&self) -> &str {
        match self {
            Self::DbusMenu { path, .. } | Self::Gtk { path, .. } => path,
            Self::X11 { .. } | Self::Parent { .. } => "",
        }
    }

    pub(in crate::global_menu) fn app_menu_path(&self) -> Option<&str> {
        match self {
            Self::Gtk { app_menu_path, .. } => app_menu_path.as_deref(),
            Self::DbusMenu { .. } | Self::X11 { .. } | Self::Parent { .. } => None,
        }
    }

    /// Action scopes advertised by this GTK endpoint.
    pub(in crate::global_menu) fn action_groups(&self) -> &[ActionGroup] {
        match self {
            Self::Gtk { action_groups, .. } => action_groups,
            Self::DbusMenu { .. } | Self::X11 { .. } | Self::Parent { .. } => &[],
        }
    }

    /// D-Bus object that owns an action prefix.
    pub(in crate::global_menu) fn action_path(&self, scope: &str) -> Option<&str> {
        self.action_groups()
            .iter()
            .find(|group| group.scope == scope)
            .map(|group| group.path.as_str())
    }

    /// Distinct action objects, even when several scopes share a path.
    pub(in crate::global_menu) fn action_paths(&self) -> Vec<&str> {
        let mut paths = Vec::new();
        for group in self.action_groups() {
            if !paths.contains(&group.path.as_str()) {
                paths.push(group.path.as_str());
            }
        }
        paths
    }
}

#[derive(Clone, Debug, Default, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub(in crate::global_menu) enum EndpointKind {
    #[default]
    DbusMenu,
    Gtk,
    X11,
    Parent,
}
