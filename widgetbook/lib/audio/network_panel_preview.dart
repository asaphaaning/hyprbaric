import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';

import '../use_cases/network/network_fixtures.dart';

/// Interactive Network / Wi-Fi preview shared by Widgetbook and the website.
class NetworkPanelPreview extends StatefulWidget {
  const NetworkPanelPreview({super.key, this.initialStatus});

  final NetworkStatus? initialStatus;

  @override
  State<NetworkPanelPreview> createState() => _NetworkPanelPreviewState();
}

class _NetworkPanelPreviewState extends State<NetworkPanelPreview> {
  late NetworkStatus _status;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus ?? NetworkFixtures.connected;
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: NetworkPanel(
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        status: AsyncData<NetworkStatus>(_status),
        latestResult: null,
        onSetWifiEnabled: _setWifiEnabled,
        onConnect: _connect,
        onOpenSettings: _ignore,
      ),
    );
  }

  void _setWifiEnabled(bool enabled) {
    setState(() {
      _status = _status.copyWith(
        wifiEnabled: enabled,
        devicePresent: enabled,
        scanning: enabled,
        networks: enabled ? NetworkFixtures.connected.networks : const [],
      );
    });
  }

  void _connect(NetworkEntry entry, String? _) {
    setState(() {
      _status = _status.copyWith(
        activeSsid: () => entry.ssid,
        networks: _status.networks
            .map(
              (NetworkEntry network) => network.copyWith(
                state: network.ssid == entry.ssid
                    ? NetworkEntryState.active
                    : NetworkEntryState.available,
              ),
            )
            .toList(growable: false),
      );
    });
  }
}

void _ignore() {}
