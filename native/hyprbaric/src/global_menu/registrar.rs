//! The Canonical AppMenu registrar.
//!
//! Qt decides whether an application exports its menu or draws one in its own
//! window by asking whether `com.canonical.AppMenu.Registrar` is owned on the
//! session bus, and it asks that question on every desktop including Wayland.
//! Owning the name is therefore what unlocks the Wayland AppMenu protocol the
//! compositor companion advertises, even though Wayland clients publish their
//! endpoint through the compositor rather than through this interface.
//!
//! X11 clients do register here, so the table this keeps is also the XWayland
//! half of endpoint discovery.

use std::{
    collections::HashMap,
    sync::{Arc, Mutex},
};

use futures_util::StreamExt;
use tracing::instrument;
use zbus::zvariant::{ObjectPath, OwnedObjectPath};

const NAME: &str = "com.canonical.AppMenu.Registrar";
const PATH: &str = "/com/canonical/AppMenu/Registrar";

/// An X11 window identifier, as registered by an X11 or XWayland client.
#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq)]
pub struct WindowId(pub u32);

/// One window's exported D-BusMenu address.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Registration {
    /// The bus name that exports the menu.
    pub service: String,
    /// The `com.canonical.dbusmenu` object it exports.
    pub path: String,
}

/// The live registrar, owning the bus name for as long as it is held.
///
/// The registrations it keeps are read back over D-Bus rather than in process:
/// nothing here consumes them until XWayland windows join endpoint discovery.
pub struct Registrar {
    _connection: zbus::Connection,
}

impl Registrar {
    /// Claims the registrar name and begins serving the interface.
    ///
    /// Serving is opt-in for the same reason loading the companion is. Qt reads
    /// the mere existence of this name as "the desktop shows my menu bar for
    /// me", so owning it without rendering those menus would leave every Qt
    /// application with no menu bar anywhere.
    ///
    /// A name owned by another registrar, such as Plasma's, is left alone: Qt
    /// only needs the name to exist, so yielding to an existing owner still
    /// leaves applications exporting their menus.
    #[instrument(name = "hyprbaric::global_menu::registrar::serve", err)]
    pub async fn serve(enabled: bool) -> Result<Option<Self>, Error> {
        if !enabled {
            tracing::debug!("The AppMenu registrar is disabled by configuration");
            return Ok(None);
        }

        let windows = Windows::default();
        let connection = zbus::connection::Builder::session()
            .map_err(Error::Connect)?
            .serve_at(PATH, Interface::new(windows.clone()))
            .map_err(Error::Serve)?
            .build()
            .await
            .map_err(Error::Connect)?;

        match connection
            .request_name_with_flags(NAME, zbus::fdo::RequestNameFlags::DoNotQueue.into())
            .await
        {
            Ok(_) => tracing::info!("Owning {NAME}; Qt applications will export their menus"),
            Err(zbus::Error::NameTaken) => {
                tracing::info!("{NAME} already has an owner; leaving it in place")
            }
            Err(error) => return Err(Error::RequestName(error)),
        }

        tokio::spawn(forget_departed_clients(connection.clone(), windows.clone()));

        Ok(Some(Self {
            _connection: connection,
        }))
    }
}

/// The registrations, shared between the interface and its readers.
#[derive(Clone, Default)]
struct Windows(Arc<Mutex<HashMap<WindowId, Registration>>>);

impl Windows {
    fn insert(&self, window: WindowId, registration: Registration) {
        self.lock().insert(window, registration);
    }

    fn remove(&self, window: WindowId) -> Option<Registration> {
        self.lock().remove(&window)
    }

    fn get(&self, window: WindowId) -> Option<Registration> {
        self.lock().get(&window).cloned()
    }

    fn all(&self) -> Vec<(WindowId, Registration)> {
        let mut all = self
            .lock()
            .iter()
            .map(|(window, registration)| (*window, registration.clone()))
            .collect::<Vec<_>>();
        all.sort_by_key(|(window, _)| window.0);
        all
    }

    /// Drops every window a departed bus name had registered.
    fn forget(&self, service: &str) -> Vec<WindowId> {
        let mut windows = self.lock();
        let departed = windows
            .iter()
            .filter(|(_, registration)| registration.service == service)
            .map(|(window, _)| *window)
            .collect::<Vec<_>>();

        for window in &departed {
            windows.remove(window);
        }

        departed
    }

    /// A poisoned registry is still readable: no invariant spans the lock.
    fn lock(&self) -> std::sync::MutexGuard<'_, HashMap<WindowId, Registration>> {
        self.0.lock().unwrap_or_else(|poison| poison.into_inner())
    }
}

/// The served `com.canonical.AppMenu.Registrar` object.
struct Interface {
    windows: Windows,
}

impl Interface {
    fn new(windows: Windows) -> Self {
        Self { windows }
    }
}

