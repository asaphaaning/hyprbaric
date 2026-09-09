//! Owned GTK Start/Changed/End subscription and ordered splice handling.
use super::{client, tree};
use crate::global_menu::{
    Error,
    discovery::focused_list_title,
    endpoint::Endpoint,
    live::{
        State,
        watch::{DEBOUNCE, recv},
    },
    model::entitle_anonymous_list,
    snapshot::{Exporter, Snapshot},
};
use client::{gtk_actions, gtk_describe, gtk_menus, gtk_menus_at};
use futures_util::{FutureExt, StreamExt};
use std::future::pending;
use tokio::sync::watch;
use tree::{gtk_tree, prepend_gtk_app_menu};
use zbus::Connection;
/// A GTK subscription owns its initial rows and applies the protocol's splices.
/// Start remains active until the watch exits; reads never cancel this lease.
struct GtkSubscription<'a> {
    proxy: client::GtkMenusProxy<'a>,
    groups: Vec<client::GtkGroup>,
    subscribed: std::collections::HashSet<u32>,
}

impl<'a> GtkSubscription<'a> {
    async fn start(proxy: client::GtkMenusProxy<'a>) -> Result<Self, Error> {
        let (groups, subscribed) = client::gtk_subscribe(&proxy, &[0]).await?;
        Ok(Self {
            proxy,
            groups,
            subscribed: subscribed.into_iter().collect(),
        })
    }

    async fn changed(&mut self, changes: &[client::GtkChange]) -> Result<(), Error> {
        for change in changes {
            apply_gtk_change(&mut self.groups, change)?;
        }
        loop {
            let pending = tree::gtk_unfetched_groups(&self.groups, &self.subscribed);
            if pending.is_empty() {
                return Ok(());
            }
            self.groups
                .extend(self.proxy.start(&pending).await.map_err(Error::GtkLayout)?);
            self.subscribed.extend(pending);
        }
    }

    async fn end(&self) {
        let subscribed = self.subscribed.iter().copied().collect::<Vec<_>>();
        if let Err(error) = self.proxy.end(&subscribed).await {
            tracing::debug!(%error, "Could not end GTK menu watch");
        }
    }
}

fn apply_gtk_change(
    groups: &mut Vec<client::GtkGroup>,
    change: &client::GtkChange,
) -> Result<(), Error> {
    let index = groups
        .iter()
        .position(|group| group.group == change.group && group.menu == change.menu);
    let group = match index {
        Some(index) => &mut groups[index],
        None => {
            groups.push(client::GtkGroup {
                group: change.group,
                menu: change.menu,
                items: Vec::new(),
            });
            groups.last_mut().ok_or(Error::InvalidGtkChange)?
        }
    };
    let start = change.position as usize;
    let end = start
        .checked_add(change.removed as usize)
        .ok_or(Error::InvalidGtkChange)?;
    if start > group.items.len() || end > group.items.len() {
        return Err(Error::InvalidGtkChange);
    }
    group.items.splice(start..end, change.items.clone());
    Ok(())
}

