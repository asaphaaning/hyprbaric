import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'layer_shell_controller.dart';
import 'native/layer_shell_api.g.dart';

bool _isLinux() => !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

enum LayerShellBarEdge {
  top,
  bottom;

  NativeLayerShellBarEdge toNative() => switch (this) {
    LayerShellBarEdge.top => NativeLayerShellBarEdge.top,
    LayerShellBarEdge.bottom => NativeLayerShellBarEdge.bottom,
  };
}

@immutable
class LayerShellMenuRegion {
  const LayerShellMenuRegion({required this.rect, required this.radius});

  final Rect rect;
  final BorderRadius radius;

  NativeLayerShellRegion toNative() => NativeLayerShellRegion(
    x: rect.left.round(),
    y: rect.top.round(),
    width: rect.width.round(),
    height: rect.height.round(),
    radiusTopLeft: radius.topLeft.x.round(),
    radiusTopRight: radius.topRight.x.round(),
    radiusBottomRight: radius.bottomRight.y.round(),
    radiusBottomLeft: radius.bottomLeft.y.round(),
  );

  @override
  bool operator ==(Object other) {
    return other is LayerShellMenuRegion &&
        other.rect == rect &&
        other.radius == radius;
  }

  @override
  int get hashCode => Object.hash(rect, radius);
}

@immutable
class LayerShellRegionRequest {
  const LayerShellRegionRequest({
    required this.barHeight,
    required this.barEdge,
    required this.menu,
    required this.regions,
    required this.captureAllClicks,
  });

  final int barHeight;
  final LayerShellBarEdge barEdge;
  final LayerShellMenuRegion? menu;
  final List<LayerShellMenuRegion> regions;
  final bool captureAllClicks;

  NativeLayerShellRegionRequest toNative() => NativeLayerShellRegionRequest(
    barHeight: barHeight,
    barEdge: barEdge.toNative(),
    menu: menu?.toNative(),
    passiveRegions: regions
        .map((LayerShellMenuRegion region) => region.toNative())
        .toList(growable: false),
    captureAllClicks: captureAllClicks,
  );

  @override
  bool operator ==(Object other) {
    return other is LayerShellRegionRequest &&
        other.barHeight == barHeight &&
        other.barEdge == barEdge &&
        other.menu == menu &&
        listEquals(other.regions, regions) &&
        other.captureAllClicks == captureAllClicks;
  }

  @override
  int get hashCode => Object.hash(
    barHeight,
    barEdge,
    menu,
    Object.hashAll(regions),
    captureAllClicks,
  );
}

class _QueuedRegionUpdate {
  const _QueuedRegionUpdate({required this.request, required this.debugLabel});

  final LayerShellRegionRequest request;
  final String debugLabel;
}

/// Handles communication with the native runner to keep the layer-shell
/// input region in sync with Flutter overlays.
class LayerShellRegionManager {
  LayerShellRegionManager({
    required double barHeight,
    LayerShellController? controller,
    LayerShellBarEdge barEdge = LayerShellBarEdge.top,
  }) : _barHeight = barHeight.round(),
       _controller = controller ?? LayerShellController.defaultView(),
       _barEdge = barEdge;

  final LayerShellController _controller;
  int _barHeight;
  LayerShellBarEdge _barEdge;
  LayerShellMenuRegion? _menu;
  bool _captureAllClicks = false;
  final Map<String, List<LayerShellMenuRegion>> _ownedRegions =
      <String, List<LayerShellMenuRegion>>{};
  bool _flushInProgress = false;
  LayerShellRegionRequest? _lastAppliedRequest;
  _QueuedRegionUpdate? _pendingUpdate;

  int get barHeight => _barHeight;

  void setBarHeight(double value) {
    _barHeight = value.round();
  }

  void setBarEdge(LayerShellBarEdge value) {
    _barEdge = value;
  }

  void dispose() {
    _pendingUpdate = null;
    _ownedRegions.clear();
  }

  Future<void> updateRegion({
    required Rect? menuRect,
    BorderRadius? radius,
    bool captureAllClicks = false,
    String debugLabel = 'layer-shell',
  }) async {
    if (!_isLinux()) {
      return;
    }

    _menu = menuRect == null
        ? null
        : LayerShellMenuRegion(
            rect: menuRect,
            radius: radius ?? BorderRadius.zero,
          );
    _captureAllClicks = captureAllClicks;
    await _sendMergedRegion(debugLabel);
  }

  Future<void> setPassiveRegions({
    required String owner,
    required List<LayerShellMenuRegion> regions,
    String debugLabel = 'layer-shell-passive',
  }) async {
    if (!_isLinux()) {
      return;
    }
    if (regions.isEmpty) {
      _ownedRegions.remove(owner);
    } else {
      _ownedRegions[owner] = List<LayerShellMenuRegion>.unmodifiable(regions);
    }
    await _sendMergedRegion(debugLabel);
  }

  Future<void> removePassiveRegions({
    required String owner,
    String debugLabel = 'layer-shell-passive-remove',
  }) async {
    if (!_isLinux()) {
      return;
    }
    _ownedRegions.remove(owner);
    await _sendMergedRegion(debugLabel);
  }

  Future<void> _sendMergedRegion(String debugLabel) async {
    final LayerShellRegionRequest request = LayerShellRegionRequest(
      barHeight: _barHeight,
      barEdge: _barEdge,
      menu: _menu,
      regions: _ownedRegions.values
          .expand((List<LayerShellMenuRegion> regions) => regions)
          .toList(growable: false),
      captureAllClicks: _captureAllClicks,
    );
    if (request == _lastAppliedRequest || request == _pendingUpdate?.request) {
      return;
    }

    _pendingUpdate = _QueuedRegionUpdate(
      request: request,
      debugLabel: debugLabel,
    );
    if (_flushInProgress) {
      return;
    }

    _flushInProgress = true;
    try {
      while (true) {
        final _QueuedRegionUpdate? nextUpdate = _pendingUpdate;
        if (nextUpdate == null) {
          break;
        }
        _pendingUpdate = null;
        if (nextUpdate.request == _lastAppliedRequest) {
          continue;
        }

        try {
          await _controller.setRegion(nextUpdate.request.toNative());
          _lastAppliedRequest = nextUpdate.request;
        } catch (_) {
          // A dropped region update is recoverable: the next one reapplies it.
        }
      }
    } finally {
      _flushInProgress = false;
    }
  }
}
