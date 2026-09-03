//! Typed projections and commands independent of the Hyprland crate.

use std::collections::BTreeSet;

/// A Hyprland workspace identity.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct WorkspaceId(i32);

/// A non-empty Hyprland output connector name.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct OutputName(String);

/// A typed compositor request.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Command {
    SwitchWorkspace {
        /// Workspace to activate.
        target: WorkspaceTarget,
        /// Output that originated the request, when known.
        output: Option<OutputName>,
    },
}

/// One coherent observation of the compositor desktop.
#[derive(Clone, Debug, PartialEq)]
pub struct DesktopSnapshot {
    /// Workspace state observed in this snapshot.
    pub workspace: WorkspaceSnapshot,
    /// Focused-window state observed in this snapshot.
    pub focused_window: FocusedWindowSnapshot,
}

impl OutputName {
    /// Creates an output name after trimming transport whitespace.
    pub fn new(value: impl Into<String>) -> Option<Self> {
        let value = value.into();
        let trimmed = value.trim();
        (!trimmed.is_empty()).then(|| Self(trimmed.to_owned()))
    }

    /// Returns the compositor-facing connector name.
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

/// A legal workspace switch target.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum WorkspaceTarget {
    Relative(i32),
    Absolute(WorkspaceId),
}

/// Kind of workspace currently visible on an output.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum WorkspaceKind {
    /// A regular numbered or named workspace.
    Regular,
    /// A Hyprland special workspace layered over the regular workspace.
    Special,
}

/// Workspace currently visible on one output.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DisplayedWorkspace {
    /// Numeric Hyprland workspace identifier.
    pub id: WorkspaceId,
    /// User-visible workspace name.
    pub name: String,
    /// Whether this is a regular or special workspace.
    kind: WorkspaceKind,
}

impl DisplayedWorkspace {
    pub(super) fn regular(id: i32, name: String) -> Self {
        Self {
            id: WorkspaceId::observed(id),
            name,
            kind: WorkspaceKind::Regular,
        }
    }

    pub(super) fn special(id: i32, name: String) -> Self {
        Self {
            id: WorkspaceId::observed(id),
            name,
            kind: WorkspaceKind::Special,
        }
    }

    /// Returns whether this is a Hyprland special workspace.
    pub const fn is_special(&self) -> bool {
        matches!(self.kind, WorkspaceKind::Special)
    }
}

/// Transform applied by Hyprland to an output.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum OutputTransform {
    /// No transform.
    Normal,
    /// Rotated 90 degrees.
    Rotated90,
    /// Rotated 180 degrees.
    Rotated180,
    /// Rotated 270 degrees.
    Rotated270,
    /// Flipped without rotation.
    Flipped,
    /// Flipped and rotated 90 degrees.
    Flipped90,
    /// Flipped and rotated 180 degrees.
    Flipped180,
    /// Flipped and rotated 270 degrees.
    Flipped270,
}

impl OutputTransform {
    const fn swaps_axes(self) -> bool {
        matches!(
            self,
            Self::Rotated90 | Self::Rotated270 | Self::Flipped90 | Self::Flipped270
        )
    }
}

/// Logical compositor rectangle occupied by an output.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct OutputGeometry {
    /// Logical x-coordinate in the compositor output layout.
    pub x: i32,
    /// Logical y-coordinate in the compositor output layout.
    pub y: i32,
    /// Logical width after scale and transform.
    pub width: i32,
    /// Logical height after scale and transform.
    pub height: i32,
}

impl OutputGeometry {
    pub(super) fn from_physical(
        x: i32,
        y: i32,
        width: i32,
        height: i32,
        scale: f32,
        transform: OutputTransform,
    ) -> Self {
        let scale = if scale.is_finite() && scale > 0.0 {
            scale
        } else {
            1.0
        };
        let (width, height) = if transform.swaps_axes() {
            (height, width)
        } else {
            (width, height)
        };

        Self {
            x,
            y,
            width: ((width as f32) / scale).round() as i32,
            height: ((height as f32) / scale).round() as i32,
        }
    }
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
        let focused_workspace = monitors
            .iter()
            .find(|monitor| monitor.is_focused)
            .map(|monitor| &monitor.workspace);

