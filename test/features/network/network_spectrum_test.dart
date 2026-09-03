import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/features/network/network_spectrum.dart';

void main() {
  group('NetworkSpectrumPainter', () {
    test('repaints when the series advances by value', () {
      // The panel used to hand the painter one buffer it mutated in place, so
      // comparing by identity always said "nothing changed" and the trace
      // froze on its first frame.
      const NetworkSpectrumPainter first = NetworkSpectrumPainter(
        uploadHistory: <double>[1, 2, 3],
        downloadHistory: <double>[1, 1, 1],
      );
      const NetworkSpectrumPainter second = NetworkSpectrumPainter(
        uploadHistory: <double>[2, 3, 4],
        downloadHistory: <double>[1, 1, 1],
      );

      expect(second.shouldRepaint(first), isTrue);
    });

    test('holds still when the series is unchanged', () {
      const NetworkSpectrumPainter first = NetworkSpectrumPainter(
        uploadHistory: <double>[1, 2, 3],
        downloadHistory: <double>[4, 5, 6],
      );
      const NetworkSpectrumPainter second = NetworkSpectrumPainter(
        uploadHistory: <double>[1, 2, 3],
        downloadHistory: <double>[4, 5, 6],
      );

      // Equal by value, so a separate instance is not a reason to repaint.
      expect(second.shouldRepaint(first), isFalse);
    });
  });

  group('scope time base', () {
    testWidgets('reports the measured window rather than a fixed label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NetworkSpectrumPanel(
              uploadHistory: <double>[1, 2],
              downloadHistory: <double>[1, 2],
              window: Duration(seconds: 50),
            ),
          ),
        ),
      );

      // The poll cadence is configurable, so the axis cannot claim a constant.
      expect(find.text('50 s'), findsOneWidget);
      expect(find.text('20 s'), findsNothing);
    });

    testWidgets('shows a placeholder before the window can be measured', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NetworkSpectrumPanel(
              uploadHistory: <double>[1, 2],
              downloadHistory: <double>[1, 2],
            ),
          ),
        ),
      );

      expect(find.text('--'), findsOneWidget);
    });
  });
  testWidgets('network metric values never change their card height', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_metric('0.04 MB/s'));
    final Size quietSize = tester.getSize(find.byType(NetworkParameter));

    await tester.pumpWidget(_metric('153.40 MB/s'));
    final Size burstSize = tester.getSize(find.byType(NetworkParameter));

    expect(burstSize, quietSize);
  });

  testWidgets('an overlong metric value ellipsises rather than shrinking', (
    WidgetTester tester,
  ) async {
    // Scaling the glyphs down to fit would undo the device-pixel snapping in
    // HyprTypography.size and break tabular alignment against the card next
    // to it, so the value has to keep its type size and lose characters.
    await tester.pumpWidget(_metric('0.04 MB/s'));
    final double quietSize = _valueFontSize(tester, '0.04 MB/s');

    const String overlong = '188888.8888 MB/s downstream sustained';
    await tester.pumpWidget(_metric(overlong));
    final Text value = tester.widget<Text>(find.text(overlong));

    expect(_valueFontSize(tester, overlong), quietSize);
    expect(value.maxLines, 1);
    expect(value.overflow, TextOverflow.ellipsis);
    expect(
      find.byType(FittedBox),
      findsNothing,
      reason: 'a scale-down fit would render the value off the type ramp',
    );
  });
}

double _valueFontSize(WidgetTester tester, String value) {
  return tester.widget<Text>(find.text(value)).style!.fontSize!;
}

Widget _metric(String value) {
  return MaterialApp(
    home: Center(
      child: SizedBox(
        width: 150,
        child: NetworkParameter(
          label: 'Downstream',
          value: value,
          detail: '14.3 GB received',
          tone: NetworkParameterTone.rx,
          progress: 0.5,
        ),
      ),
    ),
  );
}
