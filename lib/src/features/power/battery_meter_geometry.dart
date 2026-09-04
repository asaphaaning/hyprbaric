import 'dart:math' as math;

/// Segment layout for the battery charge meter.
///
/// Kept apart from the painter so the narrow-strip behaviour can be asserted
/// without rendering: the meter is laid out at whatever width its panel gives
/// it, and it must stay readable rather than disappear when that is small.
class BatteryMeterGeometry {
  const BatteryMeterGeometry({required this.segmentWidth, required this.gap});

  static const int segmentCount = 20;
  static const double nominalGap = 2;

  final double segmentWidth;
  final double gap;

  /// Resolves the layout for a strip [width] logical pixels across.
  ///
  /// The nominal gaps total 38 logical pixels. Rather than give up below that
  /// and paint nothing, the gap narrows so all twenty segments stay present.
  factory BatteryMeterGeometry.forWidth(double width) {
    if (width <= 0) {
      return const BatteryMeterGeometry(segmentWidth: 0, gap: 0);
    }

    final double gap = math.min(nominalGap, width / (segmentCount * 2));
    return BatteryMeterGeometry(
      segmentWidth: (width - gap * (segmentCount - 1)) / segmentCount,
      gap: gap,
    );
  }

  /// Whether the strip has room to draw anything at all.
  bool get isPaintable => segmentWidth > 0;

  /// Left edge of the segment at [index].
  double offsetOf(int index) => index * (segmentWidth + gap);
}
