import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/features/network/network_traffic_history.dart';

TrafficSample sample(int milliseconds, {double download = 28.4}) =>
    TrafficSample(
      at: Duration(milliseconds: milliseconds),
      download: download,
      upload: 4.7,
    );

void main() {
  test('opening records only real observations, including a zero rate', () {
    final history = const TrafficHistory.empty().record(sample(0, download: 0));
    expect(history.samples, hasLength(1));
    expect(history.extent, Duration.zero);
    expect(history.latest!.download, 0);
  });

  test('4, 27 and 58 seconds occupy their actual fractions of a minute', () {
    for (final seconds in [4, 27, 58]) {
      final history = const TrafficHistory.empty()
          .record(sample(0))
          .record(sample(seconds * 1000));
      expect(history.extent, Duration(seconds: seconds));
      expect(history.samples, hasLength(2));
    }
  });

  test(
    'sliding window keeps a boundary predecessor with irregular cadence',
    () {
      var history = const TrafficHistory.empty();
      for (final time in [0, 1200, 7100, 63000, 68200]) {
        history = history.record(sample(time));
      }
      expect(history.extent, TrafficHistory.window);
      expect(history.samples.map((sample) => sample.at.inMilliseconds), [
        7100,
        63000,
        68200,
      ]);
    },
  );

  test(
    'duplicate timestamps replace and out of order observations are ignored',
    () {
      final original = const TrafficHistory.empty().record(sample(1000));
      final replaced = original.record(sample(1000, download: 40));
      expect(replaced.samples, hasLength(1));
      expect(replaced.latest!.download, 40);
      expect(replaced.record(sample(999)), same(replaced));
      expect(original.latest!.download, 28.4);
      expect(() => replaced.samples.add(sample(2000)), throwsUnsupportedError);
    },
  );
}
