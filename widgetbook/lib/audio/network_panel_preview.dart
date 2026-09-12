import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';

import '../use_cases/network/network_fixtures.dart';
import 'network_traffic_demo.dart';

/// Interactive Network / Wi-Fi preview shared by Widgetbook and the website.
class NetworkPanelPreview extends StatefulWidget {
  const NetworkPanelPreview({
    super.key,
    this.initialStatus,
    this.animateTraffic = true,
  });

  final NetworkStatus? initialStatus;
  final bool animateTraffic;

  @override
  State<NetworkPanelPreview> createState() => _NetworkPanelPreviewState();
}

class _NetworkPanelPreviewState extends State<NetworkPanelPreview>
    with SingleTickerProviderStateMixin {
  late NetworkStatus _status;
  late final Ticker _trafficClock;
  TrafficHistory _history = NetworkTrafficDemo.prefill();
  Duration _elapsed = Duration.zero;
  Duration _offset = Duration.zero;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus ?? NetworkFixtures.reference;
    _trafficClock = createTicker(_advance);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTrafficClock();
  }

  @override
  void didUpdateWidget(covariant NetworkPanelPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animateTraffic != widget.animateTraffic) {
      _syncTrafficClock();
    }
  }

  void _syncTrafficClock() {
    final bool motionEnabled =
        widget.animateTraffic &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (motionEnabled && !_trafficClock.isActive) {
      _offset = _elapsed;
      _trafficClock.start();
    } else if (!motionEnabled && _trafficClock.isActive) {
      _trafficClock.stop();
    }
  }

  @override
  void dispose() {
    _trafficClock.dispose();
    super.dispose();
  }

  void _advance(Duration elapsed) {
    final next = _offset + elapsed;
    if (next - _elapsed < const Duration(milliseconds: 100)) return;
    setState(() {
      _elapsed = next;
      _history = _history.record(
        NetworkTrafficDemo.sample(TrafficHistory.window + next),
      );
    });
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    child: NetworkPanel(
      borderRadius: NetworkPanel.radius,
      history: _history,
      status: AsyncData<NetworkStatus>(
        _status.copyWith(traffic: NetworkTrafficDemo.traffic(_history.latest!)),
      ),
      latestResult: null,
      onSetWifiEnabled: _setWifiEnabled,
      onConnect: _connect,
      onOpenSettings: _ignore,
      onScan: _ignore,
      onJoin: (_) {},
      onDisconnect: (_) {},
      onAutoConnect: (_, {required enabled}) {},
    ),
  );

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
