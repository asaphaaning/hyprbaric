//! Owned live state for one menu session. No process-global caches or detached watches.
mod capture;
pub(super) mod watch;
use super::{
    Error, Item, Menu, SectionId, Session, Update,
    dbusmenu::{self, DBUSMENU_RELAYOUT, dbusmenu_items, dbusmenu_live_items},
    endpoint::Endpoint,
    gtk::client::gtk_items,
    popup::{Opened, closing},
    snapshot::{Exporter, Held, Snapshot},
};
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};
use tokio::{
    sync::{Notify, watch as signal},
    task::JoinHandle,
};
use tracing::instrument;
use zbus::Connection;

/// A live session owns its watch; dropping it aborts outstanding work.
pub(super) struct Live {
    /// State shared only with this session's watch.
    pub state: Arc<State>,
    watch: Option<Watch>,
}

/// Cancellation ownership stays outside the state captured by the task.
struct Watch {
    epoch: u64,
    task: JoinHandle<()>,
}
impl Drop for Watch {
    fn drop(&mut self) {
        self.task.abort();
    }
}
impl Live {
    pub fn new(session: Session, publish: fn(Update)) -> Self {
        let (generation, _) = signal::channel(0);
        Self {
            state: Arc::new(State {
                session,
                publish,
                generation,
                populated: Notify::new(),
                held: Mutex::new(Held::Vacant),
                opened: Mutex::new(Vec::new()),
            }),
            watch: None,
        }
    }
    /// Starts exactly one watch for the current snapshot generation.
    pub async fn watch(&mut self, connection: Connection, endpoint: Endpoint) {
        let epoch = self.state.generation();
        if self
            .watch
            .as_ref()
            .is_some_and(|watch| watch.epoch == epoch && !watch.task.is_finished())
        {
            return;
        }
        self.stop_watch().await;
        let state = Arc::clone(&self.state);
        self.watch = Some(Watch {
            epoch,
            task: tokio::spawn(async move {
                if let Err(error) = watch::run(state, epoch, connection, endpoint).await {
                    tracing::debug!(%error,"Menu watch ended");
                }
            }),
        });
    }
    /// Cancels and joins the watch before closing its announced popups.
    pub async fn close(&mut self) {
        self.state.bump();
        self.stop_watch().await;
        self.state.clear().await;
    }
    async fn stop_watch(&mut self) {
        if let Some(mut watch) = self.watch.take() {
            // Cooperative cancellation lets GTK send End. A stuck exporter
            // cannot keep the replacement session waiting indefinitely.
            if tokio::time::timeout(std::time::Duration::from_millis(500), &mut watch.task)
                .await
                .is_err()
            {
                watch.task.abort();
                let _ = (&mut watch.task).await;
            }
        }
    }
}

/// Snapshot and popup state belong to one immutable session identity.
pub(super) struct State {
    session: Session,
    publish: fn(Update),
    generation: signal::Sender<u64>,
    populated: Notify,
    held: Mutex<Held>,
    opened: Mutex<Vec<Opened>>,
}
impl State {
    pub(in crate::global_menu) fn remember_opened(
        &self,
        endpoint: Endpoint,
        id: i32,
        path: Vec<String>,
        section: SectionId,
    ) {
        let mut opened = self.opened();
        opened.retain(|menu| menu.id != id && menu.path != path);
        opened.push(Opened {
            endpoint,
            id,
            path,
            section,
        });
    }

    pub(in crate::global_menu) fn take_opened(&self, id: i32, path: &[String]) -> Vec<Opened> {
        let mut opened = self.opened();
        let current = std::mem::take(&mut *opened);
        let (close, keep) = closing(current, id, path);
        *opened = keep;
        close
    }

    pub(in crate::global_menu) fn drain_opened(&self) -> Vec<Opened> {
        std::mem::take(&mut *self.opened())
    }

    pub(in crate::global_menu) fn announced(&self) -> Vec<Opened> {
        self.opened().clone()
    }

