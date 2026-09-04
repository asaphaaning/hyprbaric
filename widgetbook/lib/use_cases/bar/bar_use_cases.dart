import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../audio/audio_fixtures.dart';
import '../notifications/notification_fixtures.dart';
import '../power/power_fixtures.dart';
import '../settings/settings_fixtures.dart';
import '../tray/tray_fixtures.dart';

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
///
/// Every status provider the bar reads is overridden here. Anything left out
/// falls through to the real RINF stream, and the catalog never initialises
/// RINF, so an omission renders as a region stuck in [AsyncLoading] forever
/// rather than as an obvious failure.
class _BarStory extends StatelessWidget {
  const _BarStory({required this.power});

  final PowerStatus power;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        setupGuideAutomaticHostProvider.overrideWithValue(false),
        _stream(workspaceStatusProvider, BarFixtures.workspace),
        _stream(
          workspaceSettingsStatusProvider,
          SettingsFixtures.workspacesRoman,
        ),
        _stream(focusedWindowStatusProvider, BarFixtures.focusedWindow),
        _stream(networkStatusProvider, BarFixtures.network),
        _stream(audioStatusProvider, AudioFixtures.ready),
        _stream(brightnessStatusProvider, AudioFixtures.brightness),
        _stream(notificationStatusProvider, NotificationFixtures.populated()),
        _stream(powerStatusProvider, power),
        _stream(clockStatusProvider, BarFixtures.clock),
        _stream(appearanceStatusProvider, SettingsFixtures.appearanceDefault),
        _stream(modulesStatusProvider, SettingsFixtures.modulesAll),
        _stream(capabilityStatusProvider, SettingsFixtures.capabilities),
        _stream(scheduleStatusProvider, SettingsFixtures.scheduleEnabled),
        _stream(nightLightStatusProvider, SettingsFixtures.nightLightOn),
        _stream(appStatusProvider, SettingsFixtures.app),
        _stream(trayStatusProvider, TrayFixtures.populated),
        _stream(caffeineStatusProvider, BarFixtures.caffeine),
        _stream(recordingStatusProvider, BarFixtures.recording),
        _stream(setupStatusProvider, BarFixtures.setup),
        _stream(portalStatusProvider, BarFixtures.portal),
      ],
      child: const Hyprbaric(),
    );
  }
}

/// Pins one stream provider to a single deterministic snapshot.
Override _stream<T>(StreamProvider<T> provider, T value) {
  return provider.overrideWith((Ref ref) => Stream<T>.value(value));
}

/// Representative, typed live facts for the full-bar composition stories.
abstract final class BarFixtures {
  /// ControlsScenario types these nullable for ControlsPanel, but the
  /// providers are not nullable, so the bar story declares its own.
  static const CaffeineStatus caffeine = CaffeineStatusAvailable(
    enabled: false,
  );

  static const RecordingStatus recording = RecordingStatusIdle();

  static const SetupStatus setup = SetupStatus(state: SetupState.complete);

  static const PortalStatus portal = PortalStatus(
    colorScheme: PortalColorScheme.preferDark,
  );

  static const WorkspaceStatus workspace = WorkspaceStatus(
    id: 2,
    name: '2',
    isSpecial: false,
    occupiedWorkspaceIds: <int>[1, 2, 4],
    monitors: [],
  );

  static const FocusedWindowStatus focusedWindow = FocusedWindowStatus(
    appName: 'dev.zed.Zed',
    title: 'widget_catalog.dart — Hyprbaric',
    hostname: 'hyprbaric',
    monitors: [],
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
