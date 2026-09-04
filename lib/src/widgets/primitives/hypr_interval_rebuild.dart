import 'dart:async';

import 'package:flutter/widgets.dart';

/// Rebuilds [builder] on a fixed interval while [enabled].
///
/// Relative timestamps go stale the moment they are painted. The recording pad
/// already ran its own private `Timer.periodic` for this, while the
/// notification rows rendered their ages from a stateless build and froze for
/// as long as the panel stayed open. One implementation, so a surface either
/// opts into ticking or does not.
class HyprIntervalRebuild extends StatefulWidget {
  const HyprIntervalRebuild({
    super.key,
    required this.builder,
    this.enabled = true,
    this.interval = const Duration(seconds: 1),
  });

  final WidgetBuilder builder;

  /// A surface with nothing time-dependent on it holds no timer.
  final bool enabled;
  final Duration interval;

  @override
  State<HyprIntervalRebuild> createState() => _HyprIntervalRebuildState();
}

class _HyprIntervalRebuildState extends State<HyprIntervalRebuild> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant HyprIntervalRebuild oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled ||
        widget.interval != oldWidget.interval) {
      _ticker?.cancel();
      _ticker = null;
      _syncTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker() {
    if (!widget.enabled || _ticker != null) {
      return;
    }
    _ticker = Timer.periodic(widget.interval, (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