#[zbus::interface(name = "com.canonical.AppMenu.Registrar")]
impl Interface {
    /// Records the menu a client exports for one of its X11 windows.
    #[instrument(
        name = "hyprbaric::global_menu::registrar::register",
        skip_all,
        fields(window)
    )]
    async fn register_window(
        &self,
        #[zbus(header)] header: zbus::message::Header<'_>,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
        window: u32,
        menu: OwnedObjectPath,
    ) {
        let Some(service) = header.sender().map(ToString::to_string) else {
            tracing::warn!("Ignoring an AppMenu registration from an unnamed sender");
            return;
        };

        let registration = Registration {
            service,
            path: menu.as_str().to_owned(),
        };
        tracing::debug!(
            window,
            service = %registration.service,
            path = %registration.path,
            "Registered an X11 AppMenu"
        );

        let announced = registration.clone();
        self.windows.insert(WindowId(window), registration);

        if let Err(error) =
            Self::window_registered(&emitter, window, &announced.service, &menu).await
        {
            tracing::debug!(%error, "Could not announce an AppMenu registration");
        }
    }

    /// Forgets a window, whether or not it was ever registered.
    #[instrument(
        name = "hyprbaric::global_menu::registrar::unregister",
        skip_all,
        fields(window)
    )]
    async fn unregister_window(
        &self,
        #[zbus(signal_emitter)] emitter: zbus::object_server::SignalEmitter<'_>,
        window: u32,
    ) {
        if self.windows.remove(WindowId(window)).is_none() {
            return;
        }

        tracing::debug!(window, "Unregistered an X11 AppMenu");
        if let Err(error) = Self::window_unregistered(&emitter, window).await {
            tracing::debug!(%error, "Could not announce an AppMenu removal");
        }
    }

    /// Returns the menu registered for one window.
    fn get_menu_for_window(&self, window: u32) -> zbus::fdo::Result<(String, OwnedObjectPath)> {
        let registration = self
            .windows
            .get(WindowId(window))
            .ok_or_else(|| zbus::fdo::Error::Failed(format!("window {window} has no menu")))?;
        let path = OwnedObjectPath::try_from(registration.path.as_str())
            .map_err(|error| zbus::fdo::Error::Failed(error.to_string()))?;

        Ok((registration.service, path))
    }

    /// Returns every registered menu, ordered by window.
    fn get_menus(&self) -> Vec<(u32, String, OwnedObjectPath)> {
        self.windows
            .all()
            .into_iter()
            .filter_map(|(window, registration)| {
                let path = OwnedObjectPath::try_from(registration.path.as_str()).ok()?;
                Some((window.0, registration.service, path))
            })
            .collect()
    }

    #[zbus(signal)]
    async fn window_registered(
        emitter: &zbus::object_server::SignalEmitter<'_>,
        window: u32,
        service: &str,
        menu: &ObjectPath<'_>,
    ) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn window_unregistered(
        emitter: &zbus::object_server::SignalEmitter<'_>,
        window: u32,
    ) -> zbus::Result<()>;
}

/// Removes registrations belonging to clients that left the bus.
///
/// Without this, a crashed application keeps its window in the table and a
/// later window reusing that X11 identifier resolves to a dead service.
#[instrument(name = "hyprbaric::global_menu::registrar::watch", skip_all)]
async fn forget_departed_clients(connection: zbus::Connection, windows: Windows) {
    let proxy = match zbus::fdo::DBusProxy::new(&connection).await {
        Ok(proxy) => proxy,
        Err(error) => {
            tracing::warn!(%error, "Cannot watch for departing AppMenu clients");
            return;
        }
    };

    let mut changes = match proxy.receive_name_owner_changed().await {
        Ok(changes) => changes,
        Err(error) => {
            tracing::warn!(%error, "Cannot watch for departing AppMenu clients");
            return;
        }
    };

    while let Some(change) = changes.next().await {
        let Ok(args) = change.args() else {
            continue;
        };

        if args.new_owner().is_some() {
            continue;
        }

        for window in windows.forget(args.name()) {
            tracing::debug!(
                window = window.0,
                service = %args.name(),
                "Forgot an AppMenu whose client left the bus"
            );
        }
    }
}

/// Registrar failures.
#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("failed to connect to the session bus")]
    Connect(#[source] zbus::Error),
    #[error("failed to serve the AppMenu registrar interface")]
    Serve(#[source] zbus::Error),
    #[error("failed to request the `{NAME}` bus name")]
    RequestName(#[source] zbus::Error),
}

#[cfg(test)]
mod tests {
    use super::{Registration, WindowId, Windows};

    fn registration(service: &str) -> Registration {
        Registration {
            service: service.to_owned(),
            path: "/MenuBar/1".to_owned(),
        }
    }

    #[test]
    fn a_registered_window_resolves_to_its_menu() {
        let windows = Windows::default();
        windows.insert(WindowId(7), registration(":1.42"));

        assert_eq!(windows.get(WindowId(7)), Some(registration(":1.42")));
        assert_eq!(windows.get(WindowId(8)), None);
    }

    #[test]
    fn windows_are_listed_in_identifier_order() {
        let windows = Windows::default();
        windows.insert(WindowId(9), registration(":1.9"));
        windows.insert(WindowId(2), registration(":1.2"));

        assert_eq!(
            windows.all(),
            vec![
                (WindowId(2), registration(":1.2")),
                (WindowId(9), registration(":1.9")),
            ]
        );
    }

    #[test]
    fn a_departing_client_loses_every_window_it_registered() {
        let windows = Windows::default();
        windows.insert(WindowId(1), registration(":1.5"));
        windows.insert(WindowId(2), registration(":1.5"));
        windows.insert(WindowId(3), registration(":1.6"));

        let mut departed = windows.forget(":1.5");
        departed.sort_by_key(|window| window.0);

        assert_eq!(departed, vec![WindowId(1), WindowId(2)]);
        assert_eq!(windows.get(WindowId(3)), Some(registration(":1.6")));
    }
}
