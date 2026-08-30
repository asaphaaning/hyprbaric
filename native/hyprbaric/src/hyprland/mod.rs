use std::{fs, path::Path};

use hyprland::{
    data::{Client, Clients, Monitors, Transforms, Workspace, Workspaces},
    dispatch::{Dispatch, DispatchType, WorkspaceIdentifierWithSpecial},
    error::HyprError,
    prelude::*,
};
use tokio::sync::broadcast;
use tracing::instrument;

mod domain;
mod listener;
mod occupancy;

pub use domain::{
    Command, DisplayedWorkspace, FocusedWindowSnapshot, MonitorFocusedWindow, MonitorWorkspace,
    OutputGeometry, OutputTransform, WorkspaceOccupancy, WorkspaceSnapshot, WorkspaceTarget,
};

/// Live Hyprland desktop observation.
pub struct Desktop {
    workspace_events: broadcast::Sender<WorkspaceSnapshot>,
    focused_window_events: broadcast::Sender<FocusedWindowSnapshot>,
    initial_occupancy: WorkspaceOccupancy,
    hostname: String,
}

impl Desktop {
    /// Connects to Hyprland and reads the initial desktop projection.
    #[instrument(skip_all, err)]
    pub async fn connect() -> Result<(Self, WorkspaceSnapshot, FocusedWindowSnapshot), Error> {
        let initial_workspace = Workspace::get_active_async()
            .await
            .map_err(Error::ActiveWorkspace)?;
        let snapshot = workspace_snapshot(initial_workspace).await;
        let hostname = resolve_hostname();
        let initial_client = Client::get_active_async()
            .await
            .map_err(Error::ActiveClient)?;
        let focused_window = focused_window_snapshot(initial_client.as_ref(), &hostname).await;
        let (workspace_tx, _) = broadcast::channel(32);
        let (focused_window_tx, _) = broadcast::channel(32);

        Ok((
            Self {
                workspace_events: workspace_tx,
                focused_window_events: focused_window_tx,
                initial_occupancy: snapshot.occupied.clone(),
                hostname,
            },
            snapshot,
            focused_window,
        ))
    }

    /// Runs Hyprland event observation until its event listener stops.
    #[instrument(name = "hyprbaric::hyprland::listen", skip(self), err)]
    pub async fn listen(&self) -> Result<(), Error> {
        listener::run(
            self.workspace_events.clone(),
            self.focused_window_events.clone(),
            self.initial_occupancy.clone(),
            self.hostname.clone(),
        )
        .await
    }

    /// Subscribes to active workspace updates.
    pub fn subscribe_workspace(&self) -> broadcast::Receiver<WorkspaceSnapshot> {
        self.workspace_events.subscribe()
    }

    /// Subscribes to focused-window updates.
    pub fn subscribe_focused_window(&self) -> broadcast::Receiver<FocusedWindowSnapshot> {
        self.focused_window_events.subscribe()
    }

    /// Executes a typed compositor command at the Hyprland boundary.
    #[instrument(skip(self), err)]
    pub async fn dispatch(&self, command: Command) -> Result<(), Error> {
        let identifier = match command {
            Command::SwitchWorkspace(WorkspaceTarget::Relative(offset)) => {
                WorkspaceIdentifierWithSpecial::Relative(offset)
            }
            Command::SwitchWorkspace(WorkspaceTarget::Absolute(id)) => {
                WorkspaceIdentifierWithSpecial::Id(id.get())
            }
        };
        let lua_dispatch = lua_workspace_dispatch(identifier);

        match Dispatch::call_async(DispatchType::Workspace(identifier)).await {
            Ok(()) => Ok(()),
            Err(error) if requires_lua_dispatch(&error) => {
                tracing::debug!(%lua_dispatch, "Retrying workspace dispatch with Lua syntax");
                Dispatch::call_async(DispatchType::Custom(&lua_dispatch, ""))
                    .await
                    .map_err(Error::Dispatch)
            }
            Err(error) => Err(Error::Dispatch(error)),
        }
    }
}

