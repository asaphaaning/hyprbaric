import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';

/// Interactive workspace strip shared by Widgetbook and the website.
class WorkspaceStripPreview extends StatefulWidget {
  const WorkspaceStripPreview({super.key});

  @override
  State<WorkspaceStripPreview> createState() => _WorkspaceStripPreviewState();
}

class _WorkspaceStripPreviewState extends State<WorkspaceStripPreview> {
  /// The workspaces this fixture pretends the compositor knows about.
  ///
  /// The strip shows [WorkspaceSettingsStatus.visibleCount] of them, so the
  /// preview stays inside that world rather than letting a visitor walk the
  /// active workspace off into ids the fixture says nothing about.
  static const int _workspaceCount = 7;

  static const WorkspaceSettingsStatus _settings = WorkspaceSettingsStatus(
    indicatorStyle: WorkspaceIndicatorStyle.roman,
    clickable: true,
    visibleRange: WorkspaceVisibleRange.medium,
    visibleCount: _workspaceCount,
  );

  static const List<int> _occupied = <int>[1, 3, 5];

  int _activeWorkspace = 3;

  /// The compositor never reports an active workspace as unoccupied, because
  /// focusing one occupies it. Folding the active id in keeps the preview from
  /// rendering a state the real bar cannot produce.
  List<int> get _occupiedWorkspaceIds {
    return <int>{..._occupied, _activeWorkspace}.toList(growable: false)..sort();
  }

  @override
  Widget build(BuildContext context) {
    final WorkspaceStatus status = WorkspaceStatus(
      id: _activeWorkspace,
      name: '$_activeWorkspace',
      isSpecial: false,
      occupiedWorkspaceIds: _occupiedWorkspaceIds,
      monitors: const <MonitorWorkspaceStatus>[],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: HyprColors.surfaceStrong,
        border: Border.all(color: HyprColors.borderSoft),
        borderRadius: HyprRadii.fieldRadius,
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: HyprColors.shadow,
            blurRadius: 8,
            blurStyle: BlurStyle.inner,
          ),
        ],
      ),
      child: SizedBox(
        width: 340,
        height: 64,
        child: Center(
          child: WorkspaceStrip(
            status: status,
            settings: _settings,
            resolution: MonitorWorkspaceResolution(
              activeWorkspaceId: _activeWorkspace,
              activeWorkspaceName: '$_activeWorkspace',
              isSpecial: false,
              monitorName: 'DP-1',
            ),
            onPrevious: () => _setActiveWorkspace(_activeWorkspace - 1),
            onNext: () => _setActiveWorkspace(_activeWorkspace + 1),
            onSelect: _setActiveWorkspace,
          ),
        ),
      ),
    );
  }

  void _setActiveWorkspace(int workspace) {
    setState(
      () => _activeWorkspace = workspace.clamp(1, _workspaceCount).toInt(),
    );
  }
}
