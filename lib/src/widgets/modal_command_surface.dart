import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../layer_shell_hit_region.dart';
import '../state/providers.dart';
import '../theme/hypr_motion.dart';

enum ModalCommandSurfacePlacement { topCenter, anchorLeft, anchorRight }

enum ModalCommandSurfaceTransition { compact, anchored }

class ModalCommandSurfaceController extends ChangeNotifier {
  _ModalCommandSurfaceState? _state;

  bool get isOpen => _state?._isOpen ?? false;

  void open() => _state?._open();

  void close() => _state?._close();

  void dismiss() => _state?._dismiss();

  void toggle() => isOpen ? close() : open();

  void refreshRegion() =>
      _state?._scheduleRegionUpdate(_ModalRegionMode.exactPanel);

  void _attach(_ModalCommandSurfaceState state) {
    _state = state;
  }

  void _detach(_ModalCommandSurfaceState state) {
    if (identical(_state, state)) {
      _state = null;
    }
  }

  void _notifyOpenChanged() {
    notifyListeners();
  }
}

typedef ModalCommandSurfaceBuilder = Widget Function(BuildContext context);

class ModalCommandSurface extends ConsumerStatefulWidget {
  const ModalCommandSurface({
    super.key,
    required this.controller,
    required this.barHeight,
    required this.borderRadius,
    required this.debugLabel,
    required this.builder,
    this.canOpen,
    this.onOpening,
    this.onOpened,
    this.onClosing,
    this.onDismissed,
    this.focusNode,
    this.onKeyEvent,
    this.shortcuts = const <ShortcutActivator, VoidCallback>{},
    this.anchorKey,
    this.placement = ModalCommandSurfacePlacement.topCenter,
    this.transition = ModalCommandSurfaceTransition.compact,
    this.constraints = const BoxConstraints(),
    this.width,
    this.topGap = 14,
    this.edgePadding = 8,
    this.animationDuration = HyprMotion.popup,
  });

  final ModalCommandSurfaceController controller;
  final double barHeight;
  final BorderRadius borderRadius;
  final String debugLabel;
  final ModalCommandSurfaceBuilder builder;
  final bool Function()? canOpen;
  final VoidCallback? onOpening;
  final VoidCallback? onOpened;
  final VoidCallback? onClosing;
  final VoidCallback? onDismissed;
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;
  final Map<ShortcutActivator, VoidCallback> shortcuts;
  final GlobalKey? anchorKey;
  final ModalCommandSurfacePlacement placement;
  final ModalCommandSurfaceTransition transition;
  final BoxConstraints constraints;
  final double? width;
  final double topGap;
  final double edgePadding;
  final Duration animationDuration;

  @override
  ConsumerState<ModalCommandSurface> createState() =>
      _ModalCommandSurfaceState();
}

