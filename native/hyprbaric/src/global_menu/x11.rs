//! GTK menu addresses published as properties of an XWayland window.
//!
//! The compositor companion knows the X11 id, while GTK advertises its
//! D-Bus menu on that X11 window. Some GTK modules do not register with
//! Canonical's AppMenu registrar, so these properties are the remaining link.
use super::endpoint::{ActionGroup, Endpoint};
use std::{process::Stdio, time::Duration};
use tokio::{process::Command, time::timeout};
use zbus::{names::BusName, zvariant::ObjectPath};

/// Legacy appmenu-gtk-module protocol names for an action namespace.
/// These describe an X11 property and action prefix, not an application.
const LEGACY_ACTION_PROPERTY: &str = "_UNITY_OBJECT_PATH";
const LEGACY_ACTION_SCOPE: &str = "unity";

const PROPERTIES: &[&str] = &[
    "_GTK_UNIQUE_BUS_NAME",
    "_GTK_MENUBAR_OBJECT_PATH",
    "_GTK_APP_MENU_OBJECT_PATH",
    "_GTK_APPLICATION_OBJECT_PATH",
    "_GTK_WINDOW_OBJECT_PATH",
    LEGACY_ACTION_PROPERTY,
];

/// Looks up a GTK menu on one XWayland window after registrar discovery misses.
///
/// An absent `xprop`, missing properties, and a window that closes during the
/// lookup all mean that this window has no usable GTK endpoint.
#[tracing::instrument(name = "hyprbaric::global_menu::x11_gtk", skip(address))]
pub(super) async fn gtk_endpoint(address: &str, xid: u32) -> Option<Endpoint> {
    let mut command = Command::new("xprop");
    let output = match timeout(
        Duration::from_millis(300),
        command
            .kill_on_drop(true)
            .args(["-notype", "-id", &xid.to_string()])
            .args(PROPERTIES)
            .stdin(Stdio::null())
            .output(),
    )
    .await
    {
        Ok(Ok(output)) if output.status.success() => output,
        Ok(Ok(output)) => {
            tracing::debug!(status = ?output.status.code(), "Could not read X11 GTK properties");
            return None;
        }
        Ok(Err(error)) => {
            tracing::debug!(%error, "Could not query X11 GTK properties");
            return None;
        }
        Err(_) => {
            tracing::debug!("Timed out reading X11 GTK properties");
            return None;
        }
    };

    let properties = std::str::from_utf8(&output.stdout).ok()?;
    Properties::parse(properties).endpoint(address, xid)
}

/// Only the values that describe a GTK menu and its action groups.
#[derive(Default)]
struct Properties<'a> {
    service: Option<&'a str>,
    menubar: Option<&'a str>,
    app_menu: Option<&'a str>,
    application: Option<&'a str>,
    window: Option<&'a str>,
    legacy_actions: Option<&'a str>,
}

impl<'a> Properties<'a> {
    fn parse(output: &'a str) -> Self {
        let mut properties = Self::default();
        for line in output.lines() {
            let Some((name, value)) = line.split_once(" = ") else {
                continue;
            };
            let Some(value) = value
                .strip_prefix('"')
                .and_then(|value| value.strip_suffix('"'))
            else {
                continue;
            };
            if value.is_empty() || value.contains('"') {
                continue;
            }
            match name {
                "_GTK_UNIQUE_BUS_NAME" => properties.service = Some(value),
                "_GTK_MENUBAR_OBJECT_PATH" => properties.menubar = Some(value),
                "_GTK_APP_MENU_OBJECT_PATH" => properties.app_menu = Some(value),
                "_GTK_APPLICATION_OBJECT_PATH" => properties.application = Some(value),
                "_GTK_WINDOW_OBJECT_PATH" => properties.window = Some(value),
                name if name == LEGACY_ACTION_PROPERTY => {
                    properties.legacy_actions = Some(value);
                }
                _ => {}
            }
        }
        properties
    }

    fn endpoint(self, address: &str, xid: u32) -> Option<Endpoint> {
        let service = self
            .service
            .filter(|value| BusName::try_from(*value).is_ok())?;
        let menubar = valid_path(self.menubar);
        let app_menu = valid_path(self.app_menu);
        let path = menubar.or(app_menu)?;

        Some(Endpoint::Gtk {
            address: Some(address.to_owned()),
            service: service.to_owned(),
            path: path.to_owned(),
            app_menu_path: menubar.and(app_menu).map(str::to_owned),
            action_groups: [
                ActionGroup::at("app", valid_path(self.application).map(str::to_owned)),
                ActionGroup::at("win", valid_path(self.window).map(str::to_owned)),
                ActionGroup::at(
                    LEGACY_ACTION_SCOPE,
                    valid_path(self.legacy_actions).map(str::to_owned),
                ),
            ]
            .into_iter()
            .flatten()
            .collect(),
            xid: Some(xid),
        })
    }
}

fn valid_path(path: Option<&str>) -> Option<&str> {
    path.filter(|value| ObjectPath::try_from(*value).is_ok())
}

#[cfg(test)]
mod tests {
    use super::{Endpoint, Properties};

    #[test]
    fn xwayland_gtk_properties_resolve_unity_menu_and_actions() {
        let output = r#"_GTK_UNIQUE_BUS_NAME = ":1.579"
_GTK_MENUBAR_OBJECT_PATH = "/org/appmenu/gtk/window/1"
_GTK_APP_MENU_OBJECT_PATH:  no such atom on any window.
_UNITY_OBJECT_PATH = "/org/appmenu/gtk/window/1"
"#;
        let endpoint = Properties::parse(output)
            .endpoint("0xabc", 14680725)
            .expect("GTK endpoint");
        assert!(matches!(
            &endpoint,
            Endpoint::Gtk {
                address: Some(address),
                service,
                path,
                xid: Some(14680725),
                ..
            } if address == "0xabc"
                && service == ":1.579"
                && path == "/org/appmenu/gtk/window/1"
        ));
        assert_eq!(endpoint.action_path("unity"), Some(endpoint.path()));
        assert_eq!(endpoint.action_paths(), vec![endpoint.path()]);
    }

    #[test]
    fn missing_or_invalid_gtk_properties_are_not_endpoints() {
        for output in [
            "_GTK_UNIQUE_BUS_NAME = \":1.579\"\n",
            "_GTK_UNIQUE_BUS_NAME = \":1.579\"\n_GTK_MENUBAR_OBJECT_PATH = \"invalid\"\n",
            "_GTK_UNIQUE_BUS_NAME = \"invalid\"\n_GTK_MENUBAR_OBJECT_PATH = \"/menu\"\n",
            "_GTK_UNIQUE_BUS_NAME = \":1.579\"\n_GTK_MENUBAR_OBJECT_PATH: no such atom\n",
        ] {
            assert!(Properties::parse(output).endpoint("0xabc", 1).is_none());
        }
    }
}