        Self {
            id: focused_workspace
                .map_or_else(|| WorkspaceId::observed(id), |workspace| workspace.id),
            name: focused_workspace.map_or(name, |workspace| workspace.name.clone()),
            is_special: focused_workspace.map_or(is_special, DisplayedWorkspace::is_special),
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
    /// The regular or special workspace this output currently displays.
    pub workspace: DisplayedWorkspace,
    /// Whether this output holds the compositor focus.
    pub is_focused: bool,
    /// Logical compositor rectangle occupied by this output.
    pub geometry: OutputGeometry,
    /// Refresh rate in millihertz.
    pub refresh_rate_millihertz: i32,
}

impl MonitorWorkspace {
    pub(super) fn new(
        name: String,
        workspace: DisplayedWorkspace,
        is_focused: bool,
        geometry: OutputGeometry,
        refresh_rate: f32,
    ) -> Self {
        Self {
            name,
            workspace,
            is_focused,
            geometry,
            refresh_rate_millihertz: (refresh_rate * 1000.0).round() as i32,
        }
    }
}

/// The regular Hyprland workspaces that currently contain windows.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct WorkspaceOccupancy(BTreeSet<WorkspaceId>);

impl WorkspaceOccupancy {
    /// Builds occupancy from workspace IDs whose corresponding workspace has windows.
    pub(super) fn from_occupied_ids(ids: impl IntoIterator<Item = i32>) -> Self {
        Self(
            ids.into_iter()
                .filter(|id| *id > 0)
                .map(WorkspaceId::observed)
                .collect(),
        )
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
    /// Last focused visible client for each output.
    pub monitors: Vec<MonitorFocusedWindow>,
}

impl FocusedWindowSnapshot {
    pub(super) fn new(
        app_name: Option<&str>,
        title: Option<&str>,
        hostname: &str,
        monitors: Vec<MonitorFocusedWindow>,
    ) -> Self {
        Self {
            app_name: app_name.and_then(normalize_app_name),
            title: title.and_then(normalize_title),
            hostname: hostname.to_owned(),
            monitors,
        }
    }
}

/// Last focused client visible on one output.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MonitorFocusedWindow {
    /// Hyprland connector name, such as `DP-2`.
    pub monitor_name: String,
    /// Normalized application class when the output has a visible client.
    pub app_name: Option<String>,
    /// Normalized title when the output has a visible client.
    pub title: Option<String>,
}

impl MonitorFocusedWindow {
    pub(super) fn new(monitor_name: String, app_name: Option<&str>, title: Option<&str>) -> Self {
        Self {
            monitor_name,
            app_name: app_name.and_then(normalize_app_name),
            title: title.and_then(normalize_title),
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
        DisplayedWorkspace, FocusedWindowSnapshot, MonitorFocusedWindow, MonitorWorkspace,
        OutputGeometry, OutputName, OutputTransform, WorkspaceId, WorkspaceOccupancy,
        WorkspaceSnapshot, WorkspaceTarget, normalize_app_name, normalize_title,
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
    fn output_name_rejects_blank_transport_values() {
        assert_eq!(OutputName::new("  "), None);
        assert_eq!(
            OutputName::new(" DP-2 ").map(|name| name.as_str().to_owned()),
            Some("DP-2".to_owned())
        );
    }

    #[test]
    fn focused_window_snapshot_preserves_hostname_without_title() {
        let snapshot = FocusedWindowSnapshot {
            app_name: None,
            title: None,
            hostname: "workstation".to_owned(),
            monitors: Vec::new(),
        };

        assert_eq!(snapshot.app_name, None);
        assert_eq!(snapshot.title, None);
        assert_eq!(snapshot.hostname, "workstation");
    }

    #[test]
    fn monitor_focused_window_normalizes_boundary_values() {
        let window =
            MonitorFocusedWindow::new("DP-2".to_owned(), Some("  foot  "), Some("  cargo test  "));

        assert_eq!(window.monitor_name, "DP-2");
        assert_eq!(window.app_name.as_deref(), Some("foot"));
        assert_eq!(window.title.as_deref(), Some("cargo test"));
    }

    #[test]
    fn absolute_targets_reject_non_positive_ids() {
        assert_eq!(WorkspaceTarget::absolute(0), None);
        assert_eq!(WorkspaceTarget::absolute(-1), None);
        assert!(WorkspaceTarget::absolute(1).is_some());
    }

    #[test]
    fn monitor_workspace_projects_logical_geometry_and_precise_refresh_rate() {
        let monitor = MonitorWorkspace::new(
            "DP-2".to_owned(),
            DisplayedWorkspace::regular(3, "3".to_owned()),
            true,
            OutputGeometry::from_physical(1920, 0, 3840, 2160, 1.2, OutputTransform::Normal),
            240.016,
        );

        assert_eq!(monitor.name, "DP-2");
        assert_eq!(monitor.workspace.id.get(), 3);
        assert!(!monitor.workspace.is_special());
        assert!(monitor.is_focused);
        assert_eq!(
            monitor.geometry,
            OutputGeometry {
                x: 1920,
                y: 0,
                width: 3200,
                height: 1800,
            }
        );
        assert_eq!(monitor.refresh_rate_millihertz, 240_016);
    }

    #[test]
    fn rotated_monitor_swaps_axes_after_scaling() {
        let monitor = MonitorWorkspace::new(
            "DP-1".to_owned(),
            DisplayedWorkspace::regular(2, "2".to_owned()),
            false,
            OutputGeometry::from_physical(-1080, 0, 1920, 1080, 1.0, OutputTransform::Rotated90),
            60.0,
        );

        assert_eq!(
            monitor.geometry,
            OutputGeometry {
                x: -1080,
                y: 0,
                width: 1080,
                height: 1920,
            }
        );
    }

    #[test]
    fn special_workspace_supersedes_regular_workspace_per_output() {
        let monitor = MonitorWorkspace::new(
            "DP-2".to_owned(),
            DisplayedWorkspace::special(-99, "special:notes".to_owned()),
            false,
            OutputGeometry::from_physical(0, 0, 1920, 1080, 1.0, OutputTransform::Normal),
            60.0,
        );

        assert_eq!(monitor.workspace.id.get(), -99);
        assert_eq!(monitor.workspace.name, "special:notes");
        assert!(monitor.workspace.is_special());
    }

    #[test]
    fn snapshot_carries_each_output_alongside_the_focused_workspace() {
        let snapshot = WorkspaceSnapshot::new(
            4,
            "4".to_owned(),
            false,
            WorkspaceOccupancy::from_occupied_ids([3]),
            vec![
                MonitorWorkspace::new(
                    "DP-2".to_owned(),
                    DisplayedWorkspace::regular(3, "3".to_owned()),
                    false,
                    OutputGeometry::from_physical(0, 0, 3840, 2160, 1.2, OutputTransform::Normal),
                    240.0,
                ),
                MonitorWorkspace::new(
                    "MACBOOK".to_owned(),
                    DisplayedWorkspace::regular(4, "4".to_owned()),
                    true,
                    OutputGeometry::from_physical(
                        3200,
                        0,
                        2560,
                        1600,
                        1.0,
                        OutputTransform::Normal,
                    ),
                    60.0,
                ),
            ],
        );

        // Focus is on workspace 4, but DP-2 is still displaying workspace 3.
        assert_eq!(snapshot.id.get(), 4);
        assert_eq!(snapshot.monitors[0].workspace.id.get(), 3);
        assert!(!snapshot.monitors[0].is_focused);
        assert!(snapshot.monitors[1].is_focused);
    }

    #[test]
    fn focused_special_workspace_is_the_compositor_wide_fallback() {
        let snapshot = WorkspaceSnapshot::new(
            4,
            "4".to_owned(),
            false,
            WorkspaceOccupancy::default(),
            vec![MonitorWorkspace::new(
                "DP-2".to_owned(),
                DisplayedWorkspace::special(-99, "special:notes".to_owned()),
                true,
                OutputGeometry::from_physical(0, 0, 1920, 1080, 1.0, OutputTransform::Normal),
                60.0,
            )],
        );

        assert_eq!(snapshot.id.get(), -99);
        assert_eq!(snapshot.name, "special:notes");
        assert!(snapshot.is_special);
    }

    #[test]
    fn workspace_occupancy_contains_only_observed_workspace_ids() {
        let occupancy = WorkspaceOccupancy::from_occupied_ids([3, -99, 1, 3]);

        assert_eq!(
            occupancy.ids().map(WorkspaceId::get).collect::<Vec<_>>(),
            vec![1, 3]
        );
    }
}
