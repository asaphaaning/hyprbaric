import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/features/audio/brightness_knob.dart';
import 'package:hyprbaric/src/features/audio/brightness_knob_painter.dart';

BrightnessKnobPainter _painter(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((CustomPaint paint) => paint.painter)
      .whereType<BrightnessKnobPainter>()
      .first;
}

Widget _knob(int value) => MaterialApp(
  home: BrightnessKnob(
    value: value,
    enabled: true,
    presentation: BrightnessKnobPresentation.console,
    onChanged: _ignore,
    onChangeEnd: _ignore,
  ),
);

void main() {
  test('the lamp value repaints independently of the pointer', () {
    const BrightnessKnobPainter painter = BrightnessKnobPainter(
      value: 0.75,
      lampValue: 0.74,
      enabled: true,
      console: true,
    );

    expect(
      painter.shouldRepaint(
        const BrightnessKnobPainter(
          value: 0.75,
          lampValue: 0.75,
          enabled: true,
          console: true,
        ),
      ),
      isTrue,
    );
  });

  testWidgets('the console pointer settles ahead of its lamps', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_knob(20));
    await tester.pumpAndSettle();

    expect(_painter(tester).value, closeTo(0.2, 0.001));
    expect(_painter(tester).lampValue, closeTo(0.2, 0.001));

    await tester.pumpWidget(_knob(90));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    // The pointer has arrived; the lamps are still on their way.
    final BrightnessKnobPainter midway = _painter(tester);
    expect(midway.value, closeTo(0.9, 0.001));
    expect(midway.lampValue, lessThan(0.9));
    expect(midway.lampValue, greaterThan(0.2));

    await tester.pumpAndSettle();

    expect(_painter(tester).lampValue, closeTo(0.9, 0.001));
  });
}

void _ignore(int value) {}
