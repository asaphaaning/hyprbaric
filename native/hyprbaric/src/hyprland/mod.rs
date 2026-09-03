use std::{fs, path::Path};

use hyprland::{
    data::{Client, Clients, Monitor, Monitors, Transforms, Workspace, Workspaces},
    dispatch::{Dispatch, DispatchType, MonitorIdentifier, WorkspaceIdentifierWithSpecial},
    error::HyprError,
    prelude::*,
};
use tokio::sync::broadcast;
use tracing::instrument;

mod domain;
mod listener;
mod refresh;

pub use domain::{
    Command, DesktopSnapshot, DisplayedWorkspace, FocusedWindowSnapshot, MonitorFocusedWindow,
    MonitorWorkspace, OutputGeometry, OutputName, OutputTransform, WorkspaceOccupancy,
    WorkspaceSnapshot, WorkspaceTarget,
};

/// Live Hyprland desktop observation.
pub struct Desktop {
    events: broadcast::Sender<DesktopSnapshot>,
    hostname: String,
}

impl Desktop {
    /// Connects to Hyprland and reads the initial desktop projection.
    #[instrument(skip_all)]
    pub async fn connect() -> Result<(Self, DesktopSnapshot), Error> {
        let hostname = resolve_hostname();
        let snapshot = desktop_snapshot(&hostname).await.map_err(Error::Snapshot)?;
        let (events, _) = broadcast::channel(32);

        Ok((Self { events, hostname }, snapshot))
    }

    /// Runs Hyprland event observation until its event listener stops.
    #[instrument(name = "hyprbaric::hyprland::listen", skip(self), err)]
    pub async fn listen(&self) -> Result<(), Error> {
        listener::run(self.events.clone(), self.hostname.clone()).await
    }

    /// Subscribes to coherent desktop updates.
    pub fn subscribe(&self) -> broadcast::Receiver<DesktopSnapshot> {
        self.events.subscribe()
    }

