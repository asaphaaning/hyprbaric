//! Typed projections and commands independent of the Hyprland crate.

use std::collections::BTreeSet;

/// A Hyprland workspace identity.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct WorkspaceId(i32);

/// A typed compositor request.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Command {
    SwitchWorkspace(WorkspaceTarget),
}

/// A legal workspace switch target.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum WorkspaceTarget {
    Relative(i32),
    Absolute(WorkspaceId),
}

/// The active workspace state consumed by the bar.
///
/// The top-level fields describe the compositor-wide focus. `monitors`
/// additionally carries what each output is displaying, because a bar rendered
/// on an unfocused output must show that output's workspace rather than the
/// focused one.
#[derive(Clone, Debug, PartialEq)]
pub struct WorkspaceSnapshot {
    /// Numeric Hyprland workspace identifier of the focused workspace.
    pub id: WorkspaceId,
    /// User-visible name of the focused workspace.
    pub name: String,
    /// Whether the focused workspace is a special workspace.
    pub is_special: bool,
    /// The regular workspaces that currently contain one or more windows.
    pub occupied: WorkspaceOccupancy,
    /// What each connected output is currently displaying.
    pub monitors: Vec<MonitorWorkspace>,
}

impl WorkspaceSnapshot {
    pub(super) fn new(
        id: i32,
        name: String,
        is_special: bool,
        occupied: WorkspaceOccupancy,
        monitors: Vec<MonitorWorkspace>,
    ) -> Self {
        Self {
            id: WorkspaceId::observed(id),
            name,
            is_special,
            occupied,
            monitors,
        }
    }
}

/// What a single Hyprland output is displaying.
///
/// Geometry is carried so the Dart side can match a bar's Flutter display to
/// the compositor output it occupies; Hyprland's connector names are not
/// visible to GTK, which reports monitor models instead.
#[derive(Clone, Debug, PartialEq)]
pub struct MonitorWorkspace {
    /// Hyprland connector name, such as `DP-2`.
    pub name: String,
    /// The workspace this output currently displays.
    pub active_workspace: WorkspaceId,
    /// Whether this output holds the compositor focus.
    pub is_focused: bool,
    /// Output width in physical pixels.
    pub width: i32,
    /// Output height in physical pixels.
    pub height: i32,
    /// Refresh rate in Hz, rounded to the nearest whole frame.
    pub refresh_hz: i32,
    /// Output scale, needed to derive the logical size a client observes.
    pub scale: f32,
}

impl MonitorWorkspace {
    pub(super) fn new(
        name: String,
        active_workspace: i32,
        is_focused: bool,
        width: i32,
        height: i32,
        refresh_hz: f32,
        scale: f32,
    ) -> Self {
        Self {
            name,
            active_workspace: WorkspaceId::observed(active_workspace),
            is_focused,
            width,
            height,
            refresh_hz: refresh_hz.round() as i32,
            scale,
        }
    }
}

/// The regular Hyprland workspaces that currently contain windows.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct WorkspaceOccupancy(BTreeSet<WorkspaceId>);

impl WorkspaceOccupancy {
    /// Builds occupancy from workspace IDs whose corresponding workspace has windows.
    pub(super) fn from_occupied_ids(ids: impl IntoIterator<Item = i32>) -> Self {
        Self(ids.into_iter().map(WorkspaceId::observed).collect())
    }

    /// Iterates over the IDs of occupied workspaces in ascending order.
    pub fn ids(&self) -> impl Iterator<Item = WorkspaceId> + '_ {
        self.0.iter().copied()
    }
}

/// The active client identity consumed by the center bar cluster.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct FocusedWindowSnapshot {
    /// Normalized application class, when Hyprland reports one.
    pub app_name: Option<String>,
    /// Normalized window title, when Hyprland reports one.
    pub title: Option<String>,
    /// Hostname displayed when no client identity is available.
    pub hostname: String,
}

