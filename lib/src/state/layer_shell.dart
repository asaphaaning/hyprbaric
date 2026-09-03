import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bindings/bindings.dart';
import '../layer_shell_controller.dart';
import '../layer_shell_hit_region.dart';
import 'appearance.dart';
import 'bar_config.dart';
import 'workspaces.dart';

/// Responsibility assigned to one Flutter view in a multi-view process.
enum LayerShellViewRole {
  /// The sole view allowed to react to process-global interactions.
  globalHost,

  /// A view that only renders monitor-local state and interactions.
  satellite;

  bool get handlesGlobalActions => this == globalHost;
}

/// Role of the current Flutter view.
final layerShellViewRoleProvider = Provider<LayerShellViewRole>(
  (_) => LayerShellViewRole.globalHost,
);

/// Shared instance of [LayerShellRegionManager] so overlays and other widgets
/// operate on the same native channel connection.
final layerShellRegionManagerProvider = Provider<LayerShellRegionManager>((
  ref,
) {
  final manager = LayerShellRegionManager(
    barHeight: ref.read(barHeightProvider),
    controller: ref.watch(layerShellControllerProvider),
    barEdge: _edgeFromPosition(ref.read(barPositionProvider)),
  );

  ref.listen<double>(
    barHeightProvider,
    (_, double next) => manager.setBarHeight(next),
  );
  ref.listen<AppearancePosition>(
    barPositionProvider,
    (_, AppearancePosition next) => manager.setBarEdge(_edgeFromPosition(next)),
  );

  ref.onDispose(manager.dispose);

  return manager;
});

LayerShellBarEdge _edgeFromPosition(AppearancePosition position) {
  return switch (position) {
    AppearancePosition.top => LayerShellBarEdge.top,
    AppearancePosition.bottom => LayerShellBarEdge.bottom,
  };
}

final layerShellControllerProvider = Provider<LayerShellController>(
  (_) => LayerShellController.defaultView(),
);

final layerShellMonitorsProvider = FutureProvider<List<LayerShellMonitor>>(
  (ref) => ref.watch(layerShellControllerProvider).listMonitors(),
);

/// Native output occupied by this provider scope's Flutter view.
final layerShellCurrentMonitorProvider = FutureProvider<LayerShellMonitor?>((
  ref,
) {
  ref.watch(layerShellMetricsRevisionProvider);
  return ref.watch(layerShellControllerProvider).currentMonitor();
});

/// Native visibility target resolved for the current Flutter view.
///
/// Persisted named targets are Hyprland connector names. GTK cannot expose
/// these names, so each view matches its GDK geometry to the compositor
/// projection and receives an explicit visible or hidden target.
final layerShellViewMonitorTargetProvider = Provider<LayerShellMonitorTarget>((
  ref,
) {
  final AppearanceMonitorTarget configured = ref
      .watch(currentAppearanceProvider)
      .monitor;
  final WorkspaceStatus? workspace = ref
      .watch(currentWorkspaceStatusProvider)
      .asData
      ?.value;
  final LayerShellMonitor? output = ref
      .watch(layerShellCurrentMonitorProvider)
      .asData
      ?.value;

  return resolveViewMonitorTarget(configured, workspace, output);
});

/// Changes whenever Flutter reports output metrics changing.
final layerShellMetricsRevisionProvider = Provider<int>((_) => 0);
