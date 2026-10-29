import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../theme/hypr_motion.dart';

/// Which way a [HyprFlip] turns over: the incoming content arrives from the
/// opposite side and the outgoing content leaves toward this one.
enum HyprFlipDirection {
  up,
  down;

  double get sign => switch (this) {
    HyprFlipDirection.up => -1,
    HyprFlipDirection.down => 1,
  };
}

/// Flips between children whenever [flipKey] changes.
///
/// The outgoing child lifts away and fades while the incoming one rises into
/// place, slightly scaled, like a split-flap tile. Only the incoming child
/// takes part in layout and hit testing; the outgoing one is painted around
/// the same centre without affecting its parent. A change mid-flip restarts
/// from what is currently showing, so rapid updates never queue.
class HyprFlip extends StatefulWidget {
  const HyprFlip({
    super.key,
    required this.flipKey,
    required this.child,
    this.direction = HyprFlipDirection.up,
    this.distance = HyprMotion.flipDistance,
    this.duration = HyprMotion.flip,
  });

  /// Identity of [child]; a different key flips to the new child.
  final Object? flipKey;
  final Widget child;
  final HyprFlipDirection direction;
  final double distance;
  final Duration duration;

  @override
  State<HyprFlip> createState() => _HyprFlipState();
}

class _HyprFlipState extends State<HyprFlip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );
  Widget? _outgoing;
  Object? _outgoingKey;
  HyprFlipDirection _direction = HyprFlipDirection.up;

  @override
  void didUpdateWidget(HyprFlip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (oldWidget.flipKey != widget.flipKey) {
      _outgoing = oldWidget.child;
      _outgoingKey = oldWidget.flipKey;
      _direction = widget.direction;
      _controller.forward(from: 0).whenCompleteOrCancel(() {
        if (mounted && _controller.isCompleted) {
          setState(() {
            _outgoing = null;
            _outgoingKey = null;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget? outgoing = _outgoing;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: <Widget>[
        if (outgoing != null)
          IgnorePointer(
            key: ValueKey<Object?>(('out', _outgoingKey)),
            child: ExcludeSemantics(
              child: _FlipFace(
                animation: _controller,
                leaving: true,
                sign: _direction.sign,
                distance: widget.distance,
                child: outgoing,
              ),
            ),
          ),
        _FlipFace(
          key: const ValueKey<String>('in'),
          animation: _controller,
          leaving: false,
          sign: _direction.sign,
          distance: widget.distance,
          child: KeyedSubtree(
            key: ValueKey<Object?>(widget.flipKey),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _FlipFace extends SingleChildRenderObjectWidget {
  const _FlipFace({
    super.key,
    required this.animation,
    required this.leaving,
    required this.sign,
    required this.distance,
    required super.child,
  });

  final Animation<double> animation;
  final bool leaving;
  final double sign;
  final double distance;

  @override
  _RenderFlipFace createRenderObject(BuildContext context) => _RenderFlipFace(
    animation: animation,
    leaving: leaving,
    sign: sign,
    distance: distance,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderFlipFace renderObject) {
    renderObject
      ..animation = animation
      ..leaving = leaving
      ..sign = sign
      ..distance = distance;
  }
}

/// Paint-only flip face. A leaving face takes no space in its parent.
class _RenderFlipFace extends RenderProxyBox {
  _RenderFlipFace({
    required Animation<double> animation,
    required this.leaving,
    required this.sign,
    required this.distance,
  }) : _animation = animation;

  bool leaving;
  double sign;
  double distance;

  Animation<double> _animation;
  set animation(Animation<double> value) {
    if (identical(value, _animation)) {
      return;
    }
    if (attached) {
      _animation.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _animation = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _animation.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void performLayout() {
    if (!leaving) {
      super.performLayout();
      return;
    }
    child?.layout(constraints.loosen(), parentUsesSize: true);
    size = constraints.smallest;
  }

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      !leaving && super.hitTest(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? child = this.child;
    if (child == null) {
      return;
    }
    final double t = _animation.value.clamp(0.0, 1.0);
    final double travel;
    final double opacity;
    final double scale;
    if (leaving) {
      final double gone = HyprMotion.flipOutCurve.transform(
        (t / HyprMotion.flipOutSpan).clamp(0.0, 1.0),
      );
      travel = sign * distance * gone;
      opacity = 1 - gone;
      scale = 1 - .06 * gone;
    } else {
      final double local =
          ((t - HyprMotion.flipInDelay) / (1 - HyprMotion.flipInDelay)).clamp(
            0.0,
            1.0,
          );
      final double settled = HyprMotion.flipInCurve.transform(local);
      travel = -sign * distance * (1 - settled);
      opacity = Curves.easeOut.transform(local);
      scale = .94 + .06 * settled;
    }
    final int alpha = (opacity * 255).round();
    if (alpha <= 0) {
      return;
    }

    // A leaving face is centred on its zero-sized slot.
    final Offset origin = leaving
        ? offset + size.center(Offset.zero) - child.size.center(Offset.zero)
        : offset;
    if (alpha >= 255 && travel == 0 && scale == 1) {
      context.paintChild(child, origin);
      return;
    }
    final Offset centre = child.size.center(Offset.zero);
    final Matrix4 transform = Matrix4.identity()
      ..translateByDouble(
        origin.dx + centre.dx,
        origin.dy + centre.dy + travel,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-centre.dx, -centre.dy, 0, 1);
    context.pushOpacity(Offset.zero, alpha, (
      PaintingContext context,
      Offset _,
    ) {
      context.pushTransform(
        needsCompositing,
        Offset.zero,
        transform,
        (PaintingContext context, Offset offset) =>
            context.paintChild(child, offset),
      );
    });
  }
}