/// Reads one workspace projection, degrading rather than failing.
///
/// Occupancy and per-output state are decoration on the workspace strip. A
/// compositor that cannot answer either query must not be able to abort
/// startup, so unreadable sets become empty ones.
async fn workspace_snapshot(workspace: Workspace) -> WorkspaceSnapshot {
    let occupancy = workspace_occupancy().await.unwrap_or_else(|error| {
        tracing::warn!(
            ?error,
            "Failed to read Hyprland workspace occupancy; starting without it"
        );
        WorkspaceOccupancy::default()
    });
    let monitors = monitor_workspaces().await.unwrap_or_else(|error| {
        tracing::warn!(
            ?error,
            "Failed to read Hyprland monitor workspaces; starting without them"
        );
        Vec::new()
    });
    let is_special = is_special_workspace(workspace.id, &workspace.name);

    WorkspaceSnapshot::new(
        workspace.id,
        workspace.name,
        is_special,
        occupancy,
        monitors,
    )
}

/// Decides whether a workspace is a special workspace.
///
/// Both facts are checked because the two event paths carry different data:
/// Hyprland gives special workspaces a negative ID and a `special` name
/// prefix, and deriving the flag from only one of them let the same workspace
/// arrive flagged differently depending on which event produced it.
pub(super) fn is_special_workspace(id: i32, name: &str) -> bool {
    id < 0 || name.starts_with("special")
}

/// Reads what each connected output is currently displaying.
pub(super) async fn monitor_workspaces() -> Result<Vec<MonitorWorkspace>, HyprError> {
    Ok(Monitors::get_async()
        .await?
        .into_iter()
        .map(|monitor| {
            let workspace = if monitor.special_workspace.id < 0 {
                DisplayedWorkspace::special(
                    monitor.special_workspace.id,
                    monitor.special_workspace.name,
                )
            } else {
                DisplayedWorkspace::regular(
                    monitor.active_workspace.id,
                    monitor.active_workspace.name,
                )
            };
            let geometry = OutputGeometry::from_physical(
                monitor.x,
                monitor.y,
                monitor.width.into(),
                monitor.height.into(),
                monitor.scale,
                output_transform(monitor.transform),
            );

            MonitorWorkspace::new(
                monitor.name,
                workspace,
                monitor.focused,
                geometry,
                monitor.refresh_rate,
            )
        })
        .collect())
}

fn output_transform(transform: Transforms) -> OutputTransform {
    match transform {
        Transforms::Normal => OutputTransform::Normal,
        Transforms::Normal90 => OutputTransform::Rotated90,
        Transforms::Normal180 => OutputTransform::Rotated180,
        Transforms::Normal270 => OutputTransform::Rotated270,
        Transforms::Flipped => OutputTransform::Flipped,
        Transforms::Flipped90 => OutputTransform::Flipped90,
        Transforms::Flipped180 => OutputTransform::Flipped180,
        Transforms::Flipped270 => OutputTransform::Flipped270,
    }
}

pub(super) async fn workspace_occupancy() -> Result<WorkspaceOccupancy, HyprError> {
    Ok(WorkspaceOccupancy::from_occupied_ids(
        Workspaces::get_async()
            .await?
            .into_iter()
            .filter(|workspace| workspace.windows > 0)
            .map(|workspace| workspace.id),
    ))
}

/// Formats a workspace command for Hyprland's Lua-config IPC mode.
fn lua_workspace_dispatch(identifier: WorkspaceIdentifierWithSpecial<'_>) -> String {
    format!("hl.dsp.focus({{ workspace = \"{identifier}\" }})")
}

/// Detects Hyprland's explicit legacy-dispatch rejection in Lua config mode.
fn requires_lua_dispatch(error: &HyprError) -> bool {
    matches!(error, HyprError::NotOkDispatch(message) if message.contains("dispatch in lua"))
}

pub(super) async fn focused_window_snapshot(
    client: Option<&Client>,
    hostname: &str,
) -> FocusedWindowSnapshot {
    let monitors = match monitor_focused_windows().await {
        Ok(monitors) => monitors,
        Err(error) => {
            tracing::warn!(
                ?error,
                "Failed to project focused clients per Hyprland monitor"
            );
            Vec::new()
        }
    };

    FocusedWindowSnapshot::new(
        client.map(|value| value.class.as_str()),
        client.map(|value| value.title.as_str()),
        hostname,
        monitors,
    )
}