impl FocusedWindowSnapshot {
    pub(super) fn new(app_name: Option<&str>, title: Option<&str>, hostname: &str) -> Self {
        Self {
            app_name: app_name.and_then(normalize_app_name),
            title: title.and_then(normalize_title),
            hostname: hostname.to_owned(),
        }
    }
}

impl WorkspaceId {
    pub const fn get(self) -> i32 {
        self.0
    }

    const fn observed(value: i32) -> Self {
        Self(value)
    }

    pub fn target(value: i32) -> Option<Self> {
        (value > 0).then_some(Self(value))
    }
}

impl WorkspaceTarget {
    pub const fn relative(offset: i32) -> Self {
        Self::Relative(offset)
    }

    pub fn absolute(id: i32) -> Option<Self> {
        WorkspaceId::target(id).map(Self::Absolute)
    }
}

fn normalize_title(title: &str) -> Option<String> {
    normalize(title)
}

fn normalize_app_name(name: &str) -> Option<String> {
    normalize(name)
}

fn normalize(value: &str) -> Option<String> {
    let trimmed = value.trim();
    (!trimmed.is_empty()).then(|| trimmed.to_owned())
}

#[cfg(test)]
mod tests {
    use super::{
        FocusedWindowSnapshot, MonitorWorkspace, WorkspaceId, WorkspaceOccupancy, WorkspaceSnapshot,
        WorkspaceTarget, normalize_app_name, normalize_title,
    };

    #[test]
    fn normalize_title_rejects_blank_values() {
        assert_eq!(normalize_title("   "), None);
        assert_eq!(normalize_title(" terminal "), Some("terminal".to_owned()));
    }

    #[test]
    fn normalize_app_name_rejects_blank_values() {
        assert_eq!(normalize_app_name("   "), None);
        assert_eq!(normalize_app_name(" zed "), Some("zed".to_owned()));
    }

    #[test]
    fn focused_window_snapshot_preserves_hostname_without_title() {
        let snapshot = FocusedWindowSnapshot {
            app_name: None,
            title: None,
            hostname: "workstation".to_owned(),
        };

        assert_eq!(snapshot.app_name, None);
        assert_eq!(snapshot.title, None);
        assert_eq!(snapshot.hostname, "workstation");
    }

    #[test]
    fn absolute_targets_reject_non_positive_ids() {
        assert_eq!(WorkspaceTarget::absolute(0), None);
        assert_eq!(WorkspaceTarget::absolute(-1), None);
        assert!(WorkspaceTarget::absolute(1).is_some());
    }

    #[test]
    fn monitor_workspace_rounds_refresh_rate_to_whole_frames() {
        let monitor = MonitorWorkspace::new("DP-2".to_owned(), 3, true, 3840, 2160, 240.016, 1.2);

        assert_eq!(monitor.name, "DP-2");
        assert_eq!(monitor.active_workspace.get(), 3);
        assert!(monitor.is_focused);
        assert_eq!(monitor.refresh_hz, 240);
    }

    #[test]
    fn snapshot_carries_each_output_alongside_the_focused_workspace() {
        let snapshot = WorkspaceSnapshot::new(
            4,
            "4".to_owned(),
            false,
            WorkspaceOccupancy::from_occupied_ids([3]),
            vec![
                MonitorWorkspace::new("DP-2".to_owned(), 3, false, 3840, 2160, 240.0, 1.2),
                MonitorWorkspace::new("MACBOOK".to_owned(), 4, true, 2560, 1600, 60.0, 1.0),
            ],
        );

        // Focus is on workspace 4, but DP-2 is still displaying workspace 3.
        assert_eq!(snapshot.id.get(), 4);
        assert_eq!(snapshot.monitors[0].active_workspace.get(), 3);
        assert!(!snapshot.monitors[0].is_focused);
        assert!(snapshot.monitors[1].is_focused);
    }

    #[test]
    fn workspace_occupancy_contains_only_observed_workspace_ids() {
        let occupancy = WorkspaceOccupancy::from_occupied_ids([3, 1, 3]);

        assert_eq!(
            occupancy.ids().map(WorkspaceId::get).collect::<Vec<_>>(),
            vec![1, 3]
        );
    }
}