    /// Label path of a D-BusMenu row the bar already served.
    pub(in crate::global_menu) fn item_path(&self, id: i32) -> Vec<String> {
        self.held().item_path(id)
    }

    /// Path used to close a heading or flyout, including after Firefox rebuilds ids.
    ///
    /// Dart still holds the identifier from the last read. The live node may now
    /// have a different id, so `closed` follows the heading labels: the snapshot's
    /// hint, then the last served row path, then whatever we announced as open.
    pub(in crate::global_menu) fn dismiss_path(&self, id: i32) -> Vec<String> {
        {
            let held = self.held();
            let hinted = held.path_of(&SectionId::DbusMenu { id });
            if !hinted.is_empty() {
                return hinted;
            }
            let served = held.item_path(id);
            if !served.is_empty() {
                return served;
            }
        }
        self.opened()
            .iter()
            .find(|menu| menu.id == id)
            .map(|menu| menu.path.clone())
            .unwrap_or_default()
    }

    pub(in crate::global_menu) fn held(&self) -> MutexGuard<'_, Held> {
        self.held.lock().unwrap_or_else(PoisonError::into_inner)
    }

    pub(in crate::global_menu) fn opened(&self) -> MutexGuard<'_, Vec<Opened>> {
        self.opened.lock().unwrap_or_else(PoisonError::into_inner)
    }

    pub(in crate::global_menu) fn generation(&self) -> u64 {
        *self.generation.borrow()
    }

    pub(in crate::global_menu) fn bump(&self) -> u64 {
        self.generation
            .send_replace(self.generation().wrapping_add(1))
            .wrapping_add(1)
    }

    #[instrument(name = "hyprbaric::global_menu::live::headings", skip(self))]
    pub(in crate::global_menu) async fn headings(
        &self,
        connection: Connection,
        endpoint: Endpoint,
    ) -> Result<Menu, Error> {
        let exporter = Exporter::of(&endpoint);

        if let Some(menu) = self.held().headings_for(&exporter) {
            return Ok(menu);
        }

        if self.held().holds(&exporter) {
            self.wait_until_populated(&exporter).await;
            return match self.held().headings_for(&exporter) {
                Some(menu) => Ok(menu),
                // Still empty, or this exporter was replaced while we waited.
                // Recapturing here would bump generation and steal the snapshot
                // of whatever window is focused now.
                None => Err(Error::NoMenuForFocusedWindow),
            };
        }

        self.take(connection, endpoint, exporter).await
    }

    #[instrument(name = "hyprbaric::global_menu::live::items", skip(self))]
    pub(in crate::global_menu) async fn items(
        &self,
        connection: Connection,
        endpoint: Endpoint,
        id: &SectionId,
    ) -> Result<Vec<Item>, Error> {
        let exporter = Exporter::of(&endpoint);

        if !self.held().holds(&exporter) {
            self.take(connection.clone(), endpoint.clone(), exporter.clone())
                .await?;
        } else if self.held().headings_for(&exporter).is_none() {
            self.wait_until_populated(&exporter).await;
        }

        if !self.held().holds(&exporter) {
            return Err(Error::NoMenuForFocusedWindow);
        }

        match id {
            SectionId::DbusMenu { id: dbus_id } => {
                // Always announce. Firefox rebuilds native identifiers after a
                // click, so a cached View menu still holds Zoom In's old ids.
                let path = self.held().path_hint(&exporter, id);
                let items = dbusmenu_items(self, &connection, &endpoint, *dbus_id, &path).await?;
                self.remember(&exporter, id.clone(), items.clone());
                Ok(items)
            }
            SectionId::Gtk { .. } | SectionId::GtkAppMenu { .. } => {
                if let Some(items) = self.held().section_for(&exporter, id) {
                    return Ok(items);
                }

                if let Some(items) = self.wait_for(id, &exporter).await {
                    return Ok(items);
                }

                let items = gtk_items(&connection, &endpoint, id).await?;
                self.remember(&exporter, id.clone(), items.clone());
                Ok(items)
            }
        }
    }

    pub(in crate::global_menu) fn remember(
        &self,
        exporter: &Exporter,
        id: SectionId,
        items: Vec<Item>,
    ) {
        if let Held::Occupied {
            exporter: held,
            snapshot,
        } = &mut *self.held()
            && held == exporter
        {
            snapshot.remember(id, items);
        }
    }

    /// Recaptures the same exporter in the ordered command sequence.
    #[instrument(name = "hyprbaric::global_menu::live::refresh", skip_all)]
    pub(in crate::global_menu) async fn refresh_now(
        &self,
        connection: Connection,
        endpoint: Endpoint,
    ) -> Result<(), Error> {
        let exporter = Exporter::of(&endpoint);
        self.take(connection, endpoint, exporter).await?;
        Ok(())
    }

    pub(in crate::global_menu) async fn take(
        &self,
        connection: Connection,
        endpoint: Endpoint,
        exporter: Exporter,
    ) -> Result<Menu, Error> {
        let leftover = {
            let mut held = self.held();
            let leftover = if held.holds(&exporter) {
                Vec::new()
            } else {
                self.drain_opened()
            };
            if !held.holds(&exporter) {
                *held = Held::occupy(exporter.clone(), Snapshot::default());
            }
            leftover
        };
        if !leftover.is_empty() {
            dbusmenu::close_opened(leftover).await;
        }

        let epoch = self.bump();

        let snapshot = match capture::now(&connection, &endpoint).await {
            Ok(snapshot) => snapshot,
            Err(error) => {
                if self.generation() == epoch {
                    let mut held = self.held();
                    if matches!(
                        &*held,
                        Held::Occupied {
                            exporter: held_exporter,
                            snapshot,
                        } if held_exporter == &exporter && snapshot.headings.sections.is_empty()
                    ) {
                        *held = Held::Vacant;
                    }
                    self.populated.notify_waiters();
                }
                return Err(error);
            }
        };

        self.install(epoch, exporter.clone(), snapshot);
        if let Err(error) = self.refresh_opened(&connection, &endpoint).await {
            tracing::debug!(%error, "Could not refresh an open menu after recapture");
        }

        Ok(self.held().headings_for(&exporter).unwrap_or_default())
    }

    pub(in crate::global_menu) fn install(
        &self,
        epoch: u64,
        exporter: Exporter,
        incoming: Snapshot,
    ) {
        // Keep replacement from advancing the epoch during installation.
        let generation = self.generation.borrow();
        if *generation != epoch {
            return;
        }

        let mut held = self.held();
        let snapshot = match &*held {
            Held::Occupied {
                exporter: held,
                snapshot,
            } if held == &exporter && matches!(&exporter.endpoint, Endpoint::DbusMenu { .. }) => {
                snapshot.clone().merge(incoming)
            }
            _ => incoming,
        };

        let session = &self.session;
        (self.publish)(Update::Headings {
            session: session.clone(),
            menu: snapshot.headings.clone(),
        });
        for (id, items) in &snapshot.sections {
            if items.is_empty() && matches!(id, SectionId::DbusMenu { .. }) {
                continue;
            }
            (self.publish)(Update::Section {
                session: session.clone(),
                section: id.clone(),
                items: items.clone(),
            });
        }

        *held = Held::occupy(exporter, snapshot);
        self.populated.notify_waiters();
    }

    pub(in crate::global_menu) async fn clear(&self) {
        self.bump();
        *self.held() = Held::Vacant;
        let leftover = self.drain_opened();
        if leftover.is_empty() {
            return;
        }
        dbusmenu::close_opened(leftover).await;
    }

    pub(in crate::global_menu) async fn wait_until_populated(&self, exporter: &Exporter) {
        let mut current = self.generation.subscribe();
        let start = *current.borrow();

        loop {
            let notified = self.populated.notified();
            {
                let held = self.held();
                if !held.holds(exporter) || held.headings_for(exporter).is_some() {
                    return;
                }
            }

            tokio::select! {
                _ = notified => {}
                _ = current.changed() => {
                    if *current.borrow() != start {
                        return;
                    }
                }
                _ = tokio::time::sleep(DBUSMENU_RELAYOUT) => return,
            }
        }
    }

    pub(in crate::global_menu) async fn wait_for(
        &self,
        id: &SectionId,
        exporter: &Exporter,
    ) -> Option<Vec<Item>> {
        let mut current = self.generation.subscribe();
        let start = *current.borrow();

        loop {
            {
                let held = self.held();
                if !held.holds(exporter) {
                    return None;
                }
                if let Some(items) = held.section_for(exporter, id) {
                    return Some(items);
                }
            }

            tokio::select! {
                _ = self.populated.notified() => {}
                _ = current.changed() => {
                    if *current.borrow() != start {
                        return None;
                    }
                }
                _ = tokio::time::sleep(DBUSMENU_RELAYOUT) => return None,
            }
        }
    }

    pub(in crate::global_menu) async fn replace(
        &self,
        epoch: u64,
        connection: &Connection,
        endpoint: &Endpoint,
    ) -> Result<(), Error> {
        let snapshot = capture::now(connection, endpoint).await?;
        if snapshot.headings.sections.is_empty() {
            return Ok(());
        }
        self.install(epoch, Exporter::of(endpoint), snapshot);
        if let Err(error) = self.refresh_opened(connection, endpoint).await {
            tracing::debug!(%error, "Could not refresh an open menu after a layout update");
        }
        Ok(())
    }

    /// Re-reads every D-BusMenu the bar is currently showing.
    ///
    /// Watch recaptures headings only. That is enough after Zoom In closes the
    /// panel; View → Toolbars is still up, and its checkmarks live on the rows.
    #[instrument(name = "hyprbaric::global_menu::live::refresh_opened", skip_all)]
    pub(in crate::global_menu) async fn refresh_opened(
        &self,
        connection: &Connection,
        endpoint: &Endpoint,
    ) -> Result<(), Error> {
        if !matches!(endpoint, Endpoint::DbusMenu { .. }) {
            return Ok(());
        }

        let exporter = Exporter::of(endpoint);
        let epoch = self.generation();
        let session = &self.session;
        for menu in self.announced() {
            if Exporter::of(&menu.endpoint) != exporter {
                continue;
            }
            let items = match dbusmenu_live_items(connection, endpoint, menu.id, &menu.path).await {
                Ok(items) => items,
                Err(error) => {
                    tracing::debug!(%error, "Could not re-read an open menu");
                    continue;
                }
            };
            if items.is_empty() {
                continue;
            }
            if self.generation() != epoch {
                return Ok(());
            }
            if !self.announced().contains(&menu) {
                continue;
            }
            self.remember(&exporter, menu.section.clone(), items.clone());
            (self.publish)(Update::Section {
                session: session.clone(),
                section: menu.section.clone(),
                items,
            });
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::{Live, Session, Watch};
    use crate::hyprland::WindowId;
    use std::sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    };
    fn live() -> Live {
        Live::new(
            Session {
                generation: 1,
                window: WindowId::new("0x1".into()).expect("window"),
            },
            |_| {},
        )
    }
    #[tokio::test]
    async fn close_waits_for_subscription_cleanup() {
        let mut live = live();
        let mut cancelled = live.state.generation.subscribe();
        let ended = Arc::new(AtomicBool::new(false));
        let observed = Arc::clone(&ended);
        live.watch = Some(Watch {
            epoch: 0,
            task: tokio::spawn(async move {
                cancelled.changed().await.expect("cancellation");
                tokio::task::yield_now().await;
                observed.store(true, Ordering::SeqCst);
            }),
        });
        live.close().await;
        assert!(ended.load(Ordering::SeqCst));
        assert!(live.watch.is_none());
    }
    #[tokio::test]
    async fn dropping_live_aborts_the_owned_watch() {
        let mut live = live();
        let task = tokio::spawn(std::future::pending());
        let abort = task.abort_handle();
        live.watch = Some(Watch { epoch: 0, task });
        drop(live);
        tokio::task::yield_now().await;
        assert!(abort.is_finished());
    }
}
