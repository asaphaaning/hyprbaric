import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/hypr_motion.dart';

/// Shared exchange where a closing popover offers its place to the next one.
///
/// Bar toggles dismiss the open popover and open another in the same frame.
/// A departure offered here lives until the end of that frame: the popover
/// opening in its place claims it and turns the switch into one gliding
/// shell, and an unclaimed departure simply leaves.
final popoverHandoffProvider = Provider<PopoverHandoff>(
  (_) => PopoverHandoff(),
);

/// Pairs a departing popover with the popover opening in its place.
final class PopoverHandoff {
  PopoverDeparture? _pending;

  /// Offers [departure] to a popover opening later in the same frame.
  void offer(PopoverDeparture departure) {
    _pending?._decline();
    _pending = departure;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (identical(_pending, departure)) {
        _pending = null;
        departure._decline();
      }
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// Takes the departure offered this frame, if any.
  PopoverDeparture? claim() {
    final PopoverDeparture? departure = _pending;
    _pending = null;
    return departure;
  }
}

/// A popover that has left its button and may hand its shell over.
final class PopoverDeparture {
  PopoverDeparture({
    required this.frame,
    required this.radius,
    required this.anchor,
    required this.entry,
    required void Function(PopoverMorph morph) onClaimed,
    required VoidCallback onDeclined,
  }) : _onClaimed = onClaimed,
       _onDeclined = onDeclined;

  /// The departing popover's painted frame, in overlay coordinates.
  final Rect frame;

  /// The departing popover's outline.
  final BorderRadius radius;

  /// The button the departing popover hung from, in overlay coordinates.
  final Rect anchor;

  /// The overlay still painting the departing contents.
  final OverlayEntry entry;

  final void Function(PopoverMorph morph) _onClaimed;
  final VoidCallback _onDeclined;
  bool _settled = false;

  /// Hands the departing contents to [morph], which now drives their exit.
  void follow(PopoverMorph morph) {
    if (_settled) {
      return;
    }
    _settled = true;
    _onClaimed(morph);
  }

  void _decline() {
    if (_settled) {
      return;
    }
    _settled = true;
    _onDeclined();
  }
}

/// Which side of a handoff a popover is on.
enum PopoverMorphRole {
  /// Paints the shared shell and settles its sections into it.
  arriving,

  /// Clears its sections out of the shell, which it no longer paints.
  departing,
}

/// Horizontal direction the shell travels between two anchors.
enum PopoverHandoffDirection {
  leftward,
  rightward;

  double get sign => switch (this) {
    PopoverHandoffDirection.leftward => -1,
    PopoverHandoffDirection.rightward => 1,
  };
}

/// One glass shell travelling from a departed popover to its successor.
final class PopoverMorph {
  PopoverMorph({
    required this.animation,
    required this.from,
    required this.fromRadius,
    required this.fromAnchor,
    required this.toAnchor,
  });

  /// Linear handoff progress, from departure to rest.
  final Animation<double> animation;

  /// The departed popover's frame, in overlay coordinates.
  final Rect from;
  final BorderRadius fromRadius;

  /// Buttons the shell leaves and reaches, in overlay coordinates.
  final Rect fromAnchor;
  final Rect toAnchor;

  Rect? _to;
  final List<VoidCallback> _endListeners = <VoidCallback>[];
  bool _ended = false;

  PopoverHandoffDirection get direction =>
      toAnchor.center.dx >= fromAnchor.center.dx
      ? PopoverHandoffDirection.rightward
      : PopoverHandoffDirection.leftward;

  /// Eased progress of the shell's geometry.
  double get shellProgress =>
      HyprMotion.handoffShellCurve.transform(animation.value.clamp(0.0, 1.0));

  /// The shell's frame this frame, in overlay coordinates.
  ///
  /// The arriving popover reports its resting frame when it paints, before
  /// the departing contents above it read this to clip themselves.
  ///
  /// The arriving popover reports its resting frame when it paints, before
  /// the departing contents above it read this to clip themselves.
  Rect get frame => Rect.lerp(from, _to ?? from, shellProgress)!;

  /// The button the shell is currently travelling over.
  Rect get anchor => Rect.lerp(fromAnchor, toAnchor, shellProgress)!;

  /// Calls [listener] once when the handoff completes or is abandoned.
  void onEnd(VoidCallback listener) {
    if (_ended) {
      listener();
      return;
    }
    _endListeners.add(listener);
  }

  /// Ends the handoff, releasing the departing contents.
  void end() {
    if (_ended) {
      return;
    }
    _ended = true;
    final List<VoidCallback> listeners = List<VoidCallback>.of(_endListeners);
    _endListeners.clear();
    for (final VoidCallback listener in listeners) {
      listener();
    }
  }
}

/// Where a popover's own surface paints while a handoff is under way.
///
/// The first popover surface below a [PopoverHandoffHost] consumes this:
/// the arriving one paints the travelling shell instead of its resting
/// outline, and the departing one paints no glass at all, only contents
/// clipped to the shell.
final class PopoverMorphFrame {
  const PopoverMorphFrame._(this.morph, this.role, this._origin);

