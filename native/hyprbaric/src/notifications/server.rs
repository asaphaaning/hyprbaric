//! Freedesktop notification-server boundary.
//!
//! Hyprbaric hosts `org.freedesktop.Notifications` when the well-known name is
//! free. The server owns protocol IDs and lifetimes while the notification
//! domain owns presentation state.

use std::{
    collections::HashMap,
    sync::{Arc, Mutex},
    time::{SystemTime, UNIX_EPOCH},
};

use tracing::instrument;
use zbus::{Connection, connection::Builder, interface, zvariant::OwnedValue};

use super::{
    Error,
    domain::{Event, Lifetime, NotificationId, Pending, Urgency},
};

const DESTINATION: &str = "org.freedesktop.Notifications";
const PATH: &str = "/org/freedesktop/Notifications";
const SPEC_VERSION: &str = "1.3";

type OnEvent = dyn Fn(Event) + Send + Sync + 'static;

/// Result of trying to host the desktop notification interface.
pub(super) enum Started {
    /// Hyprbaric owns the well-known notification-server name.
    Server(Handle),
    /// Another notification server already owns the well-known name.
    Occupied,
}

/// Live handle retained while Hyprbaric owns the notification-server name.
#[derive(Clone)]
pub(super) struct Handle {
    connection: Connection,
    state: Arc<State>,
}

/// Why a notification was closed, as defined by the Freedesktop protocol.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum CloseReason {
    /// The notification reached its client-requested expiry.
    Expired,
    /// The user dismissed the notification through Hyprbaric.
    Dismissed,
    /// The originating client called `CloseNotification`.
    Requested,
}

#[derive(Default)]
struct Active {
    generations: HashMap<NotificationId, u64>,
    next_generation: u64,
    next_id: u32,
}

struct State {
    active: Mutex<Active>,
    on_event: Arc<OnEvent>,
}

struct Notifications {
    state: Arc<State>,
}

/// Tries to become the session notification server without replacing an
/// existing owner.
#[instrument(name = "hyprbaric::notifications::server::start", skip(on_event), err)]
pub(super) async fn start(
    on_event: impl Fn(Event) + Send + Sync + 'static,
) -> Result<Started, Error> {
    let state = Arc::new(State {
        active: Mutex::new(Active::default()),
        on_event: Arc::new(on_event),
    });
    let interface = Notifications {
        state: Arc::clone(&state),
    };
    let builder = Builder::session()
        .map_err(Error::StartNotificationServer)?
        .serve_at(PATH, interface)
        .map_err(Error::StartNotificationServer)?
        .name(DESTINATION)
        .map_err(Error::StartNotificationServer)?;

    match builder.build().await {
        Ok(connection) => {
            tracing::info!(destination = DESTINATION, "Hosting desktop notifications");
            Ok(Started::Server(Handle { connection, state }))
        }
        Err(zbus::Error::NameTaken) => Ok(Started::Occupied),
        Err(error) => Err(Error::StartNotificationServer(error)),
    }
}

impl Handle {
    /// Closes one server-owned notification as a user dismissal.
    #[instrument(
        name = "hyprbaric::notifications::server::dismiss",
        skip(self),
        fields(notification_id = id.as_u32()),
        err
    )]
    pub(super) async fn dismiss(&self, id: NotificationId) -> Result<bool, Error> {
        close(
            &self.connection,
            &self.state,
            id,
            CloseReason::Dismissed,
            None,
        )
        .await
        .map_err(Error::EmitNotificationClosed)
    }
}

impl State {
    fn receive(
        self: &Arc<Self>,
        connection: Connection,
        replaces_id: Option<NotificationId>,
        pending: Pending,
        lifetime: Lifetime,
    ) -> NotificationId {
        let (id, generation) = {
            let mut active = lock(&self.active);
            let id = active.assign(replaces_id);
            let generation = active.replace(id);
            (id, generation)
        };

        (self.on_event)(Event::Received { id, pending });

        if let Some(duration) = lifetime.duration() {
            let state = Arc::clone(self);
            tokio::spawn(async move {
                tokio::time::sleep(duration).await;
                if let Err(error) = close(
                    &connection,
                    &state,
                    id,
                    CloseReason::Expired,
                    Some(generation),
                )
                .await
                {
                    tracing::warn!(notification_id = id.as_u32(), %error, "Failed to expire notification");
                }
            });
        }

        id
    }

    fn finish(&self, id: NotificationId, generation: Option<u64>) -> bool {
        let removed = {
            let mut active = lock(&self.active);
            active.remove(id, generation)
        };

        if removed {
            (self.on_event)(Event::Closed(id));
        }

        removed
    }
}

impl Active {
    fn assign(&mut self, replaces_id: Option<NotificationId>) -> NotificationId {
        if let Some(id) = replaces_id.filter(|id| self.generations.contains_key(id)) {
            return id;
        }

        loop {
            self.next_id = self.next_id.wrapping_add(1);
            if self.next_id == 0 {
                continue;
            }

            let id = NotificationId::new(self.next_id);
            if !self.generations.contains_key(&id) {
                return id;
            }
        }
    }

