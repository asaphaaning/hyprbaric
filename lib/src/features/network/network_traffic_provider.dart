import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../../state/rust_signals/network.dart';
import 'network_traffic_history.dart';

/// Raw observations preserve cadence even when the visible status is unchanged.
final networkTrafficUpdatesProvider = Provider<Stream<NetworkStatus>>(
  (ref) => networkStatusUpdates(),
);

/// Collects measured history across popover openings, without synthetic fill.
final networkTrafficHistoryProvider =
    NotifierProvider<NetworkTrafficRecorder, TrafficHistory>(
      NetworkTrafficRecorder.new,
    );

/// The status stream owns cadence; the monotonic clock owns chronology.
class NetworkTrafficRecorder extends Notifier<TrafficHistory> {
  @override
  TrafficHistory build() {
    final clock = Stopwatch()..start();
    var history = const TrafficHistory.empty();
    final subscription = ref.watch(networkTrafficUpdatesProvider).listen((
      snapshot,
    ) {
      history = history.record(
        TrafficSample(
          at: clock.elapsed,
          download:
              snapshot.traffic.download.bytesPerSecond.toInt() * 8 / 1000000,
          upload: snapshot.traffic.upload.bytesPerSecond.toInt() * 8 / 1000000,
        ),
      );
      state = history;
    });
    ref.onDispose(() {
      clock.stop();
      unawaited(subscription.cancel());
    });
    return history;
  }
}
