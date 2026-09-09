//! GTK menu and action-group D-Bus calls.
use super::tree::{gtk_menu_items, gtk_unfetched_groups};
use crate::global_menu::{Error, Item, SectionId, endpoint::Endpoint};
use serde::Deserialize;
use std::collections::{HashMap, HashSet};
use tracing::instrument;
use zbus::{
    proxy,
    zvariant::{OwnedValue, Type},
};
pub(in crate::global_menu) async fn gtk_items(
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
#[instrument(name = "hyprbaric::global_menu::gtk_layout", skip(proxy))]
pub(in crate::global_menu) async fn gtk_layout(
    proxy: &GtkMenusProxy<'_>,
) -> Result<Vec<GtkGroup>, Error> {
    let (groups, subscribed) = gtk_subscribe(proxy, &[0]).await?;
    if let Err(error) = proxy.end(&subscribed).await {
        tracing::debug!(%error, "GTK menu declined to end the subscription");
    }
    Ok(groups)
}

pub(in crate::global_menu) async fn gtk_subscribe(
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
pub(in crate::global_menu) async fn gtk_menus<'a>(
    connection: &zbus::Connection,
    endpoint: &Endpoint,
) -> Result<GtkMenusProxy<'a>, Error> {
    gtk_menus_at(connection, endpoint.service(), endpoint.path()).await
}

pub(in crate::global_menu) async fn gtk_menus_at<'a>(
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
pub(in crate::global_menu) async fn gtk_activate(
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
        Some(bytes) => Some(super::decode_target(bytes).ok_or(Error::InvalidGtkTarget)?),
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
pub(in crate::global_menu) async fn gtk_describe(
    connection: &zbus::Connection,
    endpoint: &Endpoint,
) -> super::Actions {
    let mut actions = super::Actions::default();
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

pub(in crate::global_menu) async fn gtk_describe_at(
    actions: &mut super::Actions,
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
            super::Action::from_description(
                description.enabled,
                description.parameter_type,
                description.state,
            ),
        );
    }
}

pub(in crate::global_menu) async fn gtk_actions<'a>(
    connection: &zbus::Connection,
    endpoint: &Endpoint,
    path: &str,
) -> Result<super::GtkActionsProxy<'a>, Error> {
    super::GtkActionsProxy::builder(connection)
        .destination(endpoint.service().to_owned())
        .map_err(Error::CreateGtkProxy)?
        .path(path.to_owned())
        .map_err(Error::CreateGtkProxy)?
        .build()
        .await
        .map_err(Error::CreateGtkProxy)
}

#[proxy(interface = "org.gtk.Menus", assume_defaults = true)]
pub(in crate::global_menu) trait GtkMenus {
    fn start(&self, groups: &[u32]) -> zbus::Result<Vec<GtkGroup>>;

    fn end(&self, groups: &[u32]) -> zbus::Result<()>;

    #[zbus(signal)]
    fn changed(&self, changes: Vec<GtkChange>) -> zbus::Result<()>;
}

/// One splice in a subscribed GTK menu: group, menu, position, removed, added.
#[derive(Clone, Debug, Deserialize, Type)]
pub(in crate::global_menu) struct GtkChange {
    pub(in crate::global_menu) group: u32,
    pub(in crate::global_menu) menu: u32,
    pub(in crate::global_menu) position: u32,
    pub(in crate::global_menu) removed: u32,
    pub(in crate::global_menu) items: Vec<HashMap<String, OwnedValue>>,
}

#[derive(Clone, Debug, Deserialize, Type)]
pub(in crate::global_menu) struct GtkGroup {
    pub(in crate::global_menu) group: u32,
    pub(in crate::global_menu) menu: u32,
    pub(in crate::global_menu) items: Vec<HashMap<String, OwnedValue>>,
}

#[derive(Clone, Copy, Debug)]
pub(in crate::global_menu) struct GtkLink {
    pub(in crate::global_menu) group: u32,
    pub(in crate::global_menu) menu: u32,
}

impl GtkLink {
    pub(in crate::global_menu) const ROOT: Self = Self { group: 0, menu: 0 };
}