class _ModalCommandSurfaceState extends ConsumerState<ModalCommandSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final LayerShellRegionManager _regionManager;
  final Object _regionOwner = Object();
  final GlobalKey _surfaceKey = GlobalKey();
  final GlobalKey _panelKey = GlobalKey();
  bool _isOpen = false;
  bool _visible = false;
  bool _regionUpdateScheduled = false;
  _ModalRegionMode? _pendingRegionMode;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
    _regionManager = ref.read(layerShellRegionManagerProvider);
    _animationController =
        AnimationController(vsync: this, duration: widget.animationDuration)
          ..value = 1
          ..addStatusListener(_handleAnimationStatus);
  }

  @override
  void didUpdateWidget(covariant ModalCommandSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller._detach(this);
      widget.controller._attach(this);
    }
    if (oldWidget.animationDuration != widget.animationDuration) {
      _animationController.duration = widget.animationDuration;
    }
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    unawaited(
      _regionManager.updateRegion(
        owner: _regionOwner,
        menuRect: null,
        radius: null,
        debugLabel: '${widget.debugLabel}-disposed',
      ),
    );
    _animationController
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();
    super.dispose();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _isOpen) {
      _scheduleRegionUpdate(_ModalRegionMode.exactPanel);
    }
    if (status == AnimationStatus.dismissed && !_isOpen) {
      setState(() => _visible = false);
    }
  }

  void _open() {
    if (_isOpen || !(widget.canOpen?.call() ?? true)) {
      return;
    }
    widget.onOpening?.call();
    setState(() {
      _visible = true;
      _isOpen = true;
    });
    widget.controller._notifyOpenChanged();
    _animationController.stop();
    _animationController.value = 1;
    _scheduleRegionUpdate(_ModalRegionMode.exactPanel);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_visible) {
        return;
      }
      widget.onOpened?.call();
      widget.focusNode?.requestFocus();
    });
  }

  void _close() {
    if (!_visible) {
      return;
    }
    widget.onClosing?.call();
    setState(() => _isOpen = false);
    widget.controller._notifyOpenChanged();
    _animationController.stop();
    _animationController.value = 0;
    setState(() => _visible = false);
    _scheduleRegionUpdate(_ModalRegionMode.barOnly);
  }

  void _dismiss() {
    if (!_visible && !_animationController.isAnimating) {
      return;
    }
    widget.onDismissed?.call();
    _animationController.stop();
    _animationController.value = 0;
    setState(() {
      _visible = false;
      _isOpen = false;
    });
    widget.controller._notifyOpenChanged();
    _scheduleRegionUpdate(_ModalRegionMode.barOnly);
  }

  void _scheduleRegionUpdate(_ModalRegionMode mode) {
    _pendingRegionMode = mode;
    if (_regionUpdateScheduled) {
      return;
    }
    _regionUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _regionUpdateScheduled = false;
      final _ModalRegionMode? mode = _pendingRegionMode;
      _pendingRegionMode = null;
      if (!mounted || mode == null) {
        return;
      }
      unawaited(_updateRegion(mode));
    });
  }

  Future<void> _updateRegion(_ModalRegionMode mode) async {
    if (mode == _ModalRegionMode.barOnly) {
      await _regionManager.updateRegion(
        owner: _regionOwner,
        menuRect: null,
        radius: null,
        debugLabel: '${widget.debugLabel}-closed',
      );
      return;
    }

    final Rect? rect = _resolvePanelRect();
    await _regionManager.updateRegion(
      owner: _regionOwner,
      menuRect: rect,
      radius: rect == null ? null : widget.borderRadius,
      captureAllClicks: rect != null,
      debugLabel: '${widget.debugLabel}-open',
    );
  }

  Rect? _resolvePanelRect() {
    final BuildContext? panelContext = _panelKey.currentContext;
    final BuildContext? surfaceContext = _surfaceKey.currentContext;
    final RenderBox? panelBox = panelContext?.findRenderObject() as RenderBox?;
    final RenderBox? surfaceBox =
        surfaceContext?.findRenderObject() as RenderBox?;
    if (panelBox == null || surfaceBox == null) {
      return null;
    }
    final Offset topLeft = panelBox.localToGlobal(
      Offset.zero,
      ancestor: surfaceBox,
    );
    return topLeft & panelBox.size;
  }

  Rect? _resolveAnchorRect() {
    final BuildContext? anchorContext = widget.anchorKey?.currentContext;
    final RenderBox? anchorBox =
        anchorContext?.findRenderObject() as RenderBox?;
    if (anchorBox == null || !anchorBox.hasSize) {
      return null;
    }
    final Offset topLeft = anchorBox.localToGlobal(Offset.zero);
    return topLeft & anchorBox.size;
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return const SizedBox.shrink();
    }

    Widget surface = KeyedSubtree(
      key: _surfaceKey,
      child: _buildInteractiveSurface(context),
    );

    if (widget.onKeyEvent != null) {
      surface = Focus(
        autofocus: true,
        focusNode: widget.focusNode,
        onKeyEvent: widget.onKeyEvent,
        child: surface,
      );
    }

    return Positioned.fill(child: surface);
  }

  Widget _buildInteractiveSurface(BuildContext context) {
    Widget panel = _buildPositionedPanel(context);
    if (widget.shortcuts.isNotEmpty) {
      panel = CallbackShortcuts(bindings: widget.shortcuts, child: panel);
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _close,
          child: const ColoredBox(color: Colors.transparent),
        ),
        panel,
      ],
    );
  }

  Widget _buildPositionedPanel(BuildContext context) {
    final Widget panel = _buildTransition(
      child: ConstrainedBox(
        constraints: widget.constraints,
        child: Material(
          key: _panelKey,
          color: Colors.transparent,
          child: widget.builder(context),
        ),
      ),
    );

    return switch (widget.placement) {
      ModalCommandSurfacePlacement.topCenter => Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: widget.barHeight + widget.topGap),
          child: panel,
        ),
      ),
      ModalCommandSurfacePlacement.anchorLeft => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = widget.width ?? widget.constraints.maxWidth;
          final double maxWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final Rect? anchorRect = _resolveAnchorRect();
          final double fallbackLeft = widget.edgePadding;
          final double anchoredLeft = anchorRect?.left ?? fallbackLeft;
          final double left = anchoredLeft
              .clamp(
                widget.edgePadding,
                math.max(
                  widget.edgePadding,
                  maxWidth - width - widget.edgePadding,
                ),
              )
              .toDouble();

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                left: left,
                top: widget.barHeight + widget.topGap,
                width: width,
                child: panel,
              ),
            ],
          );
        },
      ),
      ModalCommandSurfacePlacement.anchorRight => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = widget.width ?? widget.constraints.maxWidth;
          final double maxWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final Rect? anchorRect = _resolveAnchorRect();
          final double fallbackLeft = math.max(
            widget.edgePadding,
            (maxWidth - width) / 2,
          );
          final double anchoredLeft =
              (anchorRect?.right ?? fallbackLeft + width) - width;
          final double left = anchoredLeft
              .clamp(
                widget.edgePadding,
                math.max(
                  widget.edgePadding,
                  maxWidth - width - widget.edgePadding,
                ),
              )
              .toDouble();

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                left: left,
                top: widget.barHeight + widget.topGap,
                width: width,
                child: panel,
              ),
            ],
          );
        },
      ),
    };
  }

  Widget _buildTransition({required Widget child}) {
    final Animation<double> animation = _animationController;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (BuildContext context, Widget? child) {
        final double raw = animation.value.clamp(0.0, 1.0);
        final double progress = HyprMotion.popupCurve.transform(raw);
        return switch (widget.transition) {
          ModalCommandSurfaceTransition.compact => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.03),
              end: Offset.zero,
            ).animate(AlwaysStoppedAnimation<double>(progress)),
            child: FadeTransition(
              opacity: AlwaysStoppedAnimation<double>(progress),
              child: ScaleTransition(
                scale: AlwaysStoppedAnimation<double>(0.96 + (0.04 * progress)),
                child: child,
              ),
            ),
          ),
          ModalCommandSurfaceTransition.anchored => Transform.translate(
            offset: Offset(0, (1 - progress) * -18),
            child: Transform.scale(
              scale: 0.94 + (progress * 0.06),
              alignment: Alignment.topCenter,
              child: Opacity(opacity: progress, child: child),
            ),
          ),
        };
      },
    );
  }
}

enum _ModalRegionMode { exactPanel, barOnly }
