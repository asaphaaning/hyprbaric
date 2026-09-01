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
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          status: status,
          latestResult: null,
          onSetWifiEnabled: (_) {},
          onConnect: (_, _) {},
          onOpenSettings: () {},
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
          borderRadius: const BorderRadius.all(Radius.circular(18)),
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
        ),
      ),
    );
  }
}
