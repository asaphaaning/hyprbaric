//! Parsed compositor facts and exporter addresses.
use super::registrar;
use serde::Deserialize;

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

    pub(in crate::global_menu) fn application_path(&self) -> Option<&str> {
        match self {
            Self::Gtk {
                application_path, ..
            } => application_path.as_deref(),
            Self::DbusMenu { .. } | Self::X11 { .. } | Self::Parent { .. } => None,
        }
    }

    pub(in crate::global_menu) fn window_path(&self) -> Option<&str> {
        match self {
            Self::Gtk { window_path, .. } => window_path.as_deref(),
            Self::DbusMenu { .. } | Self::X11 { .. } | Self::Parent { .. } => None,
        }
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
