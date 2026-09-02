import 'package:flutter/material.dart';

import '../hypr_surface.dart';

/// Direction a [HyprSegmentedMeterPainter] fills towards.
enum HyprMeterDirection { leftToRight, bottomToTop }

/// Paints a level as discrete segments coloured by a [HyprLevelRamp].
///
/// This is the bar's one segmented meter. The faders, the master rail and the
/// OSD all draw through it so segment counts, gaps and band boundaries cannot
/// drift apart.
class HyprSegmentedMeterPainter extends CustomPainter {
  const HyprSegmentedMeterPainter({
    required this.value,
    required this.ramp,
    this.segments = 32,
    this.gap = 1.5,
    this.inset = 2,
    this.direction = HyprMeterDirection.leftToRight,
    this.segmentRadius = 1,
    this.inactiveColor = HyprColors.levelSlot,
    this.trackColor,
    this.trackRadius = HyprRadii.tag,
    this.trackBorderColor,
  });

  /// Level to display, as a fraction of the scale.
  final double value;

  /// Band colours and boundaries.
  final HyprLevelRamp ramp;

  final int segments;
  final double gap;

  /// Padding between the track edge and the segments.
  final double inset;

  final HyprMeterDirection direction;
  final double segmentRadius;
  final Color inactiveColor;

  /// Well painted behind the segments. Omitted when null.
  final Color? trackColor;
  final double trackRadius;
  final Color? trackBorderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final RRect track = RRect.fromRectAndRadius(
      bounds,
      Radius.circular(trackRadius),
    );
    if (trackColor case final Color color) {
      canvas.drawRRect(track, Paint()..color = color);
    }
    if (trackBorderColor case final Color color) {
      canvas.drawRRect(
        track.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color,
      );
    }

    final bool horizontal = direction == HyprMeterDirection.leftToRight;
    final double span = (horizontal ? size.width : size.height) - inset * 2;
    final double extent = (span - gap * (segments - 1)) / segments;
    if (extent <= 0) {
      return;
    }

    final int active = (value.clamp(0, 1) * segments).round();
    final Paint paint = Paint();
    for (int index = 0; index < segments; index += 1) {
      final double offset = inset + index * (extent + gap);
      final Rect segment = horizontal
          ? Rect.fromLTWH(offset, inset, extent, size.height - inset * 2)
          : Rect.fromLTWH(
              inset,
              size.height - inset - offset - extent,
              size.width - inset * 2,
              extent,
            );
      paint.color = index < active
          ? ramp.colorAt(index / segments)
          : inactiveColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(segment, Radius.circular(segmentRadius)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HyprSegmentedMeterPainter oldDelegate) {
    return value != oldDelegate.value ||
        ramp != oldDelegate.ramp ||
        segments != oldDelegate.segments ||
        gap != oldDelegate.gap ||
        inset != oldDelegate.inset ||
        direction != oldDelegate.direction ||
        segmentRadius != oldDelegate.segmentRadius ||
        inactiveColor != oldDelegate.inactiveColor ||
        trackColor != oldDelegate.trackColor ||
        trackRadius != oldDelegate.trackRadius ||
        trackBorderColor != oldDelegate.trackBorderColor;
  }
}
