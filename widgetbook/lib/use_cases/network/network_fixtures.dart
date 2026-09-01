import 'package:hyprbaric/widget_catalog.dart';

/// Stable network snapshots used by the Widgetbook stories.
abstract final class NetworkFixtures {
  static const NetworkInterface wifiInterface = NetworkInterface(
    name: 'wlo1',
    address: '192.168.1.42',
    active: true,
  );

  static const NetworkInterface ethernetInterface = NetworkInterface(
    name: 'eth0',
    address: null,
    active: false,
  );

  static const NetworkInterface loopbackInterface = NetworkInterface(
    name: 'lo',
    address: '127.0.0.1',
    active: false,
  );

  static NetworkTransfer _transfer({
    required int bytesPerSecond,
    required int totalBytes,
  }) {
    return NetworkTransfer(
      bytesPerSecond: Uint64.fromBigInt(BigInt.from(bytesPerSecond)),
      totalBytes: Uint64.fromBigInt(BigInt.from(totalBytes)),
    );
  }

  static NetworkTraffic get traffic => NetworkTraffic(
    upload: _transfer(bytesPerSecond: 407184, totalBytes: 1288490188),
    download: _transfer(bytesPerSecond: 1506060145, totalBytes: 15461882266),
    pingMs: 10,
  );

  static const List<NetworkEntry> networks = <NetworkEntry>[
    NetworkEntry(
      ssid: 'Hyprnet_5G',
      bssid: 'A0:CE:C8:12:34:56',
      strength: 92,
      secure: true,
      state: NetworkEntryState.active,
    ),
    NetworkEntry(
      ssid: 'Neighbor_2G',
      bssid: 'A0:CE:C8:65:43:21',
      strength: 64,
      secure: true,
      state: NetworkEntryState.available,
    ),
    NetworkEntry(
      ssid: 'CoffeeShop',
      strength: 48,
      secure: false,
      state: NetworkEntryState.available,
    ),
    NetworkEntry(
      ssid: 'Printer-Setup',
      strength: 28,
      secure: true,
      state: NetworkEntryState.available,
    ),
  ];

  static NetworkStatus get connected => NetworkStatus(
    wifiEnabled: true,
    devicePresent: true,
    scanning: false,
    activeSsid: 'Hyprnet_5G',
    traffic: traffic,
    networks: networks,
    interfaces: const <NetworkInterface>[
      wifiInterface,
      ethernetInterface,
      loopbackInterface,
    ],
  );

  static NetworkStatus get scanning => NetworkStatus(
    wifiEnabled: true,
    devicePresent: true,
    scanning: true,
    activeSsid: null,
    traffic: traffic,
    networks: const <NetworkEntry>[],
    interfaces: const <NetworkInterface>[wifiInterface],
  );

  static NetworkStatus get wifiOff => NetworkStatus(
    wifiEnabled: false,
    devicePresent: true,
    scanning: false,
    activeSsid: null,
    traffic: NetworkTraffic(
      upload: _transfer(bytesPerSecond: 0, totalBytes: 0),
      download: _transfer(bytesPerSecond: 0, totalBytes: 0),
      pingMs: null,
    ),
    networks: const <NetworkEntry>[],
    interfaces: const <NetworkInterface>[wifiInterface],
  );

  static NetworkStatus get noDevice => NetworkStatus(
    wifiEnabled: false,
    devicePresent: false,
    scanning: false,
    activeSsid: null,
    traffic: NetworkTraffic(
      upload: _transfer(bytesPerSecond: 0, totalBytes: 0),
      download: _transfer(bytesPerSecond: 0, totalBytes: 0),
      pingMs: null,
    ),
    networks: const <NetworkEntry>[],
    interfaces: const <NetworkInterface>[],
  );

  static NetworkStatus get serviceError =>
      connected.copyWith(message: () => 'Network service unavailable.');
}
