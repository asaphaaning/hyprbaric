import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../theme/hypr_motion.dart';

/// Eases its child in once, when it first appears.
///
/// The child drops into place by [offset] with a slight overshoot and fades
/// up after [delay]. It is paint-only: layout and hit testing are final from
/// the first frame, and later rebuilds never replay it.
class HyprEntrance extends StatefulWidget {
  const HyprEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, -12),
    this.scale = .96,
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  /// Scale the child starts from, about its centre.
  final double scale;

  @override
  State<HyprEntrance> createState() => _HyprEntranceState();
}

class _HyprEntranceState extends State<HyprEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: HyprMotion.entrance + widget.delay,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double total = (HyprMotion.entrance + widget.delay).inMicroseconds
        .toDouble();
    final double start = widget.delay.inMicroseconds / total;
    return _EntranceFace(
      animation: _controller,
      start: start,
      offset: widget.offset,
      scale: widget.scale,
      child: widget.child,
    );
  }
}

class _EntranceFace extends SingleChildRenderObjectWidget {
  const _EntranceFace({
    required this.animation,
    required this.start,
    required this.offset,
    required this.scale,
    required super.child,
  });

  final Animation<double> animation;
  final double start;
  final Offset offset;
  final double scale;

  @override
  _RenderEntrance createRenderObject(BuildContext context) => _RenderEntrance(
    animation: animation,
    start: start,
    offset: offset,
    scale: scale,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderEntrance renderObject) {
    renderObject
      ..start = start
      ..offset = offset
      ..scale = scale;
  }
}

class _RenderEntrance extends RenderProxyBox {
  _RenderEntrance({
    required this.animation,
    required this.start,
    required this.offset,
    required this.scale,
  });

  final Animation<double> animation;
  double start;
  Offset offset;
  double scale;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    animation.addListener(_tick);
  }

  @override
  void detach() {
    animation.removeListener(_tick);
    super.detach();
  }

  void _tick() => markNeedsPaint();

  @override
  void paint(PaintingContext context, Offset paintOffset) {
    final RenderBox? child = this.child;
    if (child == null) {
      return;
    }
    final double t = animation.value;
    if (t >= 1) {
      context.paintChild(child, paintOffset);
      return;
    }
    final double local = ((t - start) / (1 - start)).clamp(0.0, 1.0);
    if (local <= 0) {
      return;
    }
    final double settle = HyprMotion.entranceCurve.transform(local);
    final double opacity = Curves.easeOut.transform(
      (local / .6).clamp(0.0, 1.0),
    );
    final double factor = scale + (1 - scale) * settle;
    final Offset shift = offset * (1 - settle);
    final Offset centre = child.size.center(Offset.zero);
    final Matrix4 transform = Matrix4.identity()
      ..translateByDouble(
        paintOffset.dx + shift.dx + centre.dx,
        paintOffset.dy + shift.dy + centre.dy,
        0,
        1,
      )
      ..scaleByDouble(factor, factor, 1, 1)
      ..translateByDouble(-centre.dx, -centre.dy, 0, 1);
    context.pushOpacity(
      Offset.zero,
      (opacity * 255).round(),
      (PaintingContext context, Offset _) => context.pushTransform(
        needsCompositing,
        Offset.zero,
        transform,
        (PaintingContext context, Offset offset) =>
            context.paintChild(child, offset),
      ),
    );
  }
}
