//! One-shot snapshots. GTK reads use a connection separate from its live subscription.
use crate::global_menu::{
    Error,
    dbusmenu::{dbusmenu, dbusmenu_tree},
    discovery::focused_list_title,
    endpoint::Endpoint,
    gtk::{
        client::{gtk_describe, gtk_layout, gtk_menus, gtk_menus_at},
        tree::{gtk_tree, prepend_gtk_app_menu},
    },
    model::entitle_anonymous_list,
    snapshot::Snapshot,
};
use zbus::Connection;
pub(super) async fn now(connection: &Connection, endpoint: &Endpoint) -> Result<Snapshot, Error> {
    match endpoint {
        Endpoint::DbusMenu { .. } => capture_dbusmenu(connection, endpoint).await,
        Endpoint::Gtk { .. } => capture_gtk(connection, endpoint).await,
        Endpoint::X11 { .. } | Endpoint::Parent { .. } => Err(Error::NoMenuForFocusedWindow),
    }
}

async fn capture_dbusmenu(connection: &Connection, endpoint: &Endpoint) -> Result<Snapshot, Error> {
    let proxy = dbusmenu(connection, endpoint).await?;
    let layout = proxy.get_layout(0, 1, &[]).await.map_err(Error::Layout)?;
    let (mut headings, sections) = dbusmenu_tree(&layout.root)?;
    entitle_anonymous_list(&mut headings, focused_list_title().await);
    Ok(Snapshot {
        headings,
        sections,
        ..Default::default()
    })
}

async fn capture_gtk(connection: &Connection, endpoint: &Endpoint) -> Result<Snapshot, Error> {
    let proxy = gtk_menus(connection, endpoint).await?;
    let groups = gtk_layout(&proxy).await?;
    let actions = gtk_describe(connection, endpoint).await;
    let (mut headings, mut sections) = gtk_tree(&groups, &actions)?;

    if let Some(path) = endpoint.app_menu_path() {
        match gtk_menus_at(connection, endpoint.service(), path).await {
            Ok(app_proxy) => match gtk_layout(&app_proxy).await {
                Ok(app_groups) => {
                    let title = focused_list_title().await;
                    (headings, sections) =
                        prepend_gtk_app_menu(headings, sections, &app_groups, &actions, title)?;
                }
                Err(error) => {
                    tracing::debug!(%error, "GTK application menu layout was not readable");
                }
            },
            Err(error) => {
                tracing::debug!(%error, "GTK application menu was not reachable");
            }
        }
    }

    entitle_anonymous_list(&mut headings, focused_list_title().await);
    tracing::debug!(
        labels = ?headings
            .sections
            .iter()
            .map(|section| section.label.as_str())
            .collect::<Vec<_>>(),
        "GTK headings"
    );
    Ok(Snapshot {
        headings,
        sections,
        ..Default::default()
    })
}