  final PopoverMorph morph;
  final PopoverMorphRole role;
  final _HostOrigin _origin;

  /// Repaints chrome and reclips contents as the shell moves.
  Listenable get repaint => morph.animation;

  /// Whether this surface paints the shell's glass.
  bool get paintsGlass => role == PopoverMorphRole.arriving;

  /// The shell's frame relative to a surface painted at the host's origin.
  Rect localFrame() => morph.frame.shift(-_origin.value);

  /// The shell's outline, easing from the departed popover's to [resting].
  BorderRadius radius(BorderRadius resting) =>
      BorderRadius.lerp(morph.fromRadius, resting, morph.shellProgress)!;

  /// The shell's superellipse relative to the surface.
  RSuperellipse shape(BorderRadius resting) =>
      radius(resting).resolve(TextDirection.ltr).toRSuperellipse(localFrame());
}

/// Publishes the handoff to the popover contents beneath it.
///
/// Every [PopoverStaggerItem] below follows the handoff. Only the first
/// popover surface consumes [frame]; nested surfaces such as an output
/// picker's menu render as they always do.
class PopoverMorphScope extends InheritedWidget {
  const PopoverMorphScope._({
    required this.frame,
    required this.consumed,
    required super.child,
  });

  final PopoverMorphFrame? frame;
  final bool consumed;

  /// The handoff frame for the nearest unclaimed popover surface.
  static PopoverMorphFrame? surfaceFrameOf(BuildContext context) {
    final PopoverMorphScope? scope = context
        .dependOnInheritedWidgetOfExactType<PopoverMorphScope>();
    if (scope == null || scope.consumed) {
      return null;
    }
    return scope.frame;
  }

  /// Marks the handoff frame as painted by the surface wrapping [child].
  ///
  /// Always wraps, so the subtree keeps its state when a handoff starts or
  /// ends; stagger items below still follow the handoff.
  static Widget consume(BuildContext context, Widget child) {
    final PopoverMorphScope? scope = context
        .dependOnInheritedWidgetOfExactType<PopoverMorphScope>();
    return PopoverMorphScope._(
      frame: scope?.frame,
      consumed: true,
      child: child,
    );
  }

  @override
  bool updateShouldNotify(PopoverMorphScope oldWidget) =>
      oldWidget.frame != frame || oldWidget.consumed != consumed;
}

/// Hosts one popover's contents across handoffs.
///
/// It is always present around a handing-off popover, so the contents keep
/// their state when a handoff starts and ends. With no [morph] it paints its
/// child unchanged.
class PopoverHandoffHost extends StatefulWidget {
  const PopoverHandoffHost({
    super.key,
    required this.morph,
    required this.role,
    required this.overlay,
    required this.child,
  });

  final PopoverMorph? morph;
  final PopoverMorphRole role;

  /// The overlay both popovers share coordinates with.
  final OverlayState overlay;
  final Widget child;

  @override
  State<PopoverHandoffHost> createState() => _PopoverHandoffHostState();
}

class _PopoverHandoffHostState extends State<PopoverHandoffHost> {
  final _HostOrigin _origin = _HostOrigin();

  @override
  Widget build(BuildContext context) {
    final PopoverMorph? morph = widget.morph;
    return PopoverMorphScope._(
      frame: morph == null
          ? null
          : PopoverMorphFrame._(morph, widget.role, _origin),
      consumed: false,
      child: _HandoffPaint(
        morph: morph,
        role: widget.role,
        origin: _origin,
        overlay: widget.overlay,
        child: widget.child,
      ),
    );
  }
}

final class _HostOrigin {
  Offset value = Offset.zero;
}

class _HandoffPaint extends SingleChildRenderObjectWidget {
  const _HandoffPaint({
    required this.morph,
    required this.role,
    required this.origin,
    required this.overlay,
    required super.child,
  });

  final PopoverMorph? morph;
  final PopoverMorphRole role;
  final _HostOrigin origin;
  final OverlayState overlay;

  @override
  _RenderHandoffPaint createRenderObject(BuildContext context) =>
      _RenderHandoffPaint(
        morph: morph,
        role: role,
        origin: origin,
        overlay: overlay,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHandoffPaint renderObject,
  ) {
    renderObject
      ..morph = morph
      ..role = role
      ..overlay = overlay;
  }
}

class _RenderHandoffPaint extends RenderProxyBox {
  _RenderHandoffPaint({
    required PopoverMorph? morph,
    required PopoverMorphRole role,
    required _HostOrigin origin,
    required this.overlay,
  }) : _morph = morph,
       _role = role,
       _origin = origin;

  final _HostOrigin _origin;
  OverlayState overlay;

