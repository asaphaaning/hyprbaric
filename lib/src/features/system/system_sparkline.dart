import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';
import 'system_console.dart';

/// A compact history of occupancy samples as rising bars.
class SystemSparkline extends StatelessWidget {
  const SystemSparkline({
    super.key,
    required this.samples,
    this.color = SystemConsole.spark,
    this.width = 22,
    this.height = 12,
    this.bars = 10,
  });

  /// Occupancy fractions, oldest first.
  final List<double> samples;
  final Color color;
  final double width;
  final double height;
  final int bars;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(samples: samples, color: color, bars: bars),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.samples,
    required this.color,
    required this.bars,
  });

  final List<double> samples;
  final Color color;
  final int bars;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    const double gap = 1.15;
    final double barWidth = (size.width - gap * (bars - 1)) / bars;
    if (barWidth <= 0) {
      return;
    }
    final List<double> values = List<double>.filled(bars, 0);
    final List<double> source = samples.isEmpty ? const <double>[0] : samples;
    final int copy = source.length < bars ? source.length : bars;
    final int destStart = bars - copy;
    final int srcStart = source.length - copy;
    for (int index = 0; index < copy; index += 1) {
      values[destStart + index] = source[srcStart + index].clamp(0, 1);
    }

    for (int index = 0; index < bars; index += 1) {
      final double value = values[index];
      final double height = (2.0 + (size.height - 2) * value).clamp(
        2.0,
        size.height,
      );
      final Rect rect = Rect.fromLTWH(
        index * (barWidth + gap),
        size.height - height,
        barWidth,
        height,
      );
      final bool lit = value > 0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(0.8)),
        Paint()
          ..color = lit
              ? Color.lerp(color.withValues(alpha: 0.35), color, value)!
              : HyprColors.levelSlot.withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.bars != bars ||
        !_listEquals(oldDelegate.samples, samples);
  }
}

bool _listEquals(List<double> left, List<double> right) {
  if (left.length != right.length) {
    return false;
  }
  for (int index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
