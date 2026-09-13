import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

/// A keyed fade-through with bounded interruption behavior.
///
/// A new key starts a transition when settled. Another change cancels it and
/// displays the latest content immediately, unless only [completionGrace]
/// remains: then the current transition finishes before showing the latest
/// content. Updates never queue additional animations. Reduced motion settles
/// immediately. Give [child] a value key identifying its content.
class HyprTextSwap extends StatefulWidget {
  const HyprTextSwap({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 220),
    this.completionGrace = const Duration(milliseconds: 40),
  }) : assert(duration >= Duration.zero, 'Duration must not be negative'),
       assert(completionGrace >= Duration.zero, 'Grace must not be negative');

  /// Content whose key determines whether a transition is needed.
  final Widget child;

  /// Total transition time.
  final Duration duration;

  /// Maximum remaining time allowed to complete an interrupted transition.
  final Duration completionGrace;

  @override
  State<HyprTextSwap> createState() => _HyprTextSwapState();
}

class _HyprTextSwapState extends State<HyprTextSwap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..addStatusListener(_completed);
  late _Swap _swap = _Settled(widget.child);

  void _completed(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() => _swap = _Settled(_swap.latest));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _settle(widget.child);
  }

  @override
  void didUpdateWidget(HyprTextSwap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.duration;
    if (MediaQuery.disableAnimationsOf(context) ||
        widget.duration == Duration.zero) {
      _settle(widget.child);
      return;
    }
    final current = _swap;
    if (Widget.canUpdate(oldWidget.child, widget.child)) {
      _swap = switch (current) {
        _Settled() => _Settled(widget.child),
        _Transitioning(:final previous, :final incoming) => _Transitioning(
          previous,
          Widget.canUpdate(incoming, widget.child) ? widget.child : incoming,
          widget.child,
        ),
      };
      return;
    }
    switch (current) {
      case _Settled(:final latest):
        _swap = _Transitioning(latest, widget.child, widget.child);
        _animation.forward(from: 0);
      case _Transitioning(:final previous, :final incoming):
        final remaining =
            widget.duration.inMicroseconds * (1 - _animation.value);
        if (remaining <= widget.completionGrace.inMicroseconds) {
          _swap = _Transitioning(previous, incoming, widget.child);
        } else {
          _settle(widget.child);
        }
    }
  }

  void _settle(Widget child) {
    _animation.stop();
    _swap = _Settled(child);
  }

  @override
  Widget build(BuildContext context) => switch (_swap) {
    _Settled(:final latest) => latest,
    _Transitioning(:final previous, :final incoming) => Stack(
      alignment: Alignment.centerLeft,
      children: [
        ExcludeSemantics(
          child: IgnorePointer(
            child: FadeThroughTransition(
              animation: const AlwaysStoppedAnimation(1),
              secondaryAnimation: _animation,
              fillColor: Colors.transparent,
              child: previous,
            ),
          ),
        ),
        FadeThroughTransition(
          animation: _animation,
          secondaryAnimation: const AlwaysStoppedAnimation(0),
          fillColor: Colors.transparent,
          child: incoming,
        ),
      ],
    ),
  };

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }
}

/// Settled content or one transition with a replaceable latest update.
sealed class _Swap {
  const _Swap(this.latest);
  final Widget latest;
}

/// Content shown without a running animation.
final class _Settled extends _Swap {
  const _Settled(super.latest);
}

/// Fixed transition endpoints; the latest update wins on completion.
final class _Transitioning extends _Swap {
  const _Transitioning(this.previous, this.incoming, super.latest);
  final Widget previous;
  final Widget incoming;
}
