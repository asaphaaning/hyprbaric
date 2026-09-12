import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';
import 'network_fixtures.dart';

@UseCase(
  name: 'Connected — networks and traffic',
  type: NetworkPanel,
  path: '[Widgets]/Network',
)
Widget buildConnectedNetworkPanel(BuildContext context) {
  return _NetworkPanelStory(
    status: AsyncValue<NetworkStatus>.data(NetworkFixtures.connected),
  );
}

@UseCase(name: 'Scanning', type: NetworkPanel, path: '[Widgets]/Network')
Widget buildScanningNetworkPanel(BuildContext context) {
  return _NetworkPanelStory(
    status: AsyncValue<NetworkStatus>.data(NetworkFixtures.scanning),
  );
}

@UseCase(name: 'Wi-Fi off', type: NetworkPanel, path: '[Widgets]/Network')
Widget buildWifiOffNetworkPanel(BuildContext context) {
  return _NetworkPanelStory(
    status: AsyncValue<NetworkStatus>.data(NetworkFixtures.wifiOff),
  );
}

@UseCase(name: 'No device', type: NetworkPanel, path: '[Widgets]/Network')
Widget buildNoDeviceNetworkPanel(BuildContext context) {
  return _NetworkPanelStory(
    status: AsyncValue<NetworkStatus>.data(NetworkFixtures.noDevice),
  );
}

@UseCase(
  name: 'Service unavailable',
  type: NetworkPanel,
  path: '[Widgets]/Network',
)
Widget buildNetworkServiceError(BuildContext context) {
  return _NetworkPanelStory(
    status: AsyncValue<NetworkStatus>.data(NetworkFixtures.serviceError),
  );
}

@UseCase(name: 'Loading', type: NetworkPanel, path: '[Widgets]/Network')
Widget buildLoadingNetworkPanel(BuildContext context) {
  return const _NetworkPanelStory(status: AsyncValue<NetworkStatus>.loading());
}

@UseCase(
  name: 'Interactive Wi-Fi',
  type: NetworkPanel,
  path: '[Widgets]/Network',
)
Widget buildInteractiveNetworkPanel(BuildContext context) {
  return const _InteractiveNetworkPanelStory();
}

class _NetworkPanelStory extends StatelessWidget {
  const _NetworkPanelStory({required this.status});

  final AsyncValue<NetworkStatus> status;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: CatalogCanvas(
        child: NetworkPanel(
          history: referenceHistory(),
          status: status,
          latestResult: null,
          onSetWifiEnabled: (_) {},
          onConnect: (_, _) {},
          onOpenSettings: () {},
          onScan: () {},
          onJoin: (_) {},
          onDisconnect: (_) {},
          onAutoConnect: (_, {required enabled}) {},
        ),
      ),
    );
  }
}

class _InteractiveNetworkPanelStory extends StatefulWidget {
  const _InteractiveNetworkPanelStory();

  @override
  State<_InteractiveNetworkPanelStory> createState() =>
      _InteractiveNetworkPanelStoryState();
}

class _InteractiveNetworkPanelStoryState
    extends State<_InteractiveNetworkPanelStory> {
  bool wifiEnabled = true;
  NetworkEntryState selectedState = NetworkEntryState.active;

  @override
  Widget build(BuildContext context) {
    final List<NetworkEntry> networks = NetworkFixtures.networks
        .map(
          (NetworkEntry entry) => entry.ssid == 'Hyprnet_5G'
              ? entry.copyWith(
                  state: wifiEnabled
                      ? selectedState
                      : NetworkEntryState.available,
                )
              : entry,
        )
        .toList(growable: false);

    return ProviderScope(
      child: CatalogCanvas(
        child: NetworkPanel(
          history: referenceHistory(),
          status: AsyncValue<NetworkStatus>.data(
            NetworkFixtures.connected.copyWith(
              wifiEnabled: wifiEnabled,
              activeSsid: () => wifiEnabled ? 'Hyprnet_5G' : null,
              networks: networks,
            ),
          ),
          latestResult: null,
          onSetWifiEnabled: (bool enabled) {
            setState(() => wifiEnabled = enabled);
          },
          onConnect: (NetworkEntry entry, String? password) {
            if (entry.secure) {
              setState(() => selectedState = NetworkEntryState.active);
            }
          },
          onOpenSettings: () {},
          onScan: () {},
          onJoin: (_) {},
          onDisconnect: (_) {},
          onAutoConnect: (_, {required enabled}) {},
        ),
      ),
    );
  }
}

/// Deterministic recorded observations, confined to the preview boundary.
TrafficHistory referenceHistory({int seconds = 60}) {
  var history = const TrafficHistory.empty();
  for (var second = 0; second <= seconds; second++) {
    history = history.record(
      TrafficSample(
        at: Duration(seconds: second),
        download: second == 60
            ? 28.4
            : 42 + 9 * math.sin(second * .62) + 5 * math.sin(second * 1.77),
        upload: second == 60
            ? 4.7
            : 6.4 +
                  1.3 * math.sin(second * .72 + .7) +
                  .9 * math.sin(second * 1.8),
      ),
    );
  }
  return history;
}

