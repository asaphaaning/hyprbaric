import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/bindings/bindings.dart';
import 'package:hyprbaric/src/features/network/network_traffic_provider.dart';

void main() {
  test(
    'identical idle observations continue across popover subscriptions',
    () async {
      final updates = StreamController<NetworkStatus>();
      final container = ProviderContainer(
        overrides: [
          networkTrafficUpdatesProvider.overrideWithValue(updates.stream),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(updates.close);
      final zero = NetworkTransfer(
        bytesPerSecond: Uint64(BigInt.zero),
        totalBytes: Uint64(BigInt.zero),
      );
      final snapshot = NetworkStatus(
        wifiEnabled: true,
        devicePresent: true,
        scanning: false,
        traffic: NetworkTraffic(upload: zero, download: zero),
        networks: const [],
        interfaces: const [],
      );
      final openPopover = container.listen(
        networkTrafficHistoryProvider,
        (_, _) {},
      );
      updates.add(snapshot);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(networkTrafficHistoryProvider).samples,
        hasLength(1),
      );
      openPopover.close();
      updates.add(snapshot);
      await Future<void>.delayed(Duration.zero);
      final history = container.read(networkTrafficHistoryProvider);
      expect(history.samples, hasLength(2));
      expect(history.latest!.download, 0);
      expect(history.extent, greaterThan(Duration.zero));
    },
  );
}
