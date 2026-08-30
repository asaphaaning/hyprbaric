//! Hyprland event-listener boundary.

use hyprland::{
    data::{Client, Workspace},
    event_listener::{
        AsyncEventListener, MonitorEventData, WindowEventData, WindowTitleEventData,
        WorkspaceEventData,
    },
    prelude::*,
    shared::WorkspaceType,
};
use tokio::sync::broadcast;
use tracing::instrument;

use super::{
    Error, FocusedWindowSnapshot, WorkspaceOccupancy, WorkspaceSnapshot, focused_window_snapshot,
    occupancy::Occupancy, workspace_snapshot,
};

/// Runs compositor observation until Hyprland closes the event listener.
#[instrument(name = "hyprbaric::hyprland::listener::run", skip_all, fields(%hostname), err)]
pub(super) async fn run(
    workspace_sender: broadcast::Sender<WorkspaceSnapshot>,
    focused_window_sender: broadcast::Sender<FocusedWindowSnapshot>,
    initial_occupancy: WorkspaceOccupancy,
    hostname: String,
) -> Result<(), Error> {
    let mut listener = AsyncEventListener::new();
    let occupancy = Occupancy::spawn(workspace_sender.clone(), initial_occupancy);

    // The switch is published straight away with the occupancy already on
    // hand: the highlight must not wait on a compositor round trip. The
    // refresh that follows corrects the dots a moment later. Per-output
    // state arrives with that refresh; until then the bar renders from the
    // compositor-wide fields, which is exactly right on one monitor.
    let workspace_occupancy = occupancy.clone();
    let workspace_sender_clone = workspace_sender.clone();
    let workspace_window_sender = focused_window_sender.clone();
    let workspace_hostname = hostname.clone();
    listener.add_workspace_changed_handler(move |event: WorkspaceEventData| {
        let sender = workspace_sender_clone.clone();
        let occupancy = workspace_occupancy.clone();
        let window_sender = workspace_window_sender.clone();
        let event_hostname = workspace_hostname.clone();
        Box::pin(async move {
            let (name, is_special) = workspace_name(event.name);
            drop(sender.send(WorkspaceSnapshot::new(
                event.id,
                name,
                is_special,
                occupancy.latest(),
                Vec::new(),
            )));
            occupancy.poke();
            publish_focused_window(window_sender, &event_hostname).await;
        })
    });

    let window_occupancy = occupancy.clone();
    listener.add_window_opened_handler(move |_| {
        let occupancy = window_occupancy.clone();
        Box::pin(async move { occupancy.poke() })
    });

    let window_occupancy = occupancy.clone();
    listener.add_window_closed_handler(move |_| {
        let occupancy = window_occupancy.clone();
        Box::pin(async move { occupancy.poke() })
    });

    let moved_occupancy = occupancy.clone();
    listener.add_window_moved_handler(move |_| {
        let occupancy = moved_occupancy.clone();
        Box::pin(async move { occupancy.poke() })
    });

    // Focusing a workspace that is already visible on another monitor moves the
    // compositor's focus instead of changing a workspace, so Hyprland emits only
    // `focusedmon`. Without this handler the bar keeps showing the previous
    // workspace until the next switch that lands on a hidden one. The poke
    // re-reads the active workspace off the event loop, like every other
    // occupancy refresh.
    let monitor_occupancy = occupancy.clone();
    let monitor_window_sender = focused_window_sender.clone();
    let monitor_hostname = hostname.clone();
    listener.add_active_monitor_changed_handler(move |_event: MonitorEventData| {
        let occupancy = monitor_occupancy.clone();
        let window_sender = monitor_window_sender.clone();
        let event_hostname = monitor_hostname.clone();
        Box::pin(async move {
            occupancy.poke();
            publish_focused_window(window_sender, &event_hostname).await;
        })
    });

    let special_sender = workspace_sender.clone();
    let special_window_sender = focused_window_sender.clone();
    let special_hostname = hostname.clone();
    listener.add_changed_special_handler(move |_| {
        let sender = special_sender.clone();
        let window_sender = special_window_sender.clone();
        let event_hostname = special_hostname.clone();
        Box::pin(async move { refresh_desktop(sender, window_sender, &event_hostname).await })
    });

    let special_sender = workspace_sender.clone();
    let special_window_sender = focused_window_sender.clone();
    let special_hostname = hostname.clone();
    listener.add_special_removed_handler(move |_| {
        let sender = special_sender.clone();
        let window_sender = special_window_sender.clone();
        let event_hostname = special_hostname.clone();
        Box::pin(async move { refresh_desktop(sender, window_sender, &event_hostname).await })
    });

    let monitor_sender = workspace_sender.clone();
    let monitor_window_sender = focused_window_sender.clone();
    let monitor_hostname = hostname.clone();
    listener.add_monitor_added_handler(move |_| {
        let sender = monitor_sender.clone();
        let window_sender = monitor_window_sender.clone();
        let event_hostname = monitor_hostname.clone();
        Box::pin(async move { refresh_desktop(sender, window_sender, &event_hostname).await })
    });

    let monitor_sender = workspace_sender.clone();
    let monitor_window_sender = focused_window_sender.clone();
    let monitor_hostname = hostname.clone();
    listener.add_monitor_removed_handler(move |_| {
        let sender = monitor_sender.clone();
        let window_sender = monitor_window_sender.clone();
        let event_hostname = monitor_hostname.clone();
        Box::pin(async move { refresh_desktop(sender, window_sender, &event_hostname).await })
    });

    let workspace_move_sender = workspace_sender.clone();
    let workspace_move_window_sender = focused_window_sender.clone();
    let workspace_move_hostname = hostname.clone();
    listener.add_workspace_moved_handler(move |_| {
        let sender = workspace_move_sender.clone();
        let window_sender = workspace_move_window_sender.clone();
        let event_hostname = workspace_move_hostname.clone();
        Box::pin(async move { refresh_desktop(sender, window_sender, &event_hostname).await })
    });

    let configuration_sender = workspace_sender.clone();
    let configuration_window_sender = focused_window_sender.clone();
    let configuration_hostname = hostname.clone();
    listener.add_config_reloaded_handler(move || {
        let sender = configuration_sender.clone();
        let window_sender = configuration_window_sender.clone();
        let event_hostname = configuration_hostname.clone();
        Box::pin(async move { refresh_desktop(sender, window_sender, &event_hostname).await })
    });

    let active_window_hostname = hostname.clone();
    let focused_window_sender_clone = focused_window_sender.clone();
    listener.add_active_window_changed_handler(move |event: Option<WindowEventData>| {
        let sender = focused_window_sender_clone.clone();
        let event_hostname = active_window_hostname.clone();
        Box::pin(async move {
            publish_focused_window_with_fallback(sender, event.as_ref(), &event_hostname).await;
        })
    });

    let title_change_hostname = hostname;
    listener.add_window_title_changed_handler(move |_event: WindowTitleEventData| {
        let sender = focused_window_sender.clone();
        let event_hostname = title_change_hostname.clone();
        Box::pin(async move { publish_focused_window(sender, &event_hostname).await })
    });

    listener
        .start_listener_async()
        .await
        .map_err(Error::Listener)
}

