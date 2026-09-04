//! Freedesktop notification center.
//!
//! [`Center`] owns the live notification model exposed to Flutter. The domain
//! module owns notification state transitions, server owns the preferred D-Bus
//! service, monitor and backend own compatibility with an existing service,
//! and signal owns RINF projection.

mod backend;
mod domain;
mod monitor;
mod server;
mod signal;

use std::sync::{Arc, Mutex, RwLock};

use tokio::sync::broadcast;
use tracing::instrument;

pub use domain::{Command, Entry, Event, NotificationId, Snapshot, Urgency};

pub type Handle = Arc<Center>;

/// Live notification-center state.
#[derive(Clone)]
pub struct Center {
    events: broadcast::Sender<Snapshot>,
    snapshot: Arc<RwLock<Snapshot>>,
    model: Arc<Mutex<domain::Model>>,
    runtime: Arc<RwLock<Runtime>>,
}

/// Active notification integration selected during bootstrap.
#[derive(Clone)]
enum Runtime {
    /// Notification integration is being selected during bootstrap.
    Starting,
    /// Hyprbaric owns and serves `org.freedesktop.Notifications`.
    Server(server::Handle),
    /// Hyprbaric observes a notification server already owned by another process.
    Observer,
    /// Neither the built-in server nor compatibility observation is usable.
    Unavailable,
}

impl Center {
    /// Selects a notification integration and returns the first snapshot.
    #[instrument(skip_all)]
    pub async fn bootstrap() -> (Handle, Snapshot) {
        let (events, _) = broadcast::channel(32);
        let initial_snapshot = Snapshot::empty();
        let center = Arc::new(Self {
            events,
            snapshot: Arc::new(RwLock::new(initial_snapshot.clone())),
            model: Arc::new(Mutex::new(domain::Model::default())),
            runtime: Arc::new(RwLock::new(Runtime::Starting)),
        });

        let center_for_server = Arc::clone(&center);
        match server::start(move |event| center_for_server.accept(event)).await {
            Ok(server::Started::Server(server)) => {
                center.set_runtime(Runtime::Server(server));
                (center, initial_snapshot)
            }
            Ok(server::Started::Occupied) => center.start_observer(initial_snapshot),
            Err(error) => {
                tracing::warn!(%error, "Built-in notification server failed; trying observer mode");
                center.start_observer(initial_snapshot)
            }
        }
    }

    /// Subscribes to published notification snapshots.
    pub fn subscribe(&self) -> broadcast::Receiver<Snapshot> {
        self.events.subscribe()
    }

    /// Applies a notification command.
    #[instrument(skip(self))]
    pub async fn apply(self: &Arc<Self>, command: Command) {
        match command {
            Command::Dismiss(id) => self.dismiss(id).await,
            Command::Clear => self.clear().await,
            Command::SetDoNotDisturb(enabled) => self.set_dnd(enabled),
        }
    }

    /// Dismisses one notification optimistically.
    #[instrument(skip(self), fields(notification_id = id.as_u32()))]
    pub async fn dismiss(self: &Arc<Self>, id: NotificationId) {
        match self.read_runtime() {
            Runtime::Server(server) => {
                if let Err(error) = server.dismiss(id).await {
                    tracing::warn!("Notification dismiss failed for {}: {error}", id.as_u32());
                }
            }
            Runtime::Observer => {
                if let Err(error) = backend::close(id).await {
                    tracing::warn!("Notification dismiss failed for {}: {error}", id.as_u32());
                }
            }
            Runtime::Starting | Runtime::Unavailable => {
                tracing::warn!(
                    notification_id = id.as_u32(),
                    "Notification integration is unavailable; dismissing locally"
                );
            }
        }
        self.forget(id);
    }

    /// Clears the visible notification list optimistically.
    #[instrument(skip(self))]
    pub async fn clear(self: &Arc<Self>) {
        let ids = self
            .read_snapshot()
            .entries
            .iter()
            .map(|entry| entry.id)
            .collect::<Vec<_>>();
        for id in ids {
            self.dismiss(id).await;
        }
    }

    /// Toggles Hyprbaric's do-not-disturb mode.
    #[instrument(skip(self), fields(enabled))]
    pub fn set_dnd(self: &Arc<Self>, enabled: bool) {
        let transition = {
            let mut model = lock_mutex(&self.model);
            model.set_dnd(enabled)
        };
        self.settle(transition);
    }

