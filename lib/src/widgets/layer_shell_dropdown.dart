import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../layer_shell_hit_region.dart';
import '../state/providers.dart';
import '../theme/hypr_motion.dart';
import 'layer_shell_dropdown_model.dart';
import 'layer_shell_dropdown_overlay.dart';

export 'layer_shell_dropdown_model.dart';

/// Dropdown overlay that keeps the Hyprland layer-shell input region in sync
/// with the visible menu.
///
/// This widget owns an [OverlayEntry], drives open/close animations,
/// clamps the overlay within the monitor, and forwards the animated
/// rectangle to the shared [LayerShellRegionManager] from Riverpod.
class LayerShellDropdown extends ConsumerStatefulWidget {
  const LayerShellDropdown({
    super.key,
    required this.buttonBuilder,
    required this.menuBuilder,
    this.controller,
    this.animationDuration = HyprMotion.popup,
    this.animationCurve = HyprMotion.popupCurve,
    this.transition = LayerShellDropdownTransition.reveal,
    this.transitionAlignment = Alignment.topCenter,
    this.menuRadius = BorderRadius.zero,
    this.horizontalAnchor = LayerShellDropdownAnchor.center,
    this.menuWidth,
    this.verticalGap = 8,
  });

  final LayerShellDropdownController? controller;
  final BorderRadius menuRadius;
  final LayerShellDropdownAnchor horizontalAnchor;
  final double? menuWidth;
  final double verticalGap;
  final Duration animationDuration;
  final Curve animationCurve;
  final LayerShellDropdownTransition transition;
  final Alignment transitionAlignment;
  final Widget Function(
    BuildContext context,
    LayerShellDropdownController controller, {
    required bool isOpen,
  })
  buttonBuilder;
  final Widget Function(
    BuildContext context,
    LayerShellDropdownController controller,
  )
  menuBuilder;

  @override
  ConsumerState<LayerShellDropdown> createState() => _LayerShellDropdownState();
}

/// Imperative handle returned to button/menu builders so they can
/// open/close/toggle the dropdown programmatically.
class LayerShellDropdownController {
  LayerShellDropdownController();

  _LayerShellDropdownState? _state;

  bool get isOpen => _state?._isOpen ?? false;

  void open() => _state?._open();

  void close() => _state?._close();

  void dismiss() => _state?._dismiss();

  void toggle() => isOpen ? close() : open();

  void _attach(_LayerShellDropdownState state) {
    _state = state;
  }

  void _detach(_LayerShellDropdownState state) {
    if (identical(_state, state)) {
      _state = null;
    }
  }
}