@UseCase(name: 'Reference', type: NetworkPanel, path: '[Widgets]/Network')
Widget buildReferenceNetworkPanel(BuildContext context) =>
    const _NetworkReference();

@UseCase(
  name: 'Chronology — 4 seconds',
  type: NetworkPanel,
  path: '[Widgets]/Network',
)
Widget buildNetworkFourSeconds(BuildContext context) =>
    const _NetworkReference(seconds: 4);

@UseCase(
  name: 'Chronology — 27 seconds',
  type: NetworkPanel,
  path: '[Widgets]/Network',
)
Widget buildNetworkTwentySevenSeconds(BuildContext context) =>
    const _NetworkReference(seconds: 27);

@UseCase(
  name: 'Chronology — 58 seconds',
  type: NetworkPanel,
  path: '[Widgets]/Network',
)
Widget buildNetworkFiftyEightSeconds(BuildContext context) =>
    const _NetworkReference(seconds: 58);

@UseCase(name: 'Ethernet', type: NetworkPanel, path: '[Widgets]/Network')
Widget buildNetworkEthernet(BuildContext context) =>
    const _NetworkReference(tab: NetworkTab.ethernet);

@UseCase(name: 'VPN', type: NetworkPanel, path: '[Widgets]/Network')
Widget buildNetworkVpn(BuildContext context) =>
    const _NetworkReference(tab: NetworkTab.vpn);

@UseCase(name: 'Choose network', type: NetworkPanel, path: '[Widgets]/Network')
Widget buildNetworkChooser(BuildContext context) =>
    const _NetworkReference(page: WifiChoosing());

@UseCase(name: 'Join network', type: NetworkPanel, path: '[Widgets]/Network')
Widget buildNetworkJoin(BuildContext context) =>
    _NetworkReference(page: WifiCredentials(NetworkFixtures.networks[1]));

class _NetworkReference extends StatefulWidget {
  const _NetworkReference({
    this.seconds = 60,
    this.tab = NetworkTab.wifi,
    this.page = const WifiOverview(),
  });
  final int seconds;
  final NetworkTab tab;
  final WifiPage page;

  @override
  State<_NetworkReference> createState() => _NetworkReferenceState();
}

class _NetworkReferenceState extends State<_NetworkReference> {
  NetworkStatus _status = NetworkFixtures.reference;

  void _connect(NetworkEntry selected, String? password) {
    setState(
      () => _status = _status.copyWith(
        activeSsid: () => selected.ssid,
        networks: _status.networks
            .map(
              (entry) => entry.copyWith(
                state: entry.ssid == selected.ssid
                    ? NetworkEntryState.active
                    : NetworkEntryState.available,
              ),
            )
            .toList(),
      ),
    );
  }

  void _join(NetworkJoinRequest request) {
    setState(
      () => _status = _status.copyWith(
        activeSsid: () => request.ssid,
        networks: [
          NetworkEntry(
            ssid: request.ssid,
            strength: 80,
            secure: request.security is NetworkSecurityPersonal,
            state: NetworkEntryState.active,
          ),
          ..._status.networks.map(
            (entry) => entry.copyWith(state: NetworkEntryState.available),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF172C55), Color(0xFF090D1A), Color(0xFF3B214E)],
      ),
    ),
    child: Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: ProviderScope(
          child: NetworkPanel(
            history: referenceHistory(seconds: widget.seconds),
            initialTab: widget.tab,
            initialPage: widget.page,
            status: AsyncData(_status),
            onJoin: _join,
            onDisconnect: (device) => setState(
              () => _status = _status.copyWith(
                activeSsid: () => device.kind == NetworkInterfaceKind.wifi
                    ? null
                    : _status.activeSsid,
                interfaces: _status.interfaces
                    .map(
                      (entry) => entry.name == device.name
                          ? entry.copyWith(active: false, address: () => null)
                          : entry,
                    )
                    .toList(),
                networks: device.kind == NetworkInterfaceKind.wifi
                    ? _status.networks
                          .map(
                            (entry) => entry.copyWith(
                              state: NetworkEntryState.available,
                            ),
                          )
                          .toList()
                    : _status.networks,
              ),
            ),
            onAutoConnect: (device, {required enabled}) => setState(
              () => _status = _status.copyWith(
                interfaces: _status.interfaces
                    .map(
                      (entry) => entry.name == device.name
                          ? entry.copyWith(autoConnect: () => enabled)
                          : entry,
                    )
                    .toList(),
              ),
            ),
            latestResult: null,
            onSetWifiEnabled: (enabled) => setState(
              () => _status = _status.copyWith(wifiEnabled: enabled),
            ),
            onConnect: _connect,
            onOpenSettings: () {},
            onScan: () {},
          ),
        ),
      ),
    ),
  );
}

@UseCase(name: 'Other network', type: NetworkPanel, path: '[Widgets]/Network')
Widget buildOtherNetworkPanel(BuildContext context) =>
    const _NetworkReference(page: WifiOther());
