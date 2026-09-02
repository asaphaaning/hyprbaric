import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/bindings/bindings.dart';
import 'package:hyprbaric/src/features/audio/audio_fader.dart';

Widget _fader(int volume, List<int> sent) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: AudioFader(
        endpoint: AudioEndpoint(
          id: 'out',
          name: 'Out',
          kind: AudioEndpointKind.output,
          volume: volume,
          muted: false,
        ),
        accent: Colors.green,
        onPreviewVolume: (_) {},
        onSetVolume: (AudioEndpointKind k, int v) => sent.add(v),
      ),
    ),
  ),
);

void main() {
  testWidgets('pressing the handle does not move the value', (
    WidgetTester tester,
  ) async {
    for (final int volume in <int>[100, 75, 50, 25, 0]) {
      final List<int> sent = <int>[];
      await tester.pumpWidget(_fader(volume, sent));
      await tester.pump();
      final Rect box = tester.getRect(find.byType(AudioFader));
      final double y = AudioFaderMetrics.handleCenterY(volume / 100, box.height);
      await tester.tapAt(Offset(box.left + 28, box.top + y));
      await tester.pump();
      expect(sent, isEmpty, reason: 'press at $volume moved the value: $sent');
    }
  });

  testWidgets('the level ladder is not a control', (WidgetTester tester) async {
    final List<int> sent = <int>[];
    await tester.pumpWidget(_fader(62, sent));
    await tester.pump();
    final Rect box = tester.getRect(find.byType(AudioFader));
    await tester.tapAt(Offset(box.left + 2, box.top + 140));
    await tester.pump();
    expect(sent, isEmpty);
  });

  testWidgets('dragging to the top and bottom reaches the ends', (
    WidgetTester tester,
  ) async {
    final List<int> sent = <int>[];
    await tester.pumpWidget(_fader(50, sent));
    await tester.pump();
    final Rect box = tester.getRect(find.byType(AudioFader));
    final TestGesture g = await tester.startGesture(
      Offset(box.left + 28, box.center.dy),
    );
    await g.moveTo(Offset(box.left + 28, box.top - 40));
    await tester.pump();
    await g.up();
    await tester.pump();
    expect(sent.last, 100);
  });
}
