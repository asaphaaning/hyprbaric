import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'system_formatting.dart';

/// Compact CPU and memory readout that opens the system instrument.
/// Memory shares the occupancy bands with its own teal nominal tint.
final HyprLevelRamp _memoryRamp = HyprLevelRamp.occupancy.withNominal(
  const Color(0xFF20DCD0),
);

class SystemChip extends StatelessWidget {
  const SystemChip({
    super.key,
    required this.status,
    required this.isOpen,
    required this.onPressed,
  });

  final SystemStatus? status;
  final bool isOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool plated = HyprPlateTrack.isPresent(context);
    return Semantics(
      button: true,
      label:
          'System, CPU ${formatCpuPercent(status)}, memory ${formatMemoryChip(status)}',
      child: Material(
        color: isOpen && !plated ? HyprColors.hoverStrong : Colors.transparent,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(HyprRadii.row),
          side: isOpen && !plated
              ? const BorderSide(color: HyprColors.border, width: 1.1)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          hoverColor: plated ? Colors.transparent : HyprColors.hover,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          customBorder: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(HyprRadii.row),
          ),
          child: SizedBox(
            height: HyprIconSizes.compactButton.height + HyprSpacing.xxs,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _Readout(
                    label: 'CPU',
                    value: formatCpuPercent(status),
                    ratio: cpuRatio(status),
                    ramp: HyprLevelRamp.occupancy,
                  ),
                  const SizedBox(width: HyprSpacing.xxl),
                  _Readout(
                    label: 'MEM',
                    value: formatMemoryChip(status),
                    ratio: memoryRatio(status),
                    ramp: _memoryRamp,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({
    required this.label,
    required this.value,
    required this.ratio,
    required this.ramp,
  });

  final String label;
  final String value;

  /// Occupancy from 0 to 1, drawn as the ring's arc.
  final double ratio;
  final HyprLevelRamp ramp;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _LoadRing(ratio: ratio, ramp: ramp),
        const SizedBox(width: HyprSpacing.lg),
        Text(
          label,
          style: HyprTypography.barMono.copyWith(
            color: HyprColors.textFaint,
            fontSize: HyprTypography.size(11.5),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: HyprSpacing.lg),
        Text(
          value,
          style: HyprTypography.barMono.copyWith(
            color: HyprColors.text,
            fontSize: HyprTypography.size(11.5),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// A small ring whose arc follows the current occupancy, tinted by load.
///
/// Readings arrive every second and each animated frame recomposites the
/// whole bar surface, so only a real swing eases; ordinary jitter snaps in
/// a single frame and the bar stays idle between readings.
class _LoadRing extends StatefulWidget {
  const _LoadRing({required this.ratio, required this.ramp});

  /// Arc resolution. One step is under a pixel of the ring's circumference,
  /// so sample jitter within a step does not repaint at all.
  static const double steps = 64;

  /// Smallest change, as a fraction of the ring, that eases instead of
  /// snapping.
  static const double sweep = 0.1;

  final double ratio;
  final HyprLevelRamp ramp;

  static double quantize(double ratio) =>
      (ratio.clamp(0.0, 1.0) * steps).round() / steps;

  @override
  State<_LoadRing> createState() => _LoadRingState();
}

class _LoadRingState extends State<_LoadRing> {
  late double _target = _LoadRing.quantize(widget.ratio);
  Duration _duration = Duration.zero;

  @override
  void didUpdateWidget(_LoadRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    final double next = _LoadRing.quantize(widget.ratio);
    if (next == _target) {
      return;
    }
    _duration = (next - _target).abs() >= _LoadRing.sweep
        ? HyprMotion.loadRing
        : Duration.zero;
    _target = next;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: _target),
        duration: _duration,
        curve: HyprMotion.plateCurve,
        builder: (BuildContext context, double value, Widget? child) =>
            CustomPaint(
              size: const Size.square(_LoadRingPainter.diameter),
              painter: _LoadRingPainter(
                ratio: value,
                color: widget.ramp.colorAt(value),
              ),
            ),
      ),
    );
  }
}

class _LoadRingPainter extends CustomPainter {
  const _LoadRingPainter({required this.ratio, required this.color});

  static const double diameter = 16;
  static const double stroke = 2;

  final double ratio;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect ring = (Offset.zero & size).deflate(stroke);
    canvas.drawOval(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = const Color(0x1FFFFFFF),
    );
    if (ratio <= 0) {
      return;
    }
    canvas.drawArc(
      ring,
      -math.pi / 2,
      2 * math.pi * ratio,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_LoadRingPainter oldDelegate) =>
      oldDelegate.ratio != ratio || oldDelegate.color != color;
}
