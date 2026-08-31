import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../audio/audio_fixtures.dart';
import '../notifications/notification_fixtures.dart';
import '../power/power_fixtures.dart';

@UseCase(name: 'Desktop — active', type: Hyprbaric, path: '[Widgets]/Bar')
Widget buildDesktopBar(BuildContext context) {
  return const _BarStory(power: PowerFixtures.desktop);
}

@UseCase(name: 'Laptop — active', type: Hyprbaric, path: '[Widgets]/Bar')
Widget buildLaptopBar(BuildContext context) {
  return _BarStory(power: PowerFixtures.laptop());
}

/// A complete, production [Hyprbaric] with stable source-of-truth snapshots.
///
/// Widgetbook owns only the signal boundary. The bar, its clusters, and every
/// visible component remain the production implementation.
class _BarStory extends StatelessWidget {
  const _BarStory({required this.power});

  final PowerStatus power;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        setupGuideAutomaticHostProvider.overrideWithValue(false),
        workspaceStatusProvider.overrideWith(
          (Ref ref) => Stream<WorkspaceStatus>.value(BarFixtures.workspace),
        ),
        focusedWindowStatusProvider.overrideWith(
          (Ref ref) =>
              Stream<FocusedWindowStatus>.value(BarFixtures.focusedWindow),
        ),
        networkStatusProvider.overrideWith(
          (Ref ref) => Stream<NetworkStatus>.value(BarFixtures.network),
        ),
        audioStatusProvider.overrideWith(
          (Ref ref) => Stream<AudioStatus>.value(AudioFixtures.ready),
        ),
        brightnessStatusProvider.overrideWith(
          (Ref ref) => Stream<BrightnessStatus>.value(AudioFixtures.brightness),
        ),
        notificationStatusProvider.overrideWith(
          (Ref ref) => Stream<NotificationStatus>.value(
            NotificationFixtures.populated(),
          ),
        ),
        powerStatusProvider.overrideWith(
          (Ref ref) => Stream<PowerStatus>.value(power),
        ),
        clockStatusProvider.overrideWith(
          (Ref ref) => Stream<ClockStatus>.value(BarFixtures.clock),
        ),
      ],
      child: const Hyprbaric(),
    );
  }
}

/// Representative, typed live facts for the full-bar composition stories.
abstract final class BarFixtures {
  static const WorkspaceStatus workspace = WorkspaceStatus(
    id: 2,
    name: '2',
    isSpecial: false,
    occupiedWorkspaceIds: <int>[1, 2, 4],
    monitors: <MonitorWorkspaceStatus>[],
  );

  static const FocusedWindowStatus focusedWindow = FocusedWindowStatus(
    appName: 'dev.zed.Zed',
    title: 'widget_catalog.dart — Hyprbaric',
    hostname: 'hyprbaric',
    monitors: <MonitorFocusedWindowStatus>[],
  );

  static final NetworkStatus network = NetworkStatus(
    wifiEnabled: true,
    devicePresent: true,
    scanning: false,
    activeSsid: 'Hyprnet_5G',
    traffic: NetworkTraffic(
      upload: NetworkTransfer(
        bytesPerSecond: Uint64.fromBigInt(BigInt.from(407184)),
        totalBytes: Uint64.fromBigInt(BigInt.from(1288490188)),
      ),
      download: NetworkTransfer(
        bytesPerSecond: Uint64.fromBigInt(BigInt.from(1506060145)),
        totalBytes: Uint64.fromBigInt(BigInt.from(15461882266)),
      ),
      pingMs: 10,
    ),
    networks: <NetworkEntry>[
      NetworkEntry(
        ssid: 'Hyprnet_5G',
        strength: 92,
        secure: true,
        state: NetworkEntryState.active,
      ),
    ],
    interfaces: <NetworkInterface>[
      NetworkInterface(name: 'wlo1', address: '192.168.1.42', active: true),
    ],
  );

  static const ClockStatus clock = ClockStatus(
    timeLabel: '08:18',
    dateLabel: 'Sun, Aug 30',
    monthLabel: 'August 2026',
    weekNumber: 35,
    utcOffset: 'UTC+02:00',
    days: <CalendarDay>[],
  );
}