    /// Executes a typed compositor command at the Hyprland boundary.
    #[instrument(skip(self), err)]
    pub async fn dispatch(&self, command: Command) -> Result<(), Error> {
        let (target, output) = match command {
            Command::SwitchWorkspace { target, output } => (target, output),
        };
        let identifier = match target {
            WorkspaceTarget::Relative(offset) => WorkspaceIdentifierWithSpecial::Relative(offset),
            WorkspaceTarget::Absolute(id) => WorkspaceIdentifierWithSpecial::Id(id.get()),
        };
        if let Some(output) = output.as_ref() {
            focus_output(output).await.map_err(Error::Dispatch)?;
        }
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

/// Reads one coherent desktop projection, degrading rather than failing.
///
/// Occupancy, per-output state and focused-window decoration must not be able
/// to abort startup (or a refresh): a compositor that cannot answer those
/// queries yields empty sets while the focused workspace itself still lands.
/// Only the active workspace read is fatal, without which there is nothing
/// to display.
/// Focuses an output, including Hyprland's Lua-config dispatcher syntax.
async fn focus_output(output: &OutputName) -> Result<(), HyprError> {
    match Dispatch::call_async(DispatchType::FocusMonitor(MonitorIdentifier::Name(
        output.as_str(),
    )))
    .await
    {
        Ok(()) => Ok(()),
        Err(error) if requires_lua_dispatch(&error) => {
            let lua_dispatch = lua_output_focus_dispatch(output);
            tracing::debug!(%lua_dispatch, "Retrying output focus dispatch with Lua syntax");
            Dispatch::call_async(DispatchType::Custom(&lua_dispatch, "")).await
        }
        Err(error) => Err(error),
    }
}

async fn desktop_snapshot(hostname: &str) -> Result<DesktopSnapshot, HyprError> {
    let workspace = Workspace::get_active_async().await?;
    let workspaces = Workspaces::get_async()
        .await
        .map(HyprDataVec::to_vec)
        .unwrap_or_else(|error| {
            tracing::warn!(?error, "Failed to read Hyprland workspaces; starting without occupancy");
            Vec::new()
        });
    let monitors = Monitors::get_async()
        .await
        .map(|monitors| {
            monitors.into_iter().filter(|monitor| !monitor.disabled).collect::<Vec<_>>()
        })
        .unwrap_or_else(|error| {
            tracing::warn!(?error, "Failed to read Hyprland monitors; starting without them");
            Vec::new()
        });
    let active_client = Client::get_active_async().await.ok().flatten();
    let clients = Clients::get_async()
        .await
        .map(|clients| clients.into_iter().collect::<Vec<_>>())
        .unwrap_or_else(|error| {
            tracing::warn!(?error, "Failed to read Hyprland clients; starting without them");
            Vec::new()
        });
    let occupied = WorkspaceOccupancy::from_occupied_ids(
        workspaces
            .into_iter()
            .filter(|workspace| workspace.windows > 0)
            .map(|workspace| workspace.id),
    );
    let focused_window =
        focused_window_snapshot(active_client.as_ref(), hostname, &monitors, &clients);
    let monitor_workspaces = monitor_workspaces(monitors);
    let is_special = is_special_workspace(workspace.id, &workspace.name);
    let workspace = WorkspaceSnapshot::new(
        workspace.id,
        workspace.name,
        is_special,
        occupied,
        monitor_workspaces,
    );

    Ok(DesktopSnapshot {
        workspace,
        focused_window,
    })
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

fn monitor_workspaces(monitors: Vec<Monitor>) -> Vec<MonitorWorkspace> {
    monitors
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
        .collect()
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

/// Formats a workspace command for Hyprland's Lua-config IPC mode.
fn lua_workspace_dispatch(identifier: WorkspaceIdentifierWithSpecial<'_>) -> String {
    format!("hl.dsp.focus({{ workspace = \"{identifier}\" }})")
}

/// Formats an output-focus command for Hyprland's Lua-config IPC mode.
fn lua_output_focus_dispatch(output: &OutputName) -> String {
    let output = lua_string(output.as_str());

    format!("hl.dsp.focus({{ monitor = \"{output}\" }})")
}

/// Escapes a string embedded in a double-quoted Lua literal.
fn lua_string(value: &str) -> String {
    value
        .replace('\\', "\\\\")
        .replace('\"', "\\\"")
        .replace('\n', "\\n")
        .replace('\r', "\\r")
}

/// Detects Hyprland's explicit legacy-dispatch rejection in Lua config mode.
fn requires_lua_dispatch(error: &HyprError) -> bool {
    matches!(error, HyprError::NotOkDispatch(message) if message.contains("dispatch in lua"))
}

fn focused_window_snapshot(
    client: Option<&Client>,
    hostname: &str,
    monitors: &[Monitor],
    clients: &[Client],
) -> FocusedWindowSnapshot {
    FocusedWindowSnapshot::new(
        client.map(|value| value.class.as_str()),
        client.map(|value| value.title.as_str()),
        hostname,
        monitor_focused_windows(monitors, clients),
    )
}

fn monitor_focused_windows(monitors: &[Monitor], clients: &[Client]) -> Vec<MonitorFocusedWindow> {
    monitors
        .iter()
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
                monitor.name.clone(),
                client.map(|client| client.class.as_str()),
                client.map(|client| client.title.as_str()),
            )
        })
        .collect()
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
    #[error("failed to read a coherent Hyprland desktop snapshot")]
    Snapshot(#[source] HyprError),
    #[error("failed to start the Hyprland event listener")]
    Listener(#[source] HyprError),
    #[error("failed to dispatch a Hyprland command: {0}")]
    Dispatch(#[source] HyprError),
}

#[cfg(test)]
mod tests {
    use super::{
        lua_output_focus_dispatch, lua_workspace_dispatch, read_hostname_from_paths,
        requires_lua_dispatch,
    };
    use crate::hyprland::OutputName;
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
    fn formats_output_focus_for_lua_dispatch() {
        let output = OutputName::new("DP-2").expect("a connector name is not empty");

        assert_eq!(
            lua_output_focus_dispatch(&output),
            "hl.dsp.focus({ monitor = \"DP-2\" })"
        );
    }

    #[test]
    fn escapes_output_names_for_lua_dispatch() {
        let output = OutputName::new("DP-\\\"2").expect("a connector name is not empty");

        assert_eq!(
            lua_output_focus_dispatch(&output),
            "hl.dsp.focus({ monitor = \"DP-\\\\\\\"2\" })"
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
