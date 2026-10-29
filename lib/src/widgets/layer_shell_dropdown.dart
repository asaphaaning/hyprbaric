import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../layer_shell_hit_region.dart';
import '../state/providers.dart';
import '../theme/hypr_motion.dart';
import 'layer_shell_dropdown_model.dart';
import 'layer_shell_dropdown_overlay.dart';
import 'popover_handoff.dart';

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
    this.menuOffset = Offset.zero,
    this.onClosed,
    this.handoff = LayerShellDropdownHandoff.none,
  });

  final LayerShellDropdownController? controller;
  final BorderRadius menuRadius;
  final LayerShellDropdownAnchor horizontalAnchor;
  final double? menuWidth;
  final double verticalGap;

  /// Nudge applied to the menu's resting position.
  ///
  /// A panel whose own padding should fall outside the button it hangs from,
  /// such as a menu bar aligning its first label under its heading, shifts by
  /// that padding rather than by moving the button.
  final Offset menuOffset;

  /// Called whenever the menu leaves the screen, including a dismissal from
  /// the barrier, so an owner tracking which menu is open stays in step.
  final VoidCallback? onClosed;

  /// Whether switching between this and another [LayerShellDropdownHandoff.morph]
  /// dropdown glides one shared shell between them.
  final LayerShellDropdownHandoff handoff;
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
    with TickerProviderStateMixin {
  late LayerShellDropdownController _controller;
  late final LayerShellRegionManager _regionManager;
  late final AnimationController _animationController;
  late final AnimationController _handoffController;
  late final PopoverHandoff _handoff;

  /// The shell this dropdown is gliding in from another popover.
  PopoverMorph? _arrival;

  /// The successor's shell this dropdown's contents are clearing out of.
  PopoverMorph? _exit;

  /// Whether the overlay is only painting its departing contents.
  bool _leaving = false;
  final Object _regionOwner = Object();
  final LayerLink _buttonLayerLink = LayerLink();
  final GlobalKey _buttonKey = GlobalKey();
  GlobalKey? _menuKey;
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
    _handoff = ref.read(popoverHandoffProvider);
    _handoffController = AnimationController(
      vsync: this,
      duration: HyprMotion.handoff,
    );
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
    _endArrival();
    _animationController.dispose();
    _removeOverlay();
    _handoffController.dispose();
    super.dispose();
  }

  void _open() {
    if (_leaving) {
      _removeOverlay();
    }
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

    final Widget menuContent =
        NotificationListener<SizeChangedLayoutNotification>(
          onNotification: (_) {
            _scheduleRegionUpdate(_RegionSyncMode.exactMenu);
            return false;
          },
          child: SizeChangedLayoutNotifier(
            child: RepaintBoundary(
              child: widget.menuBuilder(context, _controller),
            ),
          ),
        );
    final bool measureTransitionBounds =
        widget.transition == LayerShellDropdownTransition.grow;
    final bool handsOff = widget.handoff == LayerShellDropdownHandoff.morph;
    // Each opening owns its measurement key, including same-frame reopens
    // while the previous entry is still waiting to unmount.
    final menuKey = GlobalKey();
    _menuKey = menuKey;

    _overlayEntry = OverlayEntry(
      builder: (BuildContext overlayContext) {
        final double barHeight = _regionManager.barHeight.toDouble();
        final Widget hostedContent = handsOff
            ? PopoverHandoffHost(
                morph: _exit ?? _arrival,
                role: _exit == null
                    ? PopoverMorphRole.arriving
                    : PopoverMorphRole.departing,
                overlay: overlayState,
                child: menuContent,
              )
            : menuContent;
        final Widget transitionChild = measureTransitionBounds
            ? hostedContent
            : KeyedSubtree(key: menuKey, child: hostedContent);
        return Positioned.fill(
          child: Stack(
            children: <Widget>[
              Positioned(
                top: barHeight,
                right: 0,
                bottom: 0,
                left: 0,
                child: IgnorePointer(
                  ignoring: _leaving,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _controller.close,
                  ),
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
                  clip: !handsOff,
                  menuKey: measureTransitionBounds ? menuKey : null,
                  child: transitionChild,
                )
              else
                CompositedTransformFollower(
                  link: _buttonLayerLink,
                  showWhenUnlinked: false,
                  targetAnchor: _followerTarget,
                  followerAnchor: _followerAnchor,
                  offset: Offset(
                    _menuOffsetX + widget.menuOffset.dx,
                    _verticalMenuOffset(overlayState) + widget.menuOffset.dy,
                  ),
                  child: KeyedSubtree(
                    key: measureTransitionBounds ? menuKey : null,
                    child: DropdownTransition(
                      animation: _animationController,
                      animationCurve: widget.animationCurve,
                      transition: widget.transition,
                      transitionAlignment: widget.transitionAlignment,
                      revealAlignment: _revealAlignment,
                      clip: !handsOff,
                      child: transitionChild,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );

    final PopoverDeparture? departure = handsOff ? _handoff.claim() : null;
    if (departure != null) {
      _beginArrival(departure, buttonBox: buttonBox, overlayBox: overlayBox);
      // Beneath the departing contents, so they clear out over the new shell.
      overlayState.insert(_overlayEntry!, below: departure.entry);
    } else {
      // Opening from a closed bar is instant; motion is for switching.
      overlayState.insert(_overlayEntry!);
    }
    setState(() {
      _isOpen = true;
    });
    _animationController.stop();
    _animationController.value = 1.0;
    _scheduleRegionUpdate(_RegionSyncMode.exactMenu);
  }

  /// Where the menu attaches on the button, when the menu sizes itself.
  ///
  /// The width-anchored path resolves this arithmetically; without a declared
  /// width the follower does it, and it honours the same anchor so the two
  /// paths do not disagree about which edge a menu hangs from.
  Alignment get _followerTarget => switch (widget.horizontalAnchor) {
    LayerShellDropdownAnchor.left => Alignment.bottomLeft,
    LayerShellDropdownAnchor.center => Alignment.bottomCenter,
    LayerShellDropdownAnchor.right => Alignment.bottomRight,
  };

  /// Where the menu rests inside the box the follower gives it.
  ///
  /// Matching the anchor makes the menu land where it belongs on its first
  /// frame, so the correction below has nothing to do but keep it on screen.
  Alignment get _revealAlignment => switch (widget.horizontalAnchor) {
    LayerShellDropdownAnchor.left => Alignment.topLeft,
    LayerShellDropdownAnchor.center => Alignment.topCenter,
    LayerShellDropdownAnchor.right => Alignment.topRight,
  };

  Alignment get _followerAnchor => switch (widget.horizontalAnchor) {
    LayerShellDropdownAnchor.left => Alignment.topLeft,
    LayerShellDropdownAnchor.center => Alignment.topCenter,
    LayerShellDropdownAnchor.right => Alignment.topRight,
  };

  void _close() {
    if (!_isOpen && !_animationController.isAnimating) {
      return;
    }
    // Closing into a closed bar is instant, like opening from one.
    setState(() {
      _isOpen = false;
    });
    widget.onClosed?.call();
    _animationController.stop();
    _animationController.value = 0.0;
    _endArrival();
    _removeOverlay();
    _scheduleRegionUpdate(_RegionSyncMode.barOnly);
  }

  void _dismiss() {
    if (!_isOpen &&
        _overlayEntry == null &&
        !_animationController.isAnimating) {
      return;
    }
    if (_leaving) {
      // Already clearing out; its handoff, or the end of this frame, removes it.
      return;
    }
    if (_isOpen &&
        !_leaving &&
        widget.handoff == LayerShellDropdownHandoff.morph &&
        _depart()) {
      return;
    }
    if (mounted) {
      setState(() {
        _isOpen = false;
      });
    } else {
      _isOpen = false;
    }
    widget.onClosed?.call();
    _animationController.stop();
    _animationController.value = 0.0;
    _endArrival();
    _removeOverlay();
    _scheduleRegionUpdate(_RegionSyncMode.barOnly);
  }

  /// Glides in from [departure]'s frame and button to this dropdown's own.
  void _beginArrival(
    PopoverDeparture departure, {
    required RenderBox buttonBox,
    required RenderBox overlayBox,
  }) {
    final PopoverMorph morph = PopoverMorph(
      animation: _handoffController,
      from: departure.frame,
      fromRadius: departure.radius,
      fromAnchor: departure.anchor,
      toAnchor: overlayRect(buttonBox, overlayBox),
    );
    departure.follow(morph);
    _runArrival(morph, HyprMotion.handoff);
  }

  void _runArrival(PopoverMorph morph, Duration duration) {
    _arrival = morph;
    _handoffController
      ..duration = duration
      ..value = 0
      ..forward().whenCompleteOrCancel(() {
        if (identical(_arrival, morph)) {
          _endArrival();
          _overlayEntry?.markNeedsBuild();
        }
      });
  }

  /// Settles or abandons the current arrival, releasing its predecessor.
  void _endArrival() {
    final PopoverMorph? morph = _arrival;
    if (morph == null) {
      return;
    }
    _arrival = null;
    _handoffController.stop();
    morph.end();
  }

  /// Leaves while offering this dropdown's place to a successor.
  ///
  /// The overlay stays mounted, inert, until the end of the frame. A
  /// successor that claims it drives its contents out through the shared
  /// shell; otherwise it is removed exactly as a plain dismissal would.
  bool _depart() {
    final OverlayEntry? entry = _overlayEntry;
    final Rect? frame = _arrival?.frame ?? _measureMenuFrame();
    final Rect? anchor = _measureButton();
    if (entry == null || frame == null || anchor == null) {
      return false;
    }

    _endArrival();
    setState(() {
      _isOpen = false;
    });
    widget.onClosed?.call();
    _leaving = true;
    entry.markNeedsBuild();
    _scheduleRegionUpdate(_RegionSyncMode.barOnly);
    _handoff.offer(
      PopoverDeparture(
        frame: frame,
        radius: widget.menuRadius,
        anchor: anchor,
        entry: entry,
        onClaimed: (PopoverMorph morph) {
          if (!identical(_overlayEntry, entry)) {
            return;
          }
          _exit = morph;
          entry.markNeedsBuild();
          morph.onEnd(() {
            if (identical(_overlayEntry, entry)) {
              _removeOverlay();
            }
          });
        },
        onDeclined: () {
          if (identical(_overlayEntry, entry)) {
            _removeOverlay();
          }
        },
      ),
    );
    return true;
  }

  Rect? _measureMenuFrame() {
    final RenderBox? menuBox =
        _menuKey?.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? overlayBox = _overlayBox();
    if (menuBox == null || overlayBox == null || !menuBox.hasSize) {
      return null;
    }
    return overlayRect(menuBox, overlayBox);
  }

  Rect? _measureButton() {
    final RenderBox? buttonBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? overlayBox = _overlayBox();
    if (buttonBox == null || overlayBox == null) {
      return null;
    }
    return overlayRect(buttonBox, overlayBox);
  }

  RenderBox? _overlayBox() =>
      Overlay.of(context, rootOverlay: true).context.findRenderObject()
          as RenderBox?;

  void _removeOverlay() {
    final entry = _overlayEntry;
    _overlayEntry = null;
    _leaving = false;
    _exit = null;
    _menuKey = null;
    _pendingRegionMode = null;
    _menuOffsetX = 0;
    entry?.remove();
    entry?.dispose();
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

    final BuildContext? menuContext = _menuKey?.currentContext;
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

    final Rect buttonRect = overlayRect(buttonBox, overlayBox);
    final double desiredLeft = _desiredMenuLeft(
      buttonRect: buttonRect,
      menuWidth: widget.menuWidth ?? menuBox.size.width,
    );
    final double adjustedLeft = desiredLeft.clamp(
      0.0,
      math.max(0.0, overlayBox.size.width - menuBox.size.width),
    );
    // The measured position already contains the offset applied last frame,
    // so the correction accumulates rather than replaces it. Replacing it
    // makes the menu chase its own compensation: the reveal transition centres
    // the menu inside a full-width box, so the correction is never zero, and
    // `x = A - P` then alternates between the two positions every frame for as
    // long as the menu stays open.
    //
    // Only the follower is placed by this offset. The width-anchored overlay
    // positions itself and reads nothing here, so its correction stays
    // absolute; accumulating there would drift without bound.
    final double offsetX = widget.menuWidth == null
        ? _menuOffsetX + (adjustedLeft - topLeft.dx)
        : adjustedLeft - topLeft.dx;
    if ((_menuOffsetX - offsetX).abs() > 0.5) {
      _menuOffsetX = offsetX;
      _overlayEntry?.markNeedsBuild();
      final entry = _overlayEntry;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (entry != null && identical(_overlayEntry, entry) && mounted) {
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

    final Rect buttonRect = overlayRect(buttonBox, overlayBox);
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

    final Rect buttonRect = overlayRect(buttonBox, overlayBox);
    final double buttonBottom = buttonRect.bottom;
    final double barBottom = _regionManager.barHeight.toDouble();
    return widget.verticalGap + math.max(0, barBottom - buttonBottom);
  }

  double _desiredMenuLeft({
    required Rect buttonRect,
    required double menuWidth,
  }) {
    return widget.menuOffset.dx +
        switch (widget.horizontalAnchor) {
          LayerShellDropdownAnchor.left => buttonRect.left,
          LayerShellDropdownAnchor.center =>
            buttonRect.center.dx - (menuWidth / 2),
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
