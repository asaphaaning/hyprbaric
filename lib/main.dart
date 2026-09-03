import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rinf/rinf.dart';

import 'src/bindings/bindings.dart';
import 'src/hyprbaric.dart';
import 'src/layer_shell_controller.dart';
import 'src/state/layer_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeRust(assignRustSignal);
  runWidget(const ProviderScope(child: _HyprbaricViews()));
}

class _HyprbaricViews extends StatefulWidget {
  const _HyprbaricViews();

  @override
  State<_HyprbaricViews> createState() => _HyprbaricViewsState();
}

class _HyprbaricViewsState extends State<_HyprbaricViews>
    with WidgetsBindingObserver {
  final Map<int, LayerShellController> _controllers =
      <int, LayerShellController>{};
  int _metricsRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (mounted) {
      setState(() => _metricsRevision += 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<ui.FlutterView> views = ui.PlatformDispatcher.instance.views
        .toList(growable: false);
    final Set<int> activeViewIds = views
        .map((ui.FlutterView view) => view.viewId)
        .toSet();
    _controllers.removeWhere(
      (int viewId, _) => !activeViewIds.contains(viewId),
    );

    return ViewCollection(
      views: views.indexed
          .map(((int, ui.FlutterView) entry) {
            final (int index, ui.FlutterView view) = entry;
            return View(
              key: ValueKey<int>(view.viewId),
              view: view,
              child: ProviderScope(
                overrides: [
                  layerShellViewRoleProvider.overrideWithValue(
                    index == 0
                        ? LayerShellViewRole.globalHost
                        : LayerShellViewRole.satellite,
                  ),
                  layerShellControllerProvider.overrideWithValue(
                    _controllers.putIfAbsent(
                      view.viewId,
                      () => LayerShellController.forView(view.viewId),
                    ),
                  ),
                  layerShellMetricsRevisionProvider.overrideWithValue(
                    _metricsRevision,
                  ),
                ],
                child: const Hyprbaric(),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}
