import 'package:hyprbaric/widget_catalog.dart';

/// Deterministic compositor snapshots for the workspace indicator stories.
abstract final class WorkspaceFixtures {
  static const WorkspaceStatus occupied = WorkspaceStatus(
    id: 3,
    name: '3',
    isSpecial: false,
    occupiedWorkspaceIds: <int>[1, 2, 3, 5, 8],
    monitors: <MonitorWorkspaceStatus>[],
  );

  static const WorkspaceStatus special = WorkspaceStatus(
    id: 1,
    name: 'magic',
    isSpecial: true,
    occupiedWorkspaceIds: <int>[1, 2, 4],
    monitors: <MonitorWorkspaceStatus>[],
  );

  static const WorkspaceSettingsStatus roman = WorkspaceSettingsStatus(
    indicatorStyle: WorkspaceIndicatorStyle.roman,
    clickable: true,
    visibleRange: WorkspaceVisibleRange.medium,
    visibleCount: 7,
  );

  static const WorkspaceSettingsStatus numeric = WorkspaceSettingsStatus(
    indicatorStyle: WorkspaceIndicatorStyle.numeric,
    clickable: true,
    visibleRange: WorkspaceVisibleRange.small,
    visibleCount: 5,
  );

  static const WorkspaceSettingsStatus readOnly = WorkspaceSettingsStatus(
    indicatorStyle: WorkspaceIndicatorStyle.numeric,
    clickable: false,
    visibleRange: WorkspaceVisibleRange.large,
    visibleCount: 9,
  );

  /// This output owns the compositor focus, which is the common case.
  static MonitorWorkspaceResolution resolutionFor(WorkspaceStatus status) {
    return MonitorWorkspaceResolution(
      activeWorkspaceId: status.id,
      activeWorkspaceName: status.name,
      isSpecial: status.isSpecial,
      monitorName: 'DP-1',
    );
  }

  /// Another output holds focus, so this bar falls back to workspace one.
  static const MonitorWorkspaceResolution unfocusedOutput =
      MonitorWorkspaceResolution(
        activeWorkspaceId: 1,
        activeWorkspaceName: '1',
        isSpecial: false,
        monitorName: 'HDMI-A-1',
      );
}