/// Re-reads the whole desktop projection after a structural event.
///
/// Special-workspace, monitor and configuration changes can move both the
/// visible workspaces and the focused window. The workspace read degrades
/// rather than failing, like the bootstrap projection.
async fn refresh_desktop(
    workspace_sender: broadcast::Sender<WorkspaceSnapshot>,
    focused_window_sender: broadcast::Sender<FocusedWindowSnapshot>,
    hostname: &str,
) {
    match Workspace::get_active_async().await {
        Ok(workspace) => drop(workspace_sender.send(workspace_snapshot(workspace).await)),
        Err(error) => tracing::warn!(?error, "Failed to refresh the active Hyprland workspace"),
    }
    publish_focused_window(focused_window_sender, hostname).await;
}

async fn publish_focused_window(sender: broadcast::Sender<FocusedWindowSnapshot>, hostname: &str) {
    publish_focused_window_with_fallback(sender, None, hostname).await;
}

async fn publish_focused_window_with_fallback(
    sender: broadcast::Sender<FocusedWindowSnapshot>,
    fallback: Option<&WindowEventData>,
    hostname: &str,
) {
    if let Some(snapshot) = refresh_focused_window(fallback, hostname).await {
        drop(sender.send(snapshot));
    }
}
async fn refresh_focused_window(
    event: Option<&WindowEventData>,
    hostname: &str,
) -> Option<FocusedWindowSnapshot> {
    match Client::get_active_async().await {
        Ok(client) => Some(focused_window_snapshot(client.as_ref(), hostname).await),
        Err(error) => {
            tracing::warn!(?error, "Failed to refresh active client from Hyprland");
            event.map(|value| {
                FocusedWindowSnapshot::new(
                    Some(&value.class),
                    Some(&value.title),
                    hostname,
                    Vec::new(),
                )
            })
        }
    }
}

fn workspace_name(ty: WorkspaceType) -> (String, bool) {
    match ty {
        WorkspaceType::Regular(name) => (name, false),
        WorkspaceType::Special(Some(name)) => (name, true),
        WorkspaceType::Special(None) => ("special".to_owned(), true),
    }
}
