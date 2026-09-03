//! Hyprland event-listener boundary.

use hyprland::{
    event_listener::{AsyncEventListener, WorkspaceEventData},
    shared::WorkspaceType,
};
use tokio::sync::broadcast;
use tracing::instrument;

use super::{
    DesktopSnapshot, Error, WorkspaceSnapshot, is_special_workspace, refresh::Refresh,
};

macro_rules! poke_on {
    ($listener:ident, $method:ident, $refresh:ident) => {{
        let refresh = $refresh.clone();
        $listener.$method(move |_| {
            let refresh = refresh.clone();
            Box::pin(async move { refresh.poke() })
        });
    }};
}

/// Runs compositor observation until Hyprland closes the event listener.
#[instrument(name = "hyprbaric::hyprland::listener::run", skip_all, fields(%hostname), err)]
pub(super) async fn run(
    sender: broadcast::Sender<DesktopSnapshot>,
    hostname: String,
) -> Result<(), Error> {
    let mut listener = AsyncEventListener::new();
    let refresh = Refresh::spawn(sender.clone(), hostname);

    // The switch publishes straight away from the last coherent snapshot:
    // the highlight must not wait on a compositor round trip. Decoration
    // (occupancy, per-output state, focused window) rides along at most one
    // refresh old, and the refresh that follows corrects it a moment later.
    let switch_refresh = refresh.clone();
    let switch_sender = sender.clone();
    listener.add_workspace_changed_handler(move |event: WorkspaceEventData| {
        let refresh = switch_refresh.clone();
        let sender = switch_sender.clone();
        Box::pin(async move {
            let (id, name, is_special) = workspace_projection(&event);
            if let Some(last) = refresh.latest() {
                drop(sender.send(DesktopSnapshot {
                    workspace: WorkspaceSnapshot::new(
                        id,
                        name,
                        is_special,
                        last.workspace.occupied.clone(),
                        last.workspace.monitors.clone(),
                    ),
                    focused_window: last.focused_window.clone(),
                }));
            }
            refresh.poke();
        })
    });
    poke_on!(listener, add_workspace_added_handler, refresh);
    poke_on!(listener, add_workspace_deleted_handler, refresh);
    poke_on!(listener, add_workspace_moved_handler, refresh);
    poke_on!(listener, add_workspace_renamed_handler, refresh);
    poke_on!(listener, add_window_opened_handler, refresh);
    poke_on!(listener, add_window_closed_handler, refresh);
    poke_on!(listener, add_window_moved_handler, refresh);
    poke_on!(listener, add_active_window_changed_handler, refresh);
    poke_on!(listener, add_window_title_changed_handler, refresh);
    poke_on!(listener, add_active_monitor_changed_handler, refresh);
    poke_on!(listener, add_changed_special_handler, refresh);
    poke_on!(listener, add_special_removed_handler, refresh);
    poke_on!(listener, add_monitor_added_handler, refresh);
    poke_on!(listener, add_monitor_removed_handler, refresh);

    let configuration_refresh = refresh.clone();
    listener.add_config_reloaded_handler(move || {
        let refresh = configuration_refresh.clone();
        Box::pin(async move { refresh.poke() })
    });

    listener
        .start_listener_async()
        .await
        .map_err(Error::Listener)
}

/// Splits a workspace-changed event into the id, name and special flag the
/// immediate projection needs. The event path carries the name while other
/// paths carry only the id, so both facts are checked in one place.
fn workspace_projection(event: &WorkspaceEventData) -> (i32, String, bool) {
    let name = match &event.name {
        WorkspaceType::Regular(name) => name.clone(),
        WorkspaceType::Special(name) => name.clone().unwrap_or_else(|| "special".to_owned()),
    };
    let is_special = is_special_workspace(event.id, &name);
    (event.id, name, is_special)
}