  PopoverMorph? _morph;
  set morph(PopoverMorph? value) {
    if (identical(value, _morph)) {
      return;
    }
    if (attached) {
      _morph?.animation.removeListener(markNeedsPaint);
      value?.animation.addListener(markNeedsPaint);
    }
    _morph = value;
    markNeedsPaint();
  }

  PopoverMorphRole _role;
  set role(PopoverMorphRole value) {
    if (value == _role) {
      return;
    }
    _role = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _morph?.animation.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _morph?.animation.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_morph != null && _role == PopoverMorphRole.departing) {
      return false;
    }
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderObject? overlayBox = overlay.context.findRenderObject();
    _origin.value = overlayBox == null
        ? localToGlobal(Offset.zero)
        : localToGlobal(Offset.zero, ancestor: overlayBox);

    final PopoverMorph? morph = _morph;
    if (morph == null) {
      super.paint(context, offset);
      return;
    }

    switch (_role) {
      case PopoverMorphRole.arriving:
        morph._to = _origin.value & size;
        super.paint(context, offset);
      case PopoverMorphRole.departing:
        final double t = morph.animation.value.clamp(0.0, 1.0);
        final double fade =
            1 -
            HyprMotion.handoffExitFadeCurve.transform(
              (t / (HyprMotion.handoffExitSpan + .04)).clamp(0.0, 1.0),
            );
        if (fade <= 0) {
          return;
        }
        context.pushOpacity(offset, (fade * 255).round(), super.paint);
    }
  }
}

/// A section of a popover that staggers in and out during handoffs.
///
/// Sections arrive from the direction the shell travelled, one after the
/// other in [index] order, and depart the opposite way. Outside a handoff it
/// is its child.
class PopoverStaggerItem extends StatelessWidget {
  const PopoverStaggerItem({
    super.key,
    required this.index,
    required this.child,
  });

  /// Position in the popover's reading order, starting at zero.
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final PopoverMorphScope? scope = context
        .dependOnInheritedWidgetOfExactType<PopoverMorphScope>();
    final PopoverMorphFrame? frame = scope?.frame;
    return _StaggerTransform(
      morph: frame?.morph,
      role: frame?.role ?? PopoverMorphRole.arriving,
      index: index,
      child: child,
    );
  }
}

class _StaggerTransform extends SingleChildRenderObjectWidget {
  const _StaggerTransform({
    required this.morph,
    required this.role,
    required this.index,
    required super.child,
  });

  final PopoverMorph? morph;
  final PopoverMorphRole role;
  final int index;

  @override
  _RenderStagger createRenderObject(BuildContext context) =>
      _RenderStagger(morph: morph, role: role, index: index);

  @override
  void updateRenderObject(BuildContext context, _RenderStagger renderObject) {
    renderObject
      ..morph = morph
      ..role = role
      ..index = index;
  }
}

/// Paint-only stagger: layout and hit targets stay where they rest.
class _RenderStagger extends RenderProxyBox {
  _RenderStagger({
    required PopoverMorph? morph,
    required this.role,
    required this.index,
  }) : _morph = morph;

  PopoverMorphRole role;
  int index;

  PopoverMorph? _morph;
  set morph(PopoverMorph? value) {
    if (identical(value, _morph)) {
      return;
    }
    if (attached) {
      _morph?.animation.removeListener(markNeedsPaint);
      value?.animation.addListener(markNeedsPaint);
    }
    _morph = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _morph?.animation.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _morph?.animation.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final PopoverMorph? morph = _morph;
    if (morph == null) {
      super.paint(context, offset);
      return;
    }

    final double t = morph.animation.value.clamp(0.0, 1.0);
    final double sign = morph.direction.sign;
    final double opacity;
    final Offset shift;
    switch (role) {
      case PopoverMorphRole.arriving:
        final double start =
            HyprMotion.handoffEnterStart +
            (index * HyprMotion.handoffEnterStagger);
        final double local = ((t - start) / HyprMotion.handoffEnterSpan).clamp(
          0.0,
          1.0,
        );
        final double settled = HyprMotion.handoffEnterCurve.transform(local);
        opacity = Curves.easeOut.transform(local);
        shift = Offset(
          sign * HyprMotion.handoffTravel * (1 - settled),
          HyprMotion.handoffRise * (1 - settled),
        );
      case PopoverMorphRole.departing:
        final double start = index * HyprMotion.handoffExitStagger;
        final double local = ((t - start) / HyprMotion.handoffExitSpan).clamp(
          0.0,
          1.0,
        );
        final double gone = HyprMotion.handoffExitCurve.transform(local);
        opacity = 1 - HyprMotion.handoffExitFadeCurve.transform(local);
        shift = Offset(
          -sign * HyprMotion.handoffTravel * gone,
          -HyprMotion.handoffRise * .4 * gone,
        );
    }

    final int alpha = (opacity * 255).round();
    if (alpha <= 0) {
      return;
    }
    final Offset at = offset + shift;
    if (alpha >= 255) {
      super.paint(context, at);
      return;
    }
    context.pushOpacity(at, alpha, super.paint);
  }
}
