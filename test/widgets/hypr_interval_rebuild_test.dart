import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/widgets/primitives/primitives.dart';

void main() {
  testWidgets('rebuilds on the interval while enabled', (
    WidgetTester tester,
  ) async {
    int builds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: HyprIntervalRebuild(
          interval: const Duration(seconds: 1),
          builder: (BuildContext context) {
            builds += 1;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(builds, 1);

    await tester.pump(const Duration(seconds: 1));
    expect(builds, 2);

    await tester.pump(const Duration(seconds: 1));
    expect(builds, 3);
  });

  testWidgets('holds no timer while disabled', (WidgetTester tester) async {
    int builds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: HyprIntervalRebuild(
          enabled: false,
          interval: const Duration(seconds: 1),
          builder: (BuildContext context) {
            builds += 1;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    // A surface with nothing time-dependent on it must not schedule frames.
    await tester.pump(const Duration(seconds: 5));
    expect(builds, 1);
  });

  testWidgets('starts and stops as enabled changes', (
    WidgetTester tester,
  ) async {
    Widget build({required bool enabled}) => MaterialApp(
      home: HyprIntervalRebuild(
        enabled: enabled,
        interval: const Duration(seconds: 1),
        builder: (BuildContext context) => const SizedBox.shrink(),
      ),
    );

    await tester.pumpWidget(build(enabled: false));
    await tester.pumpWidget(build(enabled: true));
    await tester.pump(const Duration(seconds: 1));

    // Switching back off has to cancel the timer, or the test framework
    // reports a pending timer when the widget is torn down.
    await tester.pumpWidget(build(enabled: false));
    await tester.pump(const Duration(seconds: 3));
  });
}