    fn accept(self: &Arc<Self>, event: Event) {
        let transition = {
            let mut model = lock_mutex(&self.model);
            model.apply(event)
        };
        self.settle(transition);
    }

    fn forget(self: &Arc<Self>, id: NotificationId) {
        let transition = {
            let mut model = lock_mutex(&self.model);
            model.dismiss(id)
        };
        self.settle(transition);
    }

    /// Publishes one transition and retires whatever the model stopped showing.
    ///
    /// Only the hosted server is reconciled. In observer mode the IDs belong to
    /// another daemon that is still displaying them in its own UI, and Hyprbaric
    /// holds no protocol state of its own to leak, so silently closing them
    /// there would reach into a surface it does not own.
    fn settle(self: &Arc<Self>, transition: domain::Transition) {
        if let Some(snapshot) = transition.snapshot {
            self.publish(snapshot);
        }
        if transition.closed.is_empty() {
            return;
        }
        let Runtime::Server(server) = self.read_runtime() else {
            return;
        };
        for id in transition.closed {
            let server = server.clone();
            tokio::spawn(async move {
                if let Err(error) = server.retire(id).await {
                    tracing::warn!(
                        notification_id = id.as_u32(),
                        %error,
                        "Failed to retire a notification the center dropped"
                    );
                }
            });
        }
    }

    fn publish(&self, snapshot: Snapshot) {
        write_lock(&self.snapshot).clone_from(&snapshot);
        drop(self.events.send(snapshot));
    }

    fn start_observer(self: &Arc<Self>, initial_snapshot: Snapshot) -> (Handle, Snapshot) {
        let center_for_monitor = Arc::clone(self);
        match monitor::spawn(move |event| center_for_monitor.accept(event)) {
            Ok(()) => {
                tracing::info!("Observing the existing desktop notification server");
                self.set_runtime(Runtime::Observer);
                (Arc::clone(self), initial_snapshot)
            }
            Err(error) => {
                tracing::warn!("Notification bootstrap failed: {error}");
                self.set_runtime(Runtime::Unavailable);
                let snapshot = Snapshot::unavailable(error.to_string());
                self.publish(snapshot.clone());
                (Arc::clone(self), snapshot)
            }
        }
    }

    fn set_runtime(&self, runtime: Runtime) {
        *write_lock(&self.runtime) = runtime;
    }

    fn read_runtime(&self) -> Runtime {
        read_lock(&self.runtime).clone()
    }

    fn read_snapshot(&self) -> Snapshot {
        read_lock(&self.snapshot).clone()
    }
}

fn lock_mutex<T>(value: &Mutex<T>) -> std::sync::MutexGuard<'_, T> {
    value.lock().unwrap_or_else(|poison| poison.into_inner())
}

fn read_lock<T>(value: &RwLock<T>) -> std::sync::RwLockReadGuard<'_, T> {
    value.read().unwrap_or_else(|poison| poison.into_inner())
}

fn write_lock<T>(value: &RwLock<T>) -> std::sync::RwLockWriteGuard<'_, T> {
    value.write().unwrap_or_else(|poison| poison.into_inner())
}

/// Notification subsystem failures.
#[derive(Debug, thiserror::Error)]
pub enum Error {
    /// The session bus could not be reached for monitoring.
    #[error("failed to connect to the session bus")]
    ConnectSessionBus(#[source] dbus::Error),
    /// The D-Bus connection could not become a monitor.
    #[error("failed to convert the D-Bus connection into a monitor")]
    BecomeMonitor(#[source] dbus::Error),
    /// The monitor thread could not be spawned.
    #[error("failed to spawn the notification watcher thread")]
    SpawnWatcher(#[source] std::io::Error),
    /// The session bus could not be reached for commands.
    #[error("failed to connect to the session bus for notification commands")]
    ConnectSessionBusZbus(#[source] zbus::Error),
    /// The notification-daemon command proxy could not be created.
    #[error("failed to create the notifications proxy")]
    CreateNotificationsProxy(#[source] zbus::Error),
    /// The notification-daemon close command failed.
    #[error("failed to close notification {0}")]
    CloseNotification(#[source] zbus::Error),
    /// Hyprbaric could not host the Freedesktop notification interface.
    #[error("failed to start Hyprbaric's notification server")]
    StartNotificationServer(#[source] zbus::Error),
    /// Hyprbaric could not publish a notification closure signal.
    #[error("failed to emit NotificationClosed")]
    EmitNotificationClosed(#[source] zbus::Error),
}
