import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';

import '../use_cases/network/network_fixtures.dart';

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
  late final AnimationController _trafficClock;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus ?? NetworkFixtures.connected;
    _trafficClock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
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
        widget.animateTraffic && !MediaQuery.disableAnimationsOf(context);
    if (motionEnabled && !_trafficClock.isAnimating) {
      _trafficClock.repeat();
    } else if (!motionEnabled && _trafficClock.isAnimating) {
      _trafficClock.stop();
    }
  }

  @override
  void dispose() {
    _trafficClock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _trafficClock,
      builder: (BuildContext context, Widget? child) {
        final NetworkStatus status = widget.animateTraffic
            ? _status.copyWith(
                traffic: NetworkTrafficDance.sample(_trafficClock.value)
                    .traffic,
              )
            : _status;

        return ProviderScope(
          child: NetworkPanel(
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            status: AsyncData<NetworkStatus>(status),
            latestResult: null,
            onSetWifiEnabled: _setWifiEnabled,
            onConnect: _connect,
            onOpenSettings: _ignore,
          ),
        );
      },
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

/// A deterministic burst pattern that gives catalog previews a lively signal.
///
/// The stepwise samples deliberately avoid an eased waveform. Network traffic
/// tends to idle near a low baseline before short, uneven bursts, so the graph
/// and parameter rails read like telemetry rather than an animation. It exists
/// at the story boundary: production panels still receive measurements from
/// the network runtime.
@immutable
class NetworkTrafficDance {
  const NetworkTrafficDance._({
    required this.uploadMegabytesPerSecond,
    required this.downloadMegabytesPerSecond,
    required this.pingMs,
  });

  final double uploadMegabytesPerSecond;
  final double downloadMegabytesPerSecond;
  final int pingMs;

  static const List<double> _uploadPattern = <double>[
    .03,
    .05,
    .04,
    .08,
    .45,
    .12,
    .07,
    1.80,
    .30,
    .10,
    .06,
    3.80,
    .18,
    .08,
    .05,
    .12,
    .90,
    .24,
    .04,
    .08,
    2.50,
    .34,
    .09,
    .05,
  ];

  static const List<double> _downloadPattern = <double>[
    2.0,
    2.6,
    3.1,
    8.5,
    4.2,
    18.0,
    5.8,
    3.4,
    12.2,
    5.1,
    2.8,
    7.4,
    3.0,
    16.8,
    4.4,
    2.2,
    11.6,
    4.7,
    2.9,
    6.1,
    15.4,
    3.8,
    2.5,
    5.3,
  ];

  static NetworkTrafficDance sample(double progress) {
    final double upload = _samplePattern(_uploadPattern, progress);
    final double download = _samplePattern(_downloadPattern, progress + .17);
    final int ping =
        8 + (_samplePattern(_uploadPattern, progress + .38) * 2).round();

    return NetworkTrafficDance._(
      uploadMegabytesPerSecond: upload,
      downloadMegabytesPerSecond: download,
      pingMs: ping,
    );
  }

  NetworkTraffic get traffic {
    return NetworkTraffic(
      upload: _transfer(
        megabytesPerSecond: uploadMegabytesPerSecond,
        totalMegabytes: 1280 + uploadMegabytesPerSecond * 3,
      ),
      download: _transfer(
        megabytesPerSecond: downloadMegabytesPerSecond,
        totalMegabytes: 14580 + downloadMegabytesPerSecond * 4,
      ),
      pingMs: pingMs,
    );
  }

  static double _samplePattern(List<double> pattern, double progress) {
    final double looped = progress % 1;
    final int index = (looped * pattern.length).floor() % pattern.length;
    return pattern[index];
  }

  static NetworkTransfer _transfer({
    required double megabytesPerSecond,
    required double totalMegabytes,
  }) {
    const int bytesPerMegabyte = 1024 * 1024;
    return NetworkTransfer(
      bytesPerSecond: Uint64.fromBigInt(
        BigInt.from((megabytesPerSecond * bytesPerMegabyte).round()),
      ),
      totalBytes: Uint64.fromBigInt(
        BigInt.from((totalMegabytes * bytesPerMegabyte).round()),
      ),
    );
  }
}

void _ignore() {}