/// Internal state that manages the overlay and hit-region updates.
class _LayerShellDropdownState extends ConsumerState<LayerShellDropdown>
    with SingleTickerProviderStateMixin {
  late LayerShellDropdownController _controller;
  late final LayerShellRegionManager _regionManager;
  late final AnimationController _animationController;
  final Object _regionOwner = Object();
  final LayerLink _buttonLayerLink = LayerLink();
  final GlobalKey _buttonKey = GlobalKey();
  final GlobalKey _menuKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  bool _regionUpdateScheduled = false;
  _RegionSyncMode? _pendingRegionMode;
  double _menuOffsetX = 0;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? LayerShellDropdownController();
    _controller._attach(this);
    _regionManager = ref.read(layerShellRegionManagerProvider);
    _animationController =
        AnimationController(vsync: this, duration: widget.animationDuration)
          ..value = 1
          ..addStatusListener((AnimationStatus status) {
            if (status == AnimationStatus.completed && _isOpen) {
              _scheduleRegionUpdate(_RegionSyncMode.exactMenu);
            }
            if (status == AnimationStatus.dismissed && !_isOpen) {
              _removeOverlay();
            }
          });
  }

  @override
  void didUpdateWidget(covariant LayerShellDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller._detach(this);
      _controller = widget.controller ?? LayerShellDropdownController();
      _controller._attach(this);
    }
  }

  @override
  void dispose() {
    _controller._detach(this);
    unawaited(
      _regionManager.updateRegion(
        owner: _regionOwner,
        menuRect: null,
        radius: null,
        debugLabel: 'dropdown-disposed',
      ),
    );
    _animationController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _open() {
    if (_isOpen || _overlayEntry != null) {
      return;
    }
    final buttonContext = _buttonKey.currentContext;
    final overlayState = Overlay.of(context, rootOverlay: true);
    final RenderBox? buttonBox =
        buttonContext?.findRenderObject() as RenderBox?;
    if (buttonBox == null) {
      return;
    }

    final RenderBox? overlayBox =
        overlayState.context.findRenderObject() as RenderBox?;
    if (overlayBox == null) {
      return;
    }

    _menuOffsetX = _initialMenuOffset(
      buttonBox: buttonBox,
      overlayBox: overlayBox,
    );

    final Widget menuContent = RepaintBoundary(
      child: widget.menuBuilder(context, _controller),
    );
    final bool measureTransitionBounds =
        widget.transition == LayerShellDropdownTransition.grow;
    final Widget transitionChild = measureTransitionBounds
        ? menuContent
        : KeyedSubtree(key: _menuKey, child: menuContent);

    _overlayEntry = OverlayEntry(
      builder: (BuildContext overlayContext) {
        final double barHeight = _regionManager.barHeight.toDouble();
        return Positioned.fill(
          child: Stack(
            children: <Widget>[
              Positioned(
                top: barHeight,
                right: 0,
                bottom: 0,
                left: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _controller.close,
                ),
              ),
              if (widget.menuWidth case final double menuWidth)
                AnchoredMenuOverlay(
                  buttonKey: _buttonKey,
                  overlayState: overlayState,
                  anchor: widget.horizontalAnchor,
                  animation: _animationController,
                  animationCurve: widget.animationCurve,
                  transition: widget.transition,
                  transitionAlignment: widget.transitionAlignment,
                  menuWidth: menuWidth,
                  barHeight: barHeight,
                  verticalGap: widget.verticalGap,
                  menuKey: measureTransitionBounds ? _menuKey : null,
                  child: transitionChild,
                )
              else
                CompositedTransformFollower(
                  link: _buttonLayerLink,
                  showWhenUnlinked: false,
                  targetAnchor: Alignment.bottomCenter,
                  followerAnchor: Alignment.topCenter,
                  offset: Offset(
                    _menuOffsetX,
                    _verticalMenuOffset(overlayState),
                  ),
                  child: KeyedSubtree(
                    key: measureTransitionBounds ? _menuKey : null,
                    child: DropdownTransition(
                      animation: _animationController,
                      animationCurve: widget.animationCurve,
                      transition: widget.transition,
                      transitionAlignment: widget.transitionAlignment,
                      child: transitionChild,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );

    overlayState.insert(_overlayEntry!);
    setState(() {
      _isOpen = true;
    });
    _animationController.stop();
    _animationController.value = 1.0;
    _scheduleRegionUpdate(_RegionSyncMode.exactMenu);
  }

  void _close() {
    if (!_isOpen && !_animationController.isAnimating) {
      return;
    }
    setState(() {
      _isOpen = false;
    });
    _animationController.stop();
    _animationController.value = 0.0;
    _removeOverlay();
    _scheduleRegionUpdate(_RegionSyncMode.barOnly);
  }

  void _dismiss() {
    if (!_isOpen &&
        _overlayEntry == null &&
        !_animationController.isAnimating) {
      return;
    }
    if (mounted) {
      setState(() {
        _isOpen = false;
      });
    } else {
      _isOpen = false;
    }
    _animationController.stop();
    _animationController.value = 0.0;
    _removeOverlay();
    _scheduleRegionUpdate(_RegionSyncMode.barOnly);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _menuOffsetX = 0;
  }

  void _scheduleRegionUpdate(_RegionSyncMode mode) {
    _pendingRegionMode = mode;
    if (_regionUpdateScheduled) {
      return;
    }
    _regionUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _regionUpdateScheduled = false;
      if (!mounted) {
        return;
      }
      final _RegionSyncMode? nextMode = _pendingRegionMode;
      _pendingRegionMode = null;
      if (nextMode == null) {
        return;
      }
      unawaited(_updateRegion(nextMode));
    });
  }

  Future<void> _updateRegion(_RegionSyncMode mode) async {
    if (mode == _RegionSyncMode.barOnly) {
      await _regionManager.updateRegion(
        owner: _regionOwner,
        menuRect: null,
        radius: null,
        debugLabel: 'dropdown-closed',
      );
      return;
    }

    final Rect? menuRect = _resolveMenuRect();
    await _regionManager.updateRegion(
      owner: _regionOwner,
      menuRect: menuRect,
      radius: menuRect == null ? null : widget.menuRadius,
      // Keep outside-click dismissal working while any popup is open by
      // capturing the full surface until the dropdown is closed again.
      captureAllClicks: menuRect != null,
      debugLabel: switch (mode) {
        _RegionSyncMode.openingEnvelope => 'dropdown-envelope',
        _RegionSyncMode.exactMenu => 'dropdown-open',
        _RegionSyncMode.barOnly => 'dropdown-closed',
      },
    );
  }

  Rect? _resolveMenuRect() {
    if (_overlayEntry == null) {
      return null;
    }

    final BuildContext? menuContext = _menuKey.currentContext;
    final RenderBox? menuBox = menuContext?.findRenderObject() as RenderBox?;
    if (menuBox == null) {
      return null;
    }

    final OverlayState overlayState = Overlay.of(context, rootOverlay: true);
    final RenderBox? overlayBox =
        overlayState.context.findRenderObject() as RenderBox?;
    if (overlayBox == null) {
      return null;
    }

    final Offset topLeft = menuBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final RenderBox? buttonBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (buttonBox == null) {
      return Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy,
        menuBox.size.width,
        menuBox.size.height,
      );
    }

    final Offset buttonTopLeft = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final Rect buttonRect = buttonTopLeft & buttonBox.size;
    final double desiredLeft = _desiredMenuLeft(
      buttonRect: buttonRect,
      menuWidth: widget.menuWidth ?? menuBox.size.width,
    );
    final double adjustedLeft = desiredLeft.clamp(
      0.0,
      math.max(0.0, overlayBox.size.width - menuBox.size.width),
    );
    final double offsetX = adjustedLeft - topLeft.dx;
    if ((_menuOffsetX - offsetX).abs() > 0.5) {
      _menuOffsetX = offsetX;
      _overlayEntry?.markNeedsBuild();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_overlayEntry != null && mounted) {
          _scheduleRegionUpdate(_RegionSyncMode.exactMenu);
        }
      });
    }

    return Rect.fromLTWH(
      adjustedLeft,
      topLeft.dy,
      menuBox.size.width,
      menuBox.size.height,
    );
  }

  double _initialMenuOffset({
    required RenderBox buttonBox,
    required RenderBox overlayBox,
  }) {
    final double? menuWidth = widget.menuWidth;
    if (menuWidth == null) {
      return 0;
    }

    final Offset buttonTopLeft = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final Rect buttonRect = buttonTopLeft & buttonBox.size;
    final double centeredLeft = buttonRect.center.dx - (menuWidth / 2);
    final double desiredLeft = _desiredMenuLeft(
      buttonRect: buttonRect,
      menuWidth: menuWidth,
    );
    final double adjustedLeft = desiredLeft.clamp(
      0.0,
      math.max(0.0, overlayBox.size.width - menuWidth),
    );
    return adjustedLeft - centeredLeft;
  }

  double _verticalMenuOffset(OverlayState overlayState) {
    final RenderBox? buttonBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? overlayBox =
        overlayState.context.findRenderObject() as RenderBox?;
    if (buttonBox == null || overlayBox == null) {
      return widget.verticalGap;
    }

    final Offset buttonTopLeft = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final double buttonBottom = buttonTopLeft.dy + buttonBox.size.height;
    final double barBottom = _regionManager.barHeight.toDouble();
    return widget.verticalGap + math.max(0, barBottom - buttonBottom);
  }

  double _desiredMenuLeft({
    required Rect buttonRect,
    required double menuWidth,
  }) {
    return switch (widget.horizontalAnchor) {
      LayerShellDropdownAnchor.left => buttonRect.left,
      LayerShellDropdownAnchor.center => buttonRect.center.dx - (menuWidth / 2),
      LayerShellDropdownAnchor.right => buttonRect.right - menuWidth,
    };
  }

  @override
  Widget build(BuildContext context) {
    final bool visualOpen =
        _isOpen ||
        (_animationController.isAnimating && _animationController.value > 0);
    return CompositedTransformTarget(
      link: _buttonLayerLink,
      child: KeyedSubtree(
        key: _buttonKey,
        child: widget.buttonBuilder(context, _controller, isOpen: visualOpen),
      ),
    );
  }
}

enum _RegionSyncMode { openingEnvelope, exactMenu, barOnly }
