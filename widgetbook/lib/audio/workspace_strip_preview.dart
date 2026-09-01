import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';

/// Interactive workspace strip shared by Widgetbook and the website.
class WorkspaceStripPreview extends StatefulWidget {
  const WorkspaceStripPreview({super.key});

  @override
  State<WorkspaceStripPreview> createState() => _WorkspaceStripPreviewState();
}

class _WorkspaceStripPreviewState extends State<WorkspaceStripPreview> {
  static const WorkspaceSettingsStatus _settings = WorkspaceSettingsStatus(
    indicatorStyle: WorkspaceIndicatorStyle.roman,
    clickable: true,
    visibleRange: WorkspaceVisibleRange.medium,
    visibleCount: 7,
  );

  static const WorkspaceStatus _status = WorkspaceStatus(
    id: 3,
    name: '3',
    isSpecial: false,
    occupiedWorkspaceIds: <int>[1, 3, 5],
    monitors: <MonitorWorkspaceStatus>[],
  );

  int _activeWorkspace = 3;

  @override
  Widget build(BuildContext context) {
    final MonitorWorkspaceResolution resolution = MonitorWorkspaceResolution(
      activeWorkspaceId: _activeWorkspace,
      activeWorkspaceName: '$_activeWorkspace',
      isSpecial: false,
      monitorName: null,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF07080A),
        border: Border.all(color: const Color(0xFF1D2024)),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x99000000),
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
            status: _status.copyWith(
              id: _activeWorkspace,
              name: '$_activeWorkspace',
            ),
            settings: _settings,
            resolution: resolution,
            onPrevious: () => _setActiveWorkspace(_activeWorkspace - 1),
            onNext: () => _setActiveWorkspace(_activeWorkspace + 1),
            onSelect: _setActiveWorkspace,
          ),
        ),
      ),
    );
  }

  void _setActiveWorkspace(int workspace) {
    setState(() => _activeWorkspace = workspace.clamp(1, 99).toInt());
  }
}