async fn monitor_focused_windows() -> Result<Vec<MonitorFocusedWindow>, HyprError> {
    let monitors = Monitors::get_async().await?;
    let clients = Clients::get_async().await?;

    Ok(monitors
        .into_iter()
        .map(|monitor| {
            let workspace_id = if monitor.special_workspace.id < 0 {
                monitor.special_workspace.id
            } else {
                monitor.active_workspace.id
            };
            let client = clients
                .iter()
                .filter(|client| {
                    client.mapped
                        && client.monitor == Some(monitor.id)
                        && client.workspace.id == workspace_id
                })
                .min_by_key(|client| client.focus_history_id);

            MonitorFocusedWindow::new(
                monitor.name,
                client.map(|client| client.class.as_str()),
                client.map(|client| client.title.as_str()),
            )
        })
        .collect())
}

fn resolve_hostname() -> String {
    const DEFAULT_HOSTNAME: &str = "Hyprbaric";
    let candidates = [
        Path::new("/proc/sys/kernel/hostname"),
        Path::new("/etc/hostname"),
    ];

    read_hostname_from_paths(&candidates).unwrap_or_else(|| DEFAULT_HOSTNAME.to_string())
}

fn read_hostname_from_paths(paths: &[&Path]) -> Option<String> {
    paths.iter().find_map(|path| {
        let value = fs::read_to_string(path).ok()?;
        let trimmed = value.trim();
        if trimmed.is_empty() {
            None
        } else {
            Some(trimmed.to_string())
        }
    })
}

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("failed to fetch the active Hyprland workspace")]
    ActiveWorkspace(#[source] HyprError),
    #[error("failed to fetch the active Hyprland client")]
    ActiveClient(#[source] HyprError),
    #[error("failed to start the Hyprland event listener")]
    Listener(#[source] HyprError),
    #[error("failed to dispatch a Hyprland command: {0}")]
    Dispatch(#[source] HyprError),
}

#[cfg(test)]
mod tests {
    use super::{
        is_special_workspace, lua_workspace_dispatch, read_hostname_from_paths,
        requires_lua_dispatch,
    };
    use hyprland::{dispatch::WorkspaceIdentifierWithSpecial, error::HyprError};
    use std::{
        fs,
        path::{Path, PathBuf},
        time::{SystemTime, UNIX_EPOCH},
    };

    fn unique_path(name: &str) -> PathBuf {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|value| value.as_nanos())
            .unwrap_or_default();
        std::env::temp_dir().join(format!("hyprbaric-{name}-{nanos}.tmp"))
    }

    #[test]
    fn special_workspaces_are_recognized_from_either_event_shape() {
        // The workspace-changed event carries the name, the occupancy refresh
        // carries the ID. Both have to reach the same verdict.
        assert!(is_special_workspace(-99, "special:magic"));
        assert!(is_special_workspace(-99, "magic"));
        assert!(is_special_workspace(3, "special:magic"));
        assert!(!is_special_workspace(3, "3"));
    }

    #[test]
    fn read_hostname_uses_first_non_empty_file() {
        let empty_path = unique_path("empty-hostname");
        let valid_path = unique_path("valid-hostname");
        fs::write(&empty_path, "\n").expect("failed to write empty hostname file");
        fs::write(&valid_path, "workstation\n").expect("failed to write hostname file");

        let paths: [&Path; 2] = [&empty_path, &valid_path];
        let hostname = read_hostname_from_paths(&paths);

        let _ = fs::remove_file(&empty_path);
        let _ = fs::remove_file(&valid_path);

        assert_eq!(hostname.as_deref(), Some("workstation"));
    }

    #[test]
    fn read_hostname_returns_none_when_all_candidates_fail() {
        let missing = unique_path("missing-hostname");
        let paths: [&Path; 1] = [&missing];

        assert_eq!(read_hostname_from_paths(&paths), None);
    }

    #[test]
    fn formats_relative_workspace_for_lua_dispatch() {
        assert_eq!(
            lua_workspace_dispatch(WorkspaceIdentifierWithSpecial::Relative(1)),
            "hl.dsp.focus({ workspace = \"+1\" })"
        );
    }

    #[test]
    fn recognizes_the_lua_dispatch_migration_error() {
        assert!(requires_lua_dispatch(&HyprError::NotOkDispatch(
            "Note: dispatch in lua is a shorthand".to_owned()
        )));
        assert!(!requires_lua_dispatch(&HyprError::NotOkDispatch(
            "invalid workspace".to_owned()
        )));
    }
}
