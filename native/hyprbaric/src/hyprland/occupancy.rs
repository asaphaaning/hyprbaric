//! Off-event-loop workspace occupancy refresh.
//!
//! Hyprland delivers events sequentially and awaits each handler before
//! reading the next one, so any IPC performed inside a handler stalls every
//! later event. Handlers therefore only poke [`Occupancy`], which coalesces
//! bursts and owns the single writer that queries the compositor.

use std::{
    sync::{Arc, Mutex},
    time::Duration,
};

use hyprland::{data::Workspace, prelude::*};
use tokio::{
    sync::{broadcast, mpsc},
    time::sleep,
};

use super::{
    WorkspaceOccupancy, WorkspaceSnapshot, is_special_workspace, monitor_workspaces,
    workspace_occupancy,
};

/// How long a burst of window events is allowed to settle before one refresh.
///
/// Restoring a session opens many windows at once. Without this, every one of
/// them would cost two compositor round trips.
const DEBOUNCE: Duration = Duration::from_millis(80);

/// Coalescing handle to the occupancy refresh task.
#[derive(Clone)]
pub(super) struct Occupancy {
    latest: Arc<Mutex<WorkspaceOccupancy>>,
    requests: mpsc::Sender<()>,
}

impl Occupancy {
    /// Starts the refresh task and returns its handle.
    pub(super) fn spawn(
        sender: broadcast::Sender<WorkspaceSnapshot>,
        initial: WorkspaceOccupancy,
    ) -> Self {
        // One slot is the whole coalescing policy: a queued request already
        // means "read the compositor again", so a second one adds nothing.
        let (requests, mut inbox) = mpsc::channel(1);
        let occupancy = Self {
            latest: Arc::new(Mutex::new(initial)),
            requests,
        };

        let task = occupancy.clone();
        tokio::spawn(async move {
            while inbox.recv().await.is_some() {
                sleep(DEBOUNCE).await;
                while inbox.try_recv().is_ok() {}
                task.refresh(&sender).await;
            }
        });

        occupancy
    }

    /// Returns the most recently observed occupancy.
    pub(super) fn latest(&self) -> WorkspaceOccupancy {
        lock(&self.latest).clone()
    }

    /// Asks for a refresh without blocking the caller.
    pub(super) fn poke(&self) {
        // A full queue already carries the same request.
        let _ = self.requests.try_send(());
    }

    async fn refresh(&self, sender: &broadcast::Sender<WorkspaceSnapshot>) {
        let workspace = match Workspace::get_active_async().await {
            Ok(workspace) => workspace,
            Err(error) => {
                tracing::warn!(?error, "Failed to refresh the active Hyprland workspace");
                return;
            }
        };

        // Occupancy is decoration. When it cannot be read, the last known set
        // is reused so the active-workspace update still reaches the bar.
        let occupancy = match workspace_occupancy().await {
            Ok(occupancy) => {
                lock(&self.latest).clone_from(&occupancy);
                occupancy
            }
            Err(error) => {
                tracing::warn!(?error, "Failed to refresh Hyprland workspace occupancy");
                self.latest()
            }
        };

        let is_special = is_special_workspace(workspace.id, &workspace.name);
        let monitors = monitor_workspaces().await.unwrap_or_else(|error| {
            tracing::warn!(?error, 'Failed to refresh Hyprland monitor workspaces');
            Vec::new()
        });
        drop(sender.send(WorkspaceSnapshot::new(
            workspace.id,
            workspace.name,
            is_special,
            occupancy,
            monitors,
        )));
    }
}

fn lock<T>(value: &Mutex<T>) -> std::sync::MutexGuard<'_, T> {
    value.lock().unwrap_or_else(|poison| poison.into_inner())
}
