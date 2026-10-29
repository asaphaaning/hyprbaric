import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../theme/hypr_motion.dart';

/// Slides its child out sideways and closes the gap it leaves.
///
/// Nothing happens until [leaving] turns true; then, after [delay], the
/// child slides toward [direction] and fades, its height collapses, and
/// [onGone] fires so the owner can drop it for good. Turning [leaving] back
/// to false before then brings the child back.
class HyprLeave extends StatefulWidget {
  const HyprLeave({
    super.key,
    required this.leaving,
    required this.onGone,
    required this.child,
    this.delay = Duration.zero,
    this.direction = const Offset(.14, 0),
  });

  final bool leaving;
  final VoidCallback onGone;
  final Widget child;
  final Duration delay;

  /// Where the child slides, as a fraction of its own size.
  final Offset direction;

  @override
  State<HyprLeave> createState() => _HyprLeaveState();
}

class _HyprLeaveState extends State<HyprLeave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: HyprMotion.leave,
  );
  late final Animation<double> _slide = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, .62, curve: Curves.easeInCubic),
  );
  late final Animation<double> _collapse = CurvedAnimation(
    parent: _controller,
    curve: const Interval(.42, 1, curve: Cubic(0.32, 0.72, 0, 1)),
  );
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    if (widget.leaving) {
      unawaited(_leave());
    }
  }

  @override
  void didUpdateWidget(HyprLeave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.leaving != oldWidget.leaving) {
      if (widget.leaving) {
        unawaited(_leave());
      } else {
        _generation++;
        unawaited(_controller.reverse());
      }
    }
  }

  Future<void> _leave() async {
    final int generation = ++_generation;
    if (widget.delay > Duration.zero) {
      await Future<void>.delayed(widget.delay);
      if (!mounted || generation != _generation) {
        return;
      }
    }
    await _controller.forward().orCancel.catchError((Object _) {});
    if (mounted && generation == _generation && _controller.isCompleted) {
      widget.onGone();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: ReverseAnimation(_collapse),
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: ReverseAnimation(_slide),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: widget.direction,
          ).animate(_slide),
          child: IgnorePointer(ignoring: widget.leaving, child: widget.child),
        ),
      ),
    );
  }
}
