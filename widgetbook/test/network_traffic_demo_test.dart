import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:hyprbaric_widgetbook/audio/network_panel_preview.dart';
import 'package:hyprbaric_widgetbook/audio/network_traffic_demo.dart';

void main() {
  test('pre-roll fills both scales without clipping and matches readouts', () {
    final history = NetworkTrafficDemo.prefill();
    expect(history.extent, TrafficHistory.window);
    for (var tick = 0; tick < 6000; tick++) {
      final sample = NetworkTrafficDemo.sample(
        Duration(milliseconds: tick * 100),
      );
      expect(sample.download, inExclusiveRange(0, 60));
      expect(sample.upload, inExclusiveRange(0, 10));
      final traffic = NetworkTrafficDemo.traffic(sample);
      expect(
        traffic.download.bytesPerSecond.toInt() / 125000,
        closeTo(sample.download, .00001),
      );
      expect(
        traffic.upload.bytesPerSecond.toInt() / 125000,
        closeTo(sample.upload, .00001),
      );
    }
  });

  testWidgets(
    'preview starts full, advances at bounded cadence, and pauses for reduced motion',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Future<void> mount(bool reduced) => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: const Align(
              alignment: Alignment.topCenter,
              child: NetworkPanelPreview(),
            ),
          ),
        ),
      );
      TrafficHistory history() =>
          tester.widget<NetworkPanel>(find.byType(NetworkPanel)).history!;
      await mount(false);
      final initial = history();
      expect(initial.extent, TrafficHistory.window);
      await tester.pump(const Duration(milliseconds: 16));
      expect(identical(history(), initial), isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(history().latest!.at, greaterThan(initial.latest!.at));
      await mount(true);
      final paused = history();
      await tester.pump(const Duration(seconds: 2));
      expect(identical(history(), paused), isTrue);
      await mount(false);
      await tester.pump(const Duration(milliseconds: 150));
      expect(history().extent, TrafficHistory.window);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
