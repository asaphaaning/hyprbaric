import 'package:hyprbaric/widget_catalog.dart';

/// Deterministic compositor snapshots for the workspace indicator stories.
abstract final class WorkspaceFixtures {
  static const WorkspaceStatus occupied = WorkspaceStatus(
    id: 3,
    name: '3',
    isSpecial: false,
    occupiedWorkspaceIds: <int>[1, 2, 3, 5, 8],
  );

  static const WorkspaceStatus special = WorkspaceStatus(
    id: 1,
    name: 'magic',
    isSpecial: true,
    occupiedWorkspaceIds: <int>[1, 2, 4],
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
}