    fn replace(&mut self, id: NotificationId) -> u64 {
        self.next_generation = self.next_generation.wrapping_add(1);
        let generation = self.next_generation;
        self.generations.insert(id, generation);
        generation
    }

    fn remove(&mut self, id: NotificationId, generation: Option<u64>) -> bool {
        if generation.is_some_and(|generation| self.generations.get(&id) != Some(&generation)) {
            return false;
        }

        self.generations.remove(&id).is_some()
    }
}

impl CloseReason {
    const fn code(self) -> u32 {
        match self {
            Self::Expired => 1,
            Self::Dismissed => 2,
            Self::Requested => 3,
        }
    }
}

#[interface(name = "org.freedesktop.Notifications")]
impl Notifications {
    /// Returns the optional protocol features implemented by Hyprbaric.
    fn get_capabilities(&self) -> Vec<&str> {
        vec!["body"]
    }

    /// Accepts or replaces one notification.
    #[expect(
        clippy::too_many_arguments,
        reason = "The method signature is fixed by the Freedesktop notification protocol"
    )]
    async fn notify(
        &self,
        app_name: &str,
        replaces_id: u32,
        _app_icon: &str,
        summary: &str,
        body: &str,
        _actions: Vec<&str>,
        hints: HashMap<&str, OwnedValue>,
        expire_timeout: i32,
        #[zbus(connection)] connection: &Connection,
    ) -> u32 {
        let replaces_id = (replaces_id != 0).then(|| NotificationId::new(replaces_id));
        let urgency = hints
            .get("urgency")
            .and_then(|value| u8::try_from(value).ok())
            .map(Urgency::from_hint)
            .unwrap_or_default();
        let pending = Pending::new(app_name, summary, body, replaces_id, now_unix_ms(), urgency);

        self.state
            .receive(
                connection.clone(),
                replaces_id,
                pending,
                Lifetime::from_milliseconds(expire_timeout),
            )
            .as_u32()
    }

    /// Closes one notification at the originating client's request.
    async fn close_notification(
        &self,
        id: u32,
        #[zbus(connection)] connection: &Connection,
    ) -> zbus::fdo::Result<()> {
        let id = NotificationId::new(id);
        let removed = close(connection, &self.state, id, CloseReason::Requested, None)
            .await
            .map_err(|error| zbus::fdo::Error::Failed(error.to_string()))?;

        if removed {
            Ok(())
        } else {
            Err(zbus::fdo::Error::InvalidArgs(format!(
                "Unknown notification ID {}",
                id.as_u32()
            )))
        }
    }

    /// Identifies the active notification server.
    #[zbus(out_args("name", "vendor", "version", "spec_version"))]
    fn get_server_information(&self) -> (&str, &str, &str, &str) {
        (
            "Hyprbaric",
            "Hyprbaric",
            env!("CARGO_PKG_VERSION"),
            SPEC_VERSION,
        )
    }

    /// Reports that a notification is no longer active.
    #[zbus(signal)]
    async fn notification_closed(
        signal_emitter: &zbus::object_server::SignalEmitter<'_>,
        id: u32,
        reason: u32,
    ) -> zbus::Result<()>;

    /// Reports activation of a notification action.
    #[zbus(signal)]
    async fn action_invoked(
        signal_emitter: &zbus::object_server::SignalEmitter<'_>,
        id: u32,
        action_key: &str,
    ) -> zbus::Result<()>;
}

async fn close(
    connection: &Connection,
    state: &State,
    id: NotificationId,
    reason: CloseReason,
    generation: Option<u64>,
) -> zbus::Result<bool> {
    if !state.finish(id, generation) {
        return Ok(false);
    }

    let interface = connection
        .object_server()
        .interface::<_, Notifications>(PATH)
        .await?;
    interface
        .notification_closed(id.as_u32(), reason.code())
        .await?;
    Ok(true)
}

fn lock<T>(value: &Mutex<T>) -> std::sync::MutexGuard<'_, T> {
    value.lock().unwrap_or_else(|poison| poison.into_inner())
}

fn now_unix_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64
}

#[cfg(test)]
mod tests {
    use super::{Active, NotificationId};

    #[test]
    fn ids_are_nonzero_and_reuse_only_live_replacements() {
        let mut active = Active::default();
        let first = active.assign(None);
        active.replace(first);

        assert_eq!(first, NotificationId::new(1));
        assert_eq!(active.assign(Some(first)), first);

        active.remove(first, None);
        assert_eq!(active.assign(Some(first)), NotificationId::new(2));
    }

    #[test]
    fn stale_expiry_does_not_close_a_replacement() {
        let mut active = Active::default();
        let id = active.assign(None);
        let old_generation = active.replace(id);
        let new_generation = active.replace(id);

        assert!(!active.remove(id, Some(old_generation)));
        assert!(active.remove(id, Some(new_generation)));
    }

    #[test]
    fn id_allocation_skips_zero_after_wrapping() {
        let mut active = Active {
            next_id: u32::MAX,
            ..Active::default()
        };

        assert_eq!(active.assign(None), NotificationId::new(1));
    }
}
