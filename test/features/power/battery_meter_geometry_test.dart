import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/features/power/battery_meter_geometry.dart';
import 'package:hyprbaric/src/features/power/power_colors.dart';

void main() {
  test('the meter keeps all twenty segments on a narrow strip', () {
    // The nominal gaps total 38 logical pixels. Below that the meter used to
    // bail out and paint nothing at all, which is worse than crowding.
    for (final double width in <double>[320, 60, 38, 30, 12, 1]) {
      final BatteryMeterGeometry geometry = BatteryMeterGeometry.forWidth(
        width,
      );

      expect(
        geometry.isPaintable,
        isTrue,
        reason: 'nothing would be painted at ${width}px',
      );
      expect(
        geometry.offsetOf(BatteryMeterGeometry.segmentCount - 1) +
            geometry.segmentWidth,
        moreOrLessEquals(width, epsilon: 0.001),
        reason: 'the segments do not fill the strip at ${width}px',
      );
    }
  });

  test('a strip with no width paints nothing rather than dividing by zero', () {
    expect(BatteryMeterGeometry.forWidth(0).isPaintable, isFalse);
    expect(BatteryMeterGeometry.forWidth(-4).isPaintable, isFalse);
  });

  test('the nominal gap survives at the meter\'s shipping width', () {
    expect(BatteryMeterGeometry.forWidth(294).gap,
        BatteryMeterGeometry.nominalGap);
  });

  test('the charge ramp is shared rather than restated per widget', () {
    expect(PowerColors.forCharge(10), PowerColors.critical);
    expect(PowerColors.forCharge(45), PowerColors.low);
    expect(PowerColors.forCharge(90), PowerColors.healthy);
  });
}
