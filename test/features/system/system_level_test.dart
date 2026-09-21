import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/features/system/system_level.dart';

void main() {
  test('full scale sits at zero decibels', () {
    expect(AnalogLevel.dbFor(1), 0);
    expect(AnalogLevel.sweep(1), 1);
  });

  test('silence rests on the analog floor', () {
    expect(AnalogLevel.dbFor(0), AnalogLevel.floorDb);
    expect(AnalogLevel.sweep(0), 0);
  });

  test('twelve percent lands near minus eighteen dB', () {
    expect(AnalogLevel.dbFor(0.12), closeTo(-18.42, 0.05));
    expect(AnalogLevel.sweep(0.12), closeTo(0.386, 0.01));
  });

  test('the needle eases toward a reading without jumping', () {
    final ({double position, double velocity}) first = NeedleMotion.step(
      position: 0.12,
      velocity: 0,
      target: 0.9,
      dt: 0.016,
    );
    expect(first.position, greaterThan(0.12));
    expect(first.position, lessThan(0.2));

    var position = 0.12;
    var velocity = 0.0;
    for (var frame = 0; frame < 140; frame++) {
      final ({double position, double velocity}) next = NeedleMotion.step(
        position: position,
        velocity: velocity,
        target: 0.9,
        dt: 0.016,
      );
      position = next.position;
      velocity = next.velocity;
    }
    expect(position, closeTo(0.9, 0.02));
    expect(velocity.abs(), lessThan(0.02));
  });

  test('retargeting keeps the needle where it already is', () {
    final ({double position, double velocity}) coasting = NeedleMotion.step(
      position: 0.4,
      velocity: 0.35,
      target: 0.2,
      dt: 0,
    );
    expect(coasting.position, 0.4);
    expect(coasting.velocity, 0.35);
  });
}
