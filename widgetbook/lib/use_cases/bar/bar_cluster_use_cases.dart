import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';
import 'bar_use_cases.dart';
import 'workspace_fixtures.dart';

@UseCase(name: 'Roman workspaces', type: LeftCluster, path: '[Widgets]/Bar')
Widget buildRomanLeftCluster(BuildContext context) {
  return const _LeftClusterStory(settings: WorkspaceFixtures.roman);
}

@UseCase(name: 'Numeric workspaces', type: LeftCluster, path: '[Widgets]/Bar')
Widget buildNumericLeftCluster(BuildContext context) {
  return const _LeftClusterStory(settings: WorkspaceFixtures.numeric);
}

@UseCase(name: 'Launcher open', type: LeftCluster, path: '[Widgets]/Bar')
Widget buildLauncherOpenLeftCluster(BuildContext context) {
  return const _LeftClusterStory(
    settings: WorkspaceFixtures.roman,
    appLauncherOpen: true,
  );
}

@UseCase(name: 'Awaiting compositor', type: LeftCluster, path: '[Widgets]/Bar')
Widget buildLoadingLeftCluster(BuildContext context) {
  return const _LeftClusterStory(
    settings: WorkspaceFixtures.roman,
    workspace: null,
  );
}

@UseCase(name: 'Focused window', type: CenterCluster, path: '[Widgets]/Bar')
Widget buildFocusedCenterCluster(BuildContext context) {
  return const _CenterClusterStory(focusedWindow: BarFixtures.focusedWindow);
}

@UseCase(name: 'Empty desktop', type: CenterCluster, path: '[Widgets]/Bar')
Widget buildEmptyCenterCluster(BuildContext context) {
  return const _CenterClusterStory(
    focusedWindow: FocusedWindowStatus(
      appName: '',
      title: '',
      hostname: 'hyprbaric',
      monitors: <MonitorFocusedWindowStatus>[],
    ),
  );
}

/// The production left cluster over the bar's chrome, fed by typed snapshots.
///
/// A null [workspace] leaves the compositor signal pending, which is the state
/// that renders [WorkspaceStripPlaceholder].
class _LeftClusterStory extends StatelessWidget {
  const _LeftClusterStory({
    required this.settings,
    this.workspace = WorkspaceFixtures.occupied,
    this.appLauncherOpen = false,
  });

  final WorkspaceSettingsStatus settings;
  final WorkspaceStatus? workspace;
  final bool appLauncherOpen;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        workspaceStatusProvider.overrideWith(
          (Ref ref) => workspace == null
              ? const Stream<WorkspaceStatus>.empty()
              : Stream<WorkspaceStatus>.value(workspace!),
        ),
        workspaceSettingsStatusProvider.overrideWith(
          (Ref ref) => Stream<WorkspaceSettingsStatus>.value(settings),
        ),
      ],
      child: CatalogCanvas(
        child: _BarChrome(
          child: LeftCluster(
            appLauncherOpen: appLauncherOpen,
            onToggleAppLauncher: () {},
          ),
        ),
      ),
    );
  }
}

class _CenterClusterStory extends StatelessWidget {
  const _CenterClusterStory({required this.focusedWindow});

  final FocusedWindowStatus focusedWindow;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        workspaceStatusProvider.overrideWith(
          (Ref ref) =>
              Stream<WorkspaceStatus>.value(WorkspaceFixtures.occupied),
        ),
        focusedWindowStatusProvider.overrideWith(
          (Ref ref) => Stream<FocusedWindowStatus>.value(focusedWindow),
        ),
      ],
      child: CatalogCanvas(
        child: _BarChrome(
          child: SizedBox(
            width: 520,
            child: const CenterCluster(maxWidth: 420),
          ),
        ),
      ),
    );
  }
}

class _BarChrome extends StatelessWidget {
  const _BarChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xB3081119)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: child,
      ),
    );
  }
}
