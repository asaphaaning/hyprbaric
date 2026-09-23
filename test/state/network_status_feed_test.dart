import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/bindings/bindings.dart';
import 'package:hyprbaric/src/features/network/network_traffic_provider.dart';
import 'package:hyprbaric/src/state/rust_signals/network.dart';

void main() {
  test('closed Network retains only the latest snapshot', () async {
    final feed = NetworkStatusFeed();
    final previous = NetworkStatus.latestRustSignal;
    addTearDown(() async {
      NetworkStatus.latestRustSignal = previous;
      await feed.close();
    });

    for (var sequence = 0; sequence < 300; sequence++) {
      _send(_snapshot(sequence));
    }
    await Future<void>.delayed(Duration.zero);

    expect(feed.latest!.message, '299');
    expect(NetworkStatus.latestRustSignal!.message.message, '299');

    final received = <NetworkStatus>[];
    final subscription = feed.updates().listen(received.add);
    await Future<void>.delayed(Duration.zero);
    expect(received.map((status) => status.message), ['299']);

    final current = _snapshot(300);
    _send(current);
    _send(current);
    await Future<void>.delayed(Duration.zero);
    expect(received.map((status) => status.message), ['299', '300', '300']);

    await subscription.cancel();
    for (var sequence = 301; sequence < 600; sequence++) {
      _send(_snapshot(sequence));
    }
    await Future<void>.delayed(Duration.zero);

    final reopened = <NetworkStatus>[];
    final reopenedSubscription = feed.updates().listen(reopened.add);
    await Future<void>.delayed(Duration.zero);
    expect(reopened.map((status) => status.message), ['599']);
    await reopenedSubscription.cancel();

    final resumed = <NetworkStatus>[];
    final pausedSubscription = feed.updates().listen(resumed.add);
    await Future<void>.delayed(Duration.zero);
    pausedSubscription.pause();
    for (var sequence = 600; sequence < 900; sequence++) {
      _send(_snapshot(sequence));
    }
    await Future<void>.delayed(Duration.zero);
    expect(resumed.map((status) => status.message), ['599']);

    pausedSubscription.resume();
    await Future<void>.delayed(Duration.zero);
    expect(resumed.map((status) => status.message), ['599', '899']);
    await pausedSubscription.cancel();
  });

  test('status and traffic consumers receive each live observation', () async {
    final feed = NetworkStatusFeed();
    final container = ProviderContainer(
      overrides: [networkStatusFeedProvider.overrideWithValue(feed)],
    );
    addTearDown(() async {
      container.dispose();
      await feed.close();
    });

    final traffic = <NetworkStatus>[];
    final trafficSubscription = container
        .read(networkTrafficUpdatesProvider)
        .listen(traffic.add);
    addTearDown(trafficSubscription.cancel);

    final statusSubscription = container.listen(
      networkStatusProvider,
      (_, _) {},
    );
    addTearDown(statusSubscription.close);

    await Future<void>.delayed(Duration.zero);
    _send(_snapshot(1));
    _send(_snapshot(2));
    await Future<void>.delayed(Duration.zero);

    expect(traffic.map((status) => status.message), ['1', '2']);
    expect(container.read(networkStatusProvider).value!.message, '2');
  });
}

NetworkStatus _snapshot(int sequence) {
  final transfer = NetworkTransfer(
    bytesPerSecond: Uint64(BigInt.from(sequence)),
    totalBytes: Uint64(BigInt.from(sequence)),
  );
  return NetworkStatus(
    wifiEnabled: true,
    devicePresent: true,
    scanning: false,
    traffic: NetworkTraffic(upload: transfer, download: transfer),
    networks: const [],
    interfaces: const [],
    message: '$sequence',
  );
}

void _send(NetworkStatus status) {
  assignRustSignal['NetworkStatus']!(status.bincodeSerialize(), Uint8List(0));
}
