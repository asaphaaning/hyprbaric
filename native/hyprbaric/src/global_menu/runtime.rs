//! Application-owned menu lifecycle and ordered command execution.
//!
//! ```text
//! Idle --discover--> Active { identity, endpoint, live }
//!  ^                   |
//!  +---- close/join ---+ focus or exporter changes
//! ```
use super::{
    Error, Item, ItemId, Menu, SectionId, Session, Update, dbusmenu, discovery, endpoint::Endpoint,
    gtk, live::Live,
};
use crate::hyprland::WindowId;
use hyprland::{data::Client, prelude::HyprDataActiveOptional};
use tracing::instrument;

/// Owns one focused exporter and all work that can publish on its behalf.
pub struct Runtime {
    /// Application-selected sink for typed menu updates.
    publish: fn(Update),
    /// Monotonic identity for each replacement session.
    generation: u64,
    /// Only a discovered exporter can own live work.
    active: Option<Active>,
}

/// The resources whose lifetimes are bounded by one menu identity.
struct Active {
    session: Session,
    endpoint: Endpoint,
    live: Live,
}

impl Runtime {
    /// Creates an idle runtime with an application-selected update sink.
    pub fn new(publish: fn(Update)) -> Self {
        Self {
            publish,
            generation: 0,
            active: None,
        }
    }

    /// Reads headings for an explicit focus observation.
    #[instrument(name = "hyprbaric::global_menu::read", skip(self))]
    pub async fn read(&mut self, window: Option<&str>) -> Result<(Session, Menu), Error> {
        let result = self.read_focused(window).await;
        if matches!(
            result,
            Err(Error::NoFocusedWindow | Error::NoMenuForFocusedWindow)
        ) {
            self.clear().await;
        }
        result
    }
    async fn read_focused(&mut self, window: Option<&str>) -> Result<(Session, Menu), Error> {
        let window = window
            .and_then(|window| WindowId::new(window.to_owned()))
            .ok_or(Error::NoFocusedWindow)?;
        check_focus(&window).await?;
        let endpoint = discovery::focused_endpoint().await?;
        check_focus(&window).await?;
        self.bind(window, endpoint).await;
        let active = self.active.as_mut().ok_or(Error::NoMenuForFocusedWindow)?;
        let connection = connection().await?;
        let menu = active
            .live
            .state
            .headings(connection.clone(), active.endpoint.clone())
            .await;
        active.live.watch(connection, active.endpoint.clone()).await;
        Ok((active.session.clone(), menu?))
    }
    async fn bind(&mut self, window: WindowId, endpoint: Endpoint) {
        if self
            .active
            .as_ref()
            .is_some_and(|active| active.session.window == window && active.endpoint == endpoint)
        {
            return;
        }
        self.clear().await;
        self.generation += 1;
        let session = Session {
            generation: self.generation,
            window,
        };
        self.active = Some(Active {
            live: Live::new(session.clone(), self.publish),
            session,
            endpoint,
        });
    }
    /// Joins the old watch before releasing its popups and replacing identity.
    pub async fn clear(&mut self) {
        if let Some(mut active) = self.active.take() {
            active.live.close().await;
        }
    }
    fn resolve(&mut self, session: &Session) -> Result<&mut Active, Error> {
        self.active
            .as_mut()
            .filter(|active| active.session == *session)
            .ok_or(Error::StaleSession)
    }
    /// Reads a popup from the exporter that supplied its identifier.
    #[instrument(name = "hyprbaric::global_menu::section", skip(self))]
    pub async fn section(&mut self, session: &Session, id: &SectionId) -> Result<Vec<Item>, Error> {
        let active = self.resolve(session)?;
        check_focus(&session.window).await?;
        let connection = connection().await?;
        let result = active
            .live
            .state
            .items(connection.clone(), active.endpoint.clone(), id)
            .await;
        active.live.watch(connection, active.endpoint.clone()).await;
        result
    }
    /// Dismisses popups against their owner even after compositor focus changes.
    #[instrument(name = "hyprbaric::global_menu::dismiss", skip(self))]
    pub async fn dismiss(&mut self, session: &Session, id: &SectionId) -> Result<(), Error> {
        let active = self.resolve(session)?;
        match id {
            SectionId::DbusMenu { id } => dbusmenu::dbusmenu_closed(&active.live.state, *id).await,
            SectionId::Gtk { .. } | SectionId::GtkAppMenu { .. } => Ok(()),
        }
    }
    /// Activates only a row owned by the current focused session.
    #[instrument(name = "hyprbaric::global_menu::activate", skip(self))]
    pub async fn activate(&mut self, session: &Session, id: &ItemId) -> Result<(), Error> {
        let active = self.resolve(session)?;
        check_focus(&session.window).await?;
        let connection = connection().await?;
        match id {
            ItemId::DbusMenu { id } => {
                dbusmenu::dbusmenu_activate(&active.live.state, &connection, &active.endpoint, *id)
                    .await
            }
            ItemId::Gtk { action, target } => {
                gtk::client::gtk_activate(&connection, &active.endpoint, action, target.as_deref())
                    .await
            }
        }?;
        let result = active
            .live
            .state
            .refresh_now(connection.clone(), active.endpoint.clone())
            .await;
        active.live.watch(connection, active.endpoint.clone()).await;
        result
    }
}
async fn connection() -> Result<zbus::Connection, Error> {
    zbus::Connection::session().await.map_err(Error::Connect)
}
async fn check_focus(window: &WindowId) -> Result<(), Error> {
    let active = Client::get_active_async()
        .await
        .map_err(Error::FocusedWindow)?;
    if active.is_some_and(|client| client.address.to_string() == window.as_str()) {
        Ok(())
    } else {
        Err(Error::StaleSession)
    }
}

#[cfg(test)]
mod tests {
    use super::{Endpoint, Error, Runtime, WindowId};
    fn endpoint(window: &str) -> Endpoint {
        Endpoint::Gtk {
            address: None,
            service: ":1.42".into(),
            path: "/Menu".into(),
            app_menu_path: None,
            application_path: Some("/App".into()),
            window_path: Some(window.into()),
            xid: None,
        }
    }
    #[tokio::test]
    async fn window_action_changes_replace_identity_and_returning_does_not_revive_it() {
        let mut runtime = Runtime::new(|_| {});
        let window = WindowId::new("0x1".into()).expect("valid window");
        runtime.bind(window.clone(), endpoint("/First")).await;
        let first = runtime.active.as_ref().expect("bound").session.clone();
        runtime.bind(window.clone(), endpoint("/First")).await;
        assert_eq!(runtime.active.as_ref().expect("bound").session, first);
        runtime.bind(window.clone(), endpoint("/Second")).await;
        assert!(matches!(runtime.resolve(&first), Err(Error::StaleSession)));
        runtime.clear().await;
        runtime.bind(window, endpoint("/First")).await;
        assert!(matches!(runtime.resolve(&first), Err(Error::StaleSession)));
    }
    #[tokio::test]
    async fn runtime_instances_do_not_share_session_state() {
        let mut first = Runtime::new(|_| {});
        let mut second = Runtime::new(|_| {});
        first
            .bind(
                WindowId::new("0x1".into()).expect("window"),
                endpoint("/First"),
            )
            .await;
        second
            .bind(
                WindowId::new("0x2".into()).expect("window"),
                endpoint("/Second"),
            )
            .await;
        let identity = second.active.as_ref().expect("bound").session.clone();
        first.clear().await;
        assert!(second.resolve(&identity).is_ok());
    }
}