pub(in crate::global_menu) async fn run(
    state: &State,
    epoch: u64,
    current: &mut watch::Receiver<u64>,
    _connection: &Connection,
    endpoint: &Endpoint,
) -> Result<(), Error> {
    // A dedicated connection also releases subscriptions on cancellation or
    // partial initialization failure, before an End request could be made.
    let connection = Connection::session().await.map_err(Error::Connect)?;
    let menus = gtk_menus(&connection, endpoint).await?;
    let mut changed = menus.receive_changed().await.map_err(Error::GtkLayout)?;
    let app_menus = match endpoint.app_menu_path() {
        Some(path) => Some(gtk_menus_at(&connection, endpoint.service(), path).await?),
        None => None,
    };
    let mut app_menus_changed = match &app_menus {
        Some(proxy) => Some(proxy.receive_changed().await.map_err(Error::GtkLayout)?),
        None => None,
    };
    let app = match endpoint.application_path() {
        Some(path) => gtk_actions(&connection, endpoint, path).await.ok(),
        None => None,
    };
    let win = match endpoint.window_path() {
        Some(path) => gtk_actions(&connection, endpoint, path).await.ok(),
        None => None,
    };
    let mut app_changed = match &app {
        Some(proxy) => proxy.receive_changed().await.ok(),
        None => None,
    };
    let mut win_changed = match &win {
        Some(proxy) => proxy.receive_changed().await.ok(),
        None => None,
    };
    let mut menus = GtkSubscription::start(menus).await?;
    let mut app_menus = match app_menus {
        Some(proxy) => Some(GtkSubscription::start(proxy).await?),
        None => None,
    };
    let result = async {
        loop {
            let actions = gtk_describe(&connection, endpoint).await;
            let (mut headings, mut sections) = gtk_tree(&menus.groups, &actions)?;
            if let Some(app_menu) = &app_menus {
                (headings, sections) = prepend_gtk_app_menu(
                    headings,
                    sections,
                    &app_menu.groups,
                    &actions,
                    focused_list_title().await,
                )?;
            }
            entitle_anonymous_list(&mut headings, focused_list_title().await);
            state.install(
                epoch,
                Exporter::of(endpoint),
                Snapshot {
                    headings,
                    sections,
                    ..Default::default()
                },
            );

            // Consume every splice; discarding events during a debounce loses
            // the positional baseline required by subsequent GTK changes.
            tokio::select! {
                _ = current.changed() => {
                    if *current.borrow() != epoch { return Ok(()) }
                }
                signal = changed.next() => {
                    let Some(signal) = signal else { return Ok(()) };
                    menus.changed(signal.args().map_err(Error::GtkLayout)?.changes()).await?;
                }
                signal = next_optional(&mut app_menus_changed) => {
                    let Some(signal) = signal else { return Ok(()) };
                    if let Some(menu) = &mut app_menus {
                        menu.changed(signal.args().map_err(Error::GtkLayout)?.changes()).await?;
                    }
                }
                _ = recv(&mut app_changed) => {}
                _ = recv(&mut win_changed) => {}
            }
            // Coalesce bursts without losing the ordered positional splices.
            tokio::time::sleep(DEBOUNCE).await;
            while let Some(Some(signal)) = changed.next().now_or_never() {
                menus
                    .changed(signal.args().map_err(Error::GtkLayout)?.changes())
                    .await?;
            }
            while let Some(Some(signal)) = next_optional(&mut app_menus_changed).now_or_never() {
                if let Some(menu) = &mut app_menus {
                    menu.changed(signal.args().map_err(Error::GtkLayout)?.changes())
                        .await?;
                }
            }
            while let Some(Some(_)) = next_optional(&mut app_changed).now_or_never() {}
            while let Some(Some(_)) = next_optional(&mut win_changed).now_or_never() {}
            if *current.borrow() != epoch {
                return Ok(());
            }
        }
    }
    .await;
    menus.end().await;
    if let Some(menu) = &app_menus {
        menu.end().await;
    }
    result
}

async fn next_optional<S: StreamExt + Unpin>(stream: &mut Option<S>) -> Option<S::Item> {
    match stream {
        Some(stream) => stream.next().await,
        None => pending().await,
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn gtk_splices_preserve_unmodified_rows_and_reject_invalid_ranges() {
        use crate::global_menu::gtk::client::{GtkChange, GtkGroup};
        use std::collections::HashMap;
        let row = |label: &'static str| {
            HashMap::from([(
                "label".to_owned(),
                zbus::zvariant::OwnedValue::try_from(zbus::zvariant::Value::from(label))
                    .expect("label"),
            )])
        };
        let mut groups = vec![GtkGroup {
            group: 0,
            menu: 1,
            items: vec![row("First"), row("Removed"), row("Last")],
        }];
        let change = GtkChange {
            group: 0,
            menu: 1,
            position: 1,
            removed: 1,
            items: vec![row("New"), row("Also new")],
        };
        super::apply_gtk_change(&mut groups, &change).expect("valid splice");
        assert_eq!(
            groups[0].items,
            vec![row("First"), row("New"), row("Also new"), row("Last")]
        );
        assert!(
            super::apply_gtk_change(
                &mut groups,
                &GtkChange {
                    position: 99,
                    ..change
                }
            )
            .is_err()
        );
    }

    #[test]
    fn gtk_changed_uses_the_protocol_splice_signature() {
        use zbus::zvariant::Type;
        assert_eq!(
            <Vec<crate::global_menu::gtk::client::GtkChange>>::SIGNATURE.to_string(),
            "a(uuuuaa{sv})"
        );
    }
}
