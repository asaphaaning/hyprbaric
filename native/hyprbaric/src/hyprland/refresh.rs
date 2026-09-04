//! Off-event-loop desktop refresh.
//!
//! Hyprland delivers events sequentially and awaits each handler before
//! reading the next one, so any IPC performed inside a handler stalls every
//! later event. Handlers therefore only poke [`Refresh`], which coalesces
//! bursts and owns the single writer that publishes coherent snapshots.

use std::{
    sync::{Arc, Mutex},
    time::Duration,
};

use tokio::{
    sync::{broadcast, mpsc},
    time::sleep,
};

use super::{DesktopSnapshot, desktop_snapshot};

/// How long a burst of events is allowed to settle before one refresh.
///
/// Restoring a session opens many windows at once. Without this, every one of
/// them would cost a full coherent re-read.
const DEBOUNCE: Duration = Duration::from_millis(80);

/// Coalescing handle to the desktop refresh task.
#[derive(Clone)]
pub(super) struct Refresh {
    latest: Arc<Mutex<Option<DesktopSnapshot>>>,
    hostname: String,
    requests: mpsc::Sender<()>,
}

impl Refresh {
    /// Starts the refresh task and returns its handle.
    pub(super) fn spawn(sender: broadcast::Sender<DesktopSnapshot>, hostname: String) -> Self {
        // One slot is the whole coalescing policy: a queued request already
        // means "read the compositor again", so a second one adds nothing.
        let (requests, mut inbox) = mpsc::channel(1);
        let refresh = Self {
            latest: Arc::new(Mutex::new(None)),
            hostname,
            requests,
        };

        let task = refresh.clone();
        tokio::spawn(async move {
            while inbox.recv().await.is_some() {
                sleep(DEBOUNCE).await;
                while inbox.try_recv().is_ok() {}
                task.refresh(&sender).await;
            }
        });

        refresh
    }

    /// Returns the most recently published snapshot, if any refresh has
    /// completed since this task spawned.
    pub(super) fn latest(&self) -> Option<DesktopSnapshot> {
        lock(&self.latest).clone()
    }

    /// Asks for a refresh without blocking the caller.
    pub(super) fn poke(&self) {
        // A full queue already carries the same request.
        let _ = self.requests.try_send(());
    }

    async fn refresh(&self, sender: &broadcast::Sender<DesktopSnapshot>) {
        match desktop_snapshot(&self.hostname).await {
            Ok(snapshot) => {
                lock(&self.latest).replace(snapshot.clone());
                drop(sender.send(snapshot));
            }
            Err(error) => {
                tracing::warn!(?error, "Failed to refresh coherent Hyprland desktop state");
            }
        }
    }
}

fn lock<T>(value: &Mutex<T>) -> std::sync::MutexGuard<'_, T> {
    value.lock().unwrap_or_else(|poison| poison.into_inner())
}
