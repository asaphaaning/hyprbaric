import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bindings/bindings.dart';
import '../layer_shell_controller.dart';
import '../layer_shell_hit_region.dart';
import 'bar_config.dart';

/// Shared instance of [LayerShellRegionManager] so overlays and other widgets
/// operate on the same native channel connection.
final layerShellRegionManagerProvider = Provider<LayerShellRegionManager>((
  ref,
) {
  final manager = LayerShellRegionManager(
    barHeight: ref.read(barHeightProvider),
    controller: ref.read(layerShellControllerProvider),
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
