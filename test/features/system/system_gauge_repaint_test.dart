import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/features/system/system_gauge.dart';

void main() {
  testWidgets('Needle motion repaints without repainting the gauge face', (
    tester,
  ) async {
    Widget gauge(double ratio) => MaterialApp(
      home: Center(child: SystemGauge(ratio: ratio)),
    );

    await tester.pumpWidget(gauge(0.1));

    final paints = find.descendant(
      of: find.byType(SystemGauge),
      matching: find.byType(CustomPaint),
    );
    expect(paints, findsNWidgets(3));
    final renderObjects = paints
        .evaluate()
        .map((element) => element.renderObject! as RenderCustomPaint)
        .toList();

    await tester.pumpWidget(gauge(0.9));
    await tester.pump(const Duration(milliseconds: 16));

    final previousCallback = debugOnProfilePaint;
    final painted = <RenderObject>[];
    debugOnProfilePaint = painted.add;
    try {
      await tester.pump(const Duration(milliseconds: 16));
    } finally {
      debugOnProfilePaint = previousCallback;
    }

    expect(painted.where(renderObjects.contains), <RenderObject>[
      renderObjects[1],
    ]);
  });
}
