// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/bindings/bindings.dart';
import 'package:hyprbaric/src/features/audio/audio_fader.dart';
import 'package:hyprbaric/src/features/audio/audio_panel.dart';
import 'package:hyprbaric/src/features/audio/brightness_control.dart';
import 'package:hyprbaric/src/features/controls/control_rocker.dart';
import 'package:hyprbaric/src/features/controls/control_settings_row.dart';
import 'package:hyprbaric/src/features/controls/controls_chrome.dart';
import 'package:hyprbaric/src/features/controls/controls_panel.dart';
import 'package:hyprbaric/src/features/launcher/app_launcher_results.dart';
import 'package:hyprbaric/src/features/network/network_panel.dart';
import 'package:hyprbaric/src/features/power/battery_chip.dart';
import 'package:hyprbaric/src/features/power/power_panel.dart';
import 'package:hyprbaric/src/features/rust_commands.dart';
import 'package:hyprbaric/src/features/session/session_launcher_content.dart';
import 'package:hyprbaric/src/features/settings/appearance_settings_panel.dart';
import 'package:hyprbaric/src/features/settings/keybindings/keybindings_panel.dart';
import 'package:hyprbaric/src/features/settings/night_light_settings_panel.dart';
import 'package:hyprbaric/src/features/settings/settings_overlay_content.dart';
import 'package:hyprbaric/src/features/settings/settings_overlay_layout.dart';
import 'package:hyprbaric/src/features/settings/settings_rows.dart';
import 'package:hyprbaric/src/features/settings/settings_tabs.dart';
import 'package:hyprbaric/src/features/setup/setup_guide_state.dart';
import 'package:hyprbaric/src/features/tray/tray_menu_panel.dart';
import 'package:hyprbaric/src/features/tray/tray_strip.dart';
import 'package:hyprbaric/src/hyprbaric.dart';
import 'package:hyprbaric/src/layer_shell_controller.dart';
import 'package:hyprbaric/src/layer_shell_hit_region.dart';
import 'package:hyprbaric/src/native/layer_shell_api.g.dart';
import 'package:hyprbaric/src/state/providers.dart';
import 'package:hyprbaric/src/widgets/center_cluster.dart';
import 'package:hyprbaric/src/widgets/hypr_surface.dart';
import 'package:hyprbaric/src/widgets/layer_shell_dropdown.dart';
import 'package:hyprbaric/src/widgets/left_cluster.dart';
import 'package:hyprbaric/src/widgets/primitives/primitives.dart';
import 'package:hyprbaric/src/widgets/right_cluster.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:rinf/rinf.dart';

const BasicMessageChannel<Object?> _layerShellSetRegionChannel =
    BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.hyprbaric.NativeLayerShellHostApi.setRegion',
      NativeLayerShellHostApi.pigeonChannelCodec,
    );
const BasicMessageChannel<Object?> _layerShellSetKeyboardModeChannel =
    BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.hyprbaric.NativeLayerShellHostApi.setKeyboardMode',
      NativeLayerShellHostApi.pigeonChannelCodec,
    );

Map<String, Object?> _regionPayloadFromMessage(Object? message) {
  final List<Object?> arguments = message! as List<Object?>;
  final NativeLayerShellRegionRequest request =
      arguments.single! as NativeLayerShellRegionRequest;
  return <String, Object?>{
    'bar_h': request.barHeight,
    'bar_edge': request.barEdge.name,
    'menu': request.menu == null ? null : _regionPayload(request.menu!),
    'regions': request.passiveRegions
        .map(_regionPayload)
        .toList(growable: false),
    'capture_all_clicks': request.captureAllClicks,
  };
}

Map<String, Object?> _regionPayload(NativeLayerShellRegion region) =>
    <String, Object?>{
      'x': region.x,
      'y': region.y,
      'w': region.width,
      'h': region.height,
      'r_tl': region.radiusTopLeft,
      'r_tr': region.radiusTopRight,
      'r_br': region.radiusBottomRight,
      'r_bl': region.radiusBottomLeft,
    };

class _RecordingRustDispatcher extends RustCommandDispatcher {
  final List<RustIntent> intents = <RustIntent>[];

  @override
  void dispatch(RustIntent intent) {
    intents.add(intent);
  }
}

void _setRegionMock(FutureOr<Object?> Function(Object? message)? handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(
        _layerShellSetRegionChannel.name,
        handler == null
            ? null
            : (ByteData? message) async {
                final Object? decoded = _layerShellSetRegionChannel.codec
                    .decodeMessage(message);
                final Object? response = await handler(decoded);
                return _layerShellSetRegionChannel.codec.encodeMessage(
                  response,
                );
              },
      );
}

void _setKeyboardModeMock(
  FutureOr<Object?> Function(Object? message)? handler,
) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(
        _layerShellSetKeyboardModeChannel.name,
        handler == null
            ? null
            : (ByteData? message) async {
                final Object? decoded = _layerShellSetKeyboardModeChannel.codec
                    .decodeMessage(message);
                final Object? response = await handler(decoded);
                return _layerShellSetKeyboardModeChannel.codec.encodeMessage(
                  response,
                );
              },
      );
}

List<Object?> _pigeonSuccess() => <Object?>[null];

Finder _iconsaxGlyphFinder(IconData icon) =>
    find.byKey(ValueKey<String>('iconsax-glyph-${icon.codePoint}'));

List<Text> _textsForGlyph(WidgetTester tester, IconData icon) {
  return tester
      .widgetList<Text>(
        find.descendant(
          of: _iconsaxGlyphFinder(icon),
          matching: find.byType(Text),
        ),
      )
      .toList(growable: false);
}

List<Text> _expectStrokedIconsaxGlyph(WidgetTester tester, IconData icon) {
  expect(_iconsaxGlyphFinder(icon), findsOneWidget);
  final List<Text> glyphs = _textsForGlyph(tester, icon);
  expect(glyphs.length, greaterThanOrEqualTo(2));
  final Paint? stroke = glyphs.first.style?.foreground;
  expect(stroke?.style, PaintingStyle.stroke);
  expect(stroke?.strokeWidth, greaterThan(0.4));
  expect(glyphs.last.style?.color, HyprColors.textMuted);
  return glyphs;
}

AppLauncherEntry _appEntry({
  String id = 'firefox.desktop',
  String name = 'Firefox',
  String? subtitle = 'Web Browser',
  bool terminal = false,
}) {
  return AppLauncherEntry(
    id: id,
    name: name,
    subtitle: subtitle,
    terminal: terminal,
  );
}

NetworkStatus _networkStatus({
  bool wifiEnabled = true,
  String activeSsid = 'Fiber_5G',
  List<NetworkEntry> extraNetworks = const <NetworkEntry>[],
}) {
  return NetworkStatus(
    wifiEnabled: wifiEnabled,
    devicePresent: true,
    scanning: false,
    activeSsid: activeSsid,
    traffic: NetworkTraffic(
      upload: NetworkTransfer(
        bytesPerSecond: Uint64(BigInt.from(24_800_000)),
        totalBytes: Uint64(BigInt.from(1_200_000_000)),
      ),
      download: NetworkTransfer(
        bytesPerSecond: Uint64(BigInt.from(59_100_000)),
        totalBytes: Uint64(BigInt.from(14_800_000_000)),
      ),
      pingMs: 25,
    ),
    networks: <NetworkEntry>[
      NetworkEntry(
        ssid: activeSsid,
        bssid: 'aa:bb:cc:dd:ee:ff',
        strength: 86,
        secure: true,
        state: NetworkEntryState.active,
      ),
      const NetworkEntry(
        ssid: 'Fiber_2.4G',
        bssid: '11:22:33:44:55:66',
        strength: 58,
        secure: true,
        state: NetworkEntryState.available,
      ),
      const NetworkEntry(
        ssid: 'starbucks-guest',
        bssid: '66:55:44:33:22:11',
        strength: 41,
        secure: false,
        state: NetworkEntryState.available,
      ),
      ...extraNetworks,
    ],
    interfaces: const <NetworkInterface>[
      NetworkInterface(name: 'wlo1', address: '192.168.1.42', active: true),
      NetworkInterface(name: 'eth0', active: false),
      NetworkInterface(name: 'lo', address: '127.0.0.1', active: true),
    ],
    message: null,
  );
}

AudioStatus _audioStatus() {
  return const AudioStatusAvailable(
    output: AudioEndpoint(
      kind: AudioEndpointKind.output,
      id: '117',
      name: 'EVO4 Analog Surround 4.0',
      volume: 62,
      muted: false,
    ),
    input: AudioEndpoint(
      kind: AudioEndpointKind.input,
      id: '116',
      name: 'Built-in Mic',
      volume: 80,
      muted: false,
    ),
  );
}

TrayStatus _trayStatus() {
  return const TrayStatus(
    items: <TrayItem>[
      TrayItem(
        id: 'org.example.Dropbox',
        title: 'Dropbox',
        status: TrayItemStatus.active,
        icon: TrayIcon(kind: TrayIconKind.none, symbolic: true),
      ),
      TrayItem(
        id: 'org.example.Spotify',
        title: 'Spotify',
        description: 'Playing',
        status: TrayItemStatus.passive,
        icon: TrayIcon(kind: TrayIconKind.none, symbolic: true),
      ),
    ],
  );
}

PowerStatus _powerStatus() {
  return PowerStatus(
    batteryPresent: true,
    percentage: 72,
    state: PowerBatteryState.discharging,
    remainingSeconds: Uint64.fromBigInt(BigInt.from(12600)),
    powerRateWatts: -8.2,
    voltage: 11.84,
    temperatureCelsius: 28,
    activeProfile: PowerProfile.balanced,
    availableProfiles: <PowerProfile>[
      PowerProfile.saver,
      PowerProfile.balanced,
      PowerProfile.performance,
    ],
  );
}

PowerStatus _desktopPowerStatus() {
  return const PowerStatus(
    batteryPresent: false,
    percentage: null,
    state: PowerBatteryState.unknown,
    remainingSeconds: null,
    powerRateWatts: null,
    voltage: null,
    temperatureCelsius: null,
    activeProfile: PowerProfile.balanced,
    availableProfiles: <PowerProfile>[
      PowerProfile.saver,
      PowerProfile.balanced,
      PowerProfile.performance,
    ],
  );
}

NotificationStatus _notificationStatus() {
  return NotificationStatus(
    available: true,
    unreadCount: 2,
    dndEnabled: false,
    entries: <NotificationEntry>[
      NotificationEntry(
        id: 7,
        app: 'Slack',
        message: 'Maya: "wfh today, ping me before standup"',
        createdAtMs: Uint64.fromBigInt(
          BigInt.from(
            DateTime.now()
                .subtract(const Duration(minutes: 2))
                .millisecondsSinceEpoch,
          ),
        ),
        urgency: NotificationUrgency.normal,
      ),
      NotificationEntry(
        id: 8,
        app: 'System',
        message: 'Software updates available (4 packages)',
        createdAtMs: Uint64.fromBigInt(
          BigInt.from(
            DateTime.now()
                .subtract(const Duration(minutes: 14))
                .millisecondsSinceEpoch,
          ),
        ),
        urgency: NotificationUrgency.low,
      ),
    ],
  );
}

ClockStatus _clockStatus({String monthLabel = 'April 2026'}) {
  return ClockStatus(
    timeLabel: '22:58',
    dateLabel: 'Wed, Apr 22',
    monthLabel: monthLabel,
    weekNumber: 17,
    utcOffset: 'UTC+02:00',
    days: const <CalendarDay>[
      CalendarDay(
        year: 2026,
        month: 3,
        day: 30,
        currentMonth: false,
        today: false,
      ),
      CalendarDay(
        year: 2026,
        month: 3,
        day: 31,
        currentMonth: false,
        today: false,
      ),
      CalendarDay(
        year: 2026,
        month: 4,
        day: 1,
        currentMonth: true,
        today: false,
      ),
      CalendarDay(
        year: 2026,
        month: 4,
        day: 2,
        currentMonth: true,
        today: false,
      ),
      CalendarDay(
        year: 2026,
        month: 4,
        day: 3,
        currentMonth: true,
        today: false,
      ),
      CalendarDay(
        year: 2026,
        month: 4,
        day: 4,
        currentMonth: true,
        today: false,
      ),
      CalendarDay(
        year: 2026,
        month: 4,
        day: 5,
        currentMonth: true,
        today: false,
      ),
      CalendarDay(
        year: 2026,
        month: 4,
        day: 22,
        currentMonth: true,
        today: true,
      ),
    ],
  );
}

ShortcutEvent _shortcut(int sequence, HotkeyEvent event) {
  return ShortcutEvent(sequence: sequence, event: event);
}

ShortcutBindingView _shortcutBinding({
  required String key,
  required String display,
  ShortcutBindingPhase phase = ShortcutBindingPhase.press,
  List<ShortcutModifier> modifiers = const <ShortcutModifier>[],
}) {
  return ShortcutBindingView(
    phase: phase,
    modifiers: modifiers,
    key: key,
    display: display,
  );
}

ShortcutSettingsSnapshot _shortcutSettingsSnapshot({
  bool appLauncherDisabled = false,
}) {
  final ShortcutMappingView appLauncherMapping = ShortcutMappingViewBound(
    binding: _shortcutBinding(
      key: 'Super_L',
      display: 'Super',
      phase: ShortcutBindingPhase.release,
      modifiers: const <ShortcutModifier>[ShortcutModifier.logo],
    ),
  );

  return ShortcutSettingsSnapshot(
    writablePath: '/home/example/.config/hyprbaric/config.toml',
    rows: <ShortcutSettingsRow>[
      ShortcutSettingsRow(
        shortcut: ShortcutSettingId.appLauncher,
        label: 'App launcher',
        description: 'Open the application launcher.',
        category: ShortcutSettingCategory.bar,
        defaultMapping: appLauncherMapping,
        effectiveMapping: appLauncherDisabled
            ? const ShortcutMappingViewDisabled()
            : appLauncherMapping,
        source: appLauncherDisabled
            ? ShortcutMappingSource.disabled
            : ShortcutMappingSource.builtin,
      ),
      const ShortcutSettingsRow(
        shortcut: ShortcutSettingId.lockSession,
        label: 'Lock session',
        description: 'Lock the current session.',
        category: ShortcutSettingCategory.session,
        defaultMapping: ShortcutMappingViewDisabled(),
        effectiveMapping: ShortcutMappingViewDisabled(),
        source: ShortcutMappingSource.disabled,
      ),
    ],
  );
}

Widget _scopedSurface({required Widget child}) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(child: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    _setRegionMock(null);
    _setKeyboardModeMock(null);
  });

  test('audio controller updates the volume OSD optimistically', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(audioControllerProvider.notifier)
        .setVolume(AudioEndpointKind.output, 144);

    final OsdEvent? osd = container.read(transientOverlayProvider).osd;
    expect(osd, isNotNull);
    expect(osd!.kind, OsdKind.volume);
    expect(osd.value, 100);
    expect(osd.muted, false);
  });

  test(
    'audio controller shows a muted output OSD when no audio snapshot exists',
    () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(audioControllerProvider.notifier)
          .setMuted(AudioEndpointKind.output, muted: true);

      final OsdEvent? osd = container.read(transientOverlayProvider).osd;
      expect(osd, isNotNull);
      expect(osd!.kind, OsdKind.volume);
      expect(osd.value, 0);
      expect(osd.muted, true);
    },
  );

  test('controls controller can publish local control toasts', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(controlsControllerProvider.notifier)
        .showToast('Control action unavailable');

    final List<ToastEntry> toasts = container
        .read(transientOverlayProvider)
        .toasts;
    expect(toasts, hasLength(1));
    expect(toasts.single.app, 'Controls');
    expect(toasts.single.message, 'Control action unavailable');
  });

  test('controls controller dispatches color picker intents', () async {
    final _RecordingRustDispatcher dispatcher = _RecordingRustDispatcher();
    final ProviderContainer container = ProviderContainer(
      overrides: [rustCommandDispatcherProvider.overrideWithValue(dispatcher)],
    );
    addTearDown(container.dispose);

    container.read(controlsControllerProvider.notifier).pickColor();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(dispatcher.intents, hasLength(1));
    expect(dispatcher.intents.single, isA<ColorPickerIntent>());
  });

  test('controls controller dispatches recording intents', () async {
    final _RecordingRustDispatcher dispatcher = _RecordingRustDispatcher();
    final ProviderContainer container = ProviderContainer(
      overrides: [rustCommandDispatcherProvider.overrideWithValue(dispatcher)],
    );
    addTearDown(container.dispose);

    container.read(controlsControllerProvider.notifier).toggleRecording();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(dispatcher.intents, hasLength(1));
    expect(dispatcher.intents.single, isA<RecordingIntent>());
  });

  test('controls controller reports saved recordings', () async {
    final StreamController<RecordingCommandResult> results =
        StreamController<RecordingCommandResult>();
    addTearDown(results.close);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        recordingCommandResultProvider.overrideWith((ref) => results.stream),
      ],
    );
    addTearDown(container.dispose);

    final ProviderSubscription<void> subscription = container.listen(
      controlsControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);

    results.add(
      const RecordingCommandResultSaved(
        command: RecordingCommandToggle(mode: RecordingMode.region),
        path: '/tmp/Recording_2026-06-15-21-00-00.mp4',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final List<ToastEntry> toasts = container
        .read(transientOverlayProvider)
        .toasts;
    expect(toasts, hasLength(1));
    expect(toasts.single.app, 'Recording');
    expect(toasts.single.message, 'Saved Recording_2026-06-15-21-00-00.mp4');
  });

  test('controls controller reports picked colors', () async {
    final StreamController<ColorPickerCommandResult> results =
        StreamController<ColorPickerCommandResult>();
    addTearDown(results.close);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        colorPickerCommandResultProvider.overrideWith((ref) => results.stream),
      ],
    );
    addTearDown(container.dispose);

    final ProviderSubscription<void> subscription = container.listen(
      controlsControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);

    results.add(
      const ColorPickerCommandResult(
        command: ColorPickerCommand.pick,
        outcome: ColorPickerCommandOutcome.picked,
        color: '#38bdf8',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final List<ToastEntry> toasts = container
        .read(transientOverlayProvider)
        .toasts;
    expect(toasts, hasLength(1));
    expect(toasts.single.app, 'Color picker');
    expect(toasts.single.message, 'Copied #38bdf8');
  });

  test('controls controller reports color picker failures', () async {
    final StreamController<ColorPickerCommandResult> results =
        StreamController<ColorPickerCommandResult>();
    addTearDown(results.close);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        colorPickerCommandResultProvider.overrideWith((ref) => results.stream),
      ],
    );
    addTearDown(container.dispose);

    final ProviderSubscription<void> subscription = container.listen(
      controlsControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);

    results.add(
      const ColorPickerCommandResult(
        command: ColorPickerCommand.pick,
        outcome: ColorPickerCommandOutcome.failed,
        message: '`hyprpicker` is unavailable',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final List<ToastEntry> toasts = container
        .read(transientOverlayProvider)
        .toasts;
    expect(toasts, hasLength(1));
    expect(toasts.single.app, 'Color picker');
    expect(toasts.single.message, '`hyprpicker` is unavailable');
    expect(toasts.single.urgency, NotificationUrgency.critical);
  });

  test('controls controller reports night light backend failures', () async {
    final StreamController<NightLightCommandResult> results =
        StreamController<NightLightCommandResult>();
    addTearDown(results.close);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        nightLightCommandResultProvider.overrideWith((ref) => results.stream),
      ],
    );
    addTearDown(container.dispose);

    final ProviderSubscription<void> subscription = container.listen(
      controlsControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);
    results.add(
      const NightLightCommandResultFailed(
        command: NightLightCommandSetEnabled(enabled: true),
        message: 'hyprsunset socket missing',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final List<ToastEntry> toasts = container
        .read(transientOverlayProvider)
        .toasts;
    expect(toasts, hasLength(1));
    expect(toasts.single.app, 'Night light');
    expect(toasts.single.message, 'hyprsunset socket missing');
    expect(toasts.single.urgency, NotificationUrgency.critical);
  });

  test('clock view state projects fallback and live status', () {
    expect(ClockViewState.fromStatus(null).monthLabel, 'Calendar');

    final ClockViewState state = ClockViewState.fromStatus(_clockStatus());
    expect(state.timeLabel, '22:58');
    expect(state.monthLabel, 'April 2026');
    expect(state.days, hasLength(8));
  });

  test('session controller owns confirmation and result state', () async {
    final StreamController<SessionCommandResult> results =
        StreamController<SessionCommandResult>();
    addTearDown(results.close);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        sessionCommandResultProvider.overrideWith((ref) => results.stream),
      ],
    );
    addTearDown(container.dispose);
    final ProviderSubscription<SessionLauncherState> subscription = container
        .listen<SessionLauncherState>(
          sessionControllerProvider,
          (_, _) {},
          fireImmediately: true,
        );
    addTearDown(subscription.close);

    final SessionController controller = container.read(
      sessionControllerProvider.notifier,
    );
    controller.opened();
    expect(
      container.read(sessionControllerProvider).selectedAction,
      SessionAction.lock,
    );

    controller.moveSelection(1);
    expect(
      container.read(sessionControllerProvider).selectedAction,
      SessionAction.logout,
    );

    controller.moveSelection(-1);
    expect(
      container.read(sessionControllerProvider).selectedAction,
      SessionAction.lock,
    );

    controller.select(SessionAction.shutdown);
    await container.pump();

    SessionLauncherState state = container.read(sessionControllerProvider);
    expect(state.confirmingAction, SessionAction.shutdown);
    expect(state.confirmChoice, SessionConfirmChoice.confirm);
    expect(state.errorMessage, isNull);

    controller.moveSelection(-1);
    state = container.read(sessionControllerProvider);
    expect(state.confirmChoice, SessionConfirmChoice.cancel);

    controller.activateSelection();
    state = container.read(sessionControllerProvider);
    expect(state.confirmingAction, isNull);
    expect(state.confirmChoice, SessionConfirmChoice.confirm);

    controller.select(SessionAction.shutdown);
    await container.pump();

    state = container.read(sessionControllerProvider);
    expect(state.confirmingAction, SessionAction.shutdown);
    expect(state.confirmChoice, SessionConfirmChoice.confirm);

    results.add(
      const SessionCommandResult(
        action: SessionAction.shutdown,
        outcome: SessionCommandOutcome.failed,
        message: 'No permission',
      ),
    );
    await container.pump();

    state = container.read(sessionControllerProvider);
    expect(state.isOpen, true);
    expect(state.confirmingAction, isNull);
    expect(state.errorMessage, 'No permission');

    results.add(
      const SessionCommandResult(
        action: SessionAction.shutdown,
        outcome: SessionCommandOutcome.started,
        message: null,
      ),
    );
    await container.pump();

    state = container.read(sessionControllerProvider);
    expect(state.isOpen, false);
    expect(state.closeSerial, 1);
  });

  test('launcher controller owns selection and launch result state', () async {
    final StreamController<AppLaunchResult> launches =
        StreamController<AppLaunchResult>();
    addTearDown(launches.close);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        appLaunchResultProvider.overrideWith((ref) => launches.stream),
      ],
    );
    addTearDown(container.dispose);
    final ProviderSubscription<LauncherViewState> subscription = container
        .listen<LauncherViewState>(
          launcherControllerProvider,
          (_, _) {},
          fireImmediately: true,
        );
    addTearDown(subscription.close);

    final LauncherController controller = container.read(
      launcherControllerProvider.notifier,
    );
    controller.moveSelection(1, 2);
    expect(container.read(launcherControllerProvider).selectedIndex, 1);

    final AppLauncherEntry entry = _appEntry();
    controller.launch(entry);
    expect(container.read(launcherControllerProvider).lastLaunchId, entry.id);

    launches.add(
      AppLaunchResult(
        id: entry.id,
        outcome: AppLaunchOutcome.failed,
        message: 'No executable',
      ),
    );
    await container.pump();

    LauncherViewState state = container.read(launcherControllerProvider);
    expect(state.errorMessage, 'No executable');
    expect(state.closeSerial, 0);

    launches.add(
      AppLaunchResult(id: entry.id, outcome: AppLaunchOutcome.started),
    );
    await container.pump();

    state = container.read(launcherControllerProvider);
    expect(state.errorMessage, isNull);
    expect(state.lastLaunchId, isNull);
    expect(state.closeSerial, 1);
  });

  testWidgets('typography sizes snap for common Hyprland scales', (_) async {
    expect(HyprTypography.sizeForScale(12.5, 1.0), 13);
    expect(HyprTypography.sizeForScale(11.5, 1.0), 12);
    expect(HyprTypography.sizeForScale(12.5, 1.2), 12.5);
    expect(HyprTypography.sizeForScale(11.5, 1.2), closeTo(11.667, 0.001));
  });

  testWidgets('glyph badge owns initials and deterministic color', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: HyprGlyphBadge(name: 'JetBrains Toolbox', dimension: 24),
        ),
      ),
    );

    expect(find.text('JT'), findsOneWidget);
    expect(
      HyprGlyphBadge.colorFor('JetBrains Toolbox'),
      HyprGlyphBadge.colorFor('JetBrains Toolbox'),
    );
    expect(
      HyprGlyphBadge.initialsFor('org.gnome.Nautilus', maxCharacters: 1),
      'O',
    );
  });

  test('live value gates repeated commits and force-commits final values', () {
    final HyprLiveValue value = HyprLiveValue(
      initialValue: 50,
      commitInterval: const Duration(seconds: 1),
    );

    value.begin();
    expect(value.preview(60), 60);
    expect(value.commit(force: true), 60);
    expect(value.preview(70), 70);
    expect(value.commit(), isNull);
    expect(value.commit(force: true), 70);
    expect(value.end(), 70);
    expect(value.active, isFalse);
  });

  testWidgets('bar renders base UI scaffold', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: Hyprbaric()));

    expect(find.text('Hyprbaric'), findsWidgets);
    expect(find.text('Menu'), findsNothing);
    expect(find.textContaining('Rust'), findsNothing);
  });

  testWidgets('popover surface keeps the border ring inside its bounds', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: HyprSurface(
            borderRadius: BorderRadius.circular(14),
            borderColor: HyprColors.popupStroke,
            frame: HyprSurfaceFrame.popover,
            child: const SizedBox(width: 120, height: 80),
          ),
        ),
      ),
    );

    final Iterable<ShapeDecoration> outerDecorations = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((DecoratedBox box) => box.decoration)
        .whereType<ShapeDecoration>();

    expect(
      outerDecorations.any(
        (ShapeDecoration decoration) =>
            decoration.shadows?.contains(
              const BoxShadow(
                color: HyprColors.popupOuterRing,
                blurRadius: 0,
                spreadRadius: 1,
              ),
            ) ??
            false,
      ),
      false,
    );
    expect(find.byType(CustomPaint), findsOneWidget);
  });

  testWidgets('bar renders workspace indicators as Roman numerals', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceStatusProvider.overrideWith(
            (ref) => Stream.value(
              const WorkspaceStatus(
                id: 2,
                name: '2',
                isSpecial: false,
                occupiedWorkspaceIds: <int>[],
                monitors: <MonitorWorkspaceStatus>[],
              ),
            ),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pump();

    expect(find.text('I'), findsOneWidget);
    expect(find.text('II'), findsOneWidget);
    expect(find.text('VII'), findsOneWidget);
    expect(find.text('1 term'), findsNothing);
  });

  testWidgets('left cluster renders launcher logo and workspace strip', (
    WidgetTester tester,
  ) async {
    var launcherToggled = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceStatusProvider.overrideWith(
            (ref) => Stream.value(
              const WorkspaceStatus(
                id: 2,
                name: '2',
                isSpecial: false,
                occupiedWorkspaceIds: <int>[],
                monitors: <MonitorWorkspaceStatus>[],
              ),
            ),
          ),
        ],
        child: _scopedSurface(
          child: SizedBox(
            width: 360,
            height: 40,
            child: LeftCluster(
              appLauncherOpen: true,
              onToggleAppLauncher: () => launcherToggled = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('hyprbaric-logo-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('workspace-strip')),
      findsOneWidget,
    );
    expect(find.text('II'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Open app launcher'));
    await tester.pump();

    expect(launcherToggled, true);
  });

  testWidgets('center cluster renders focused title only', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusedWindowStatusProvider.overrideWith(
            (ref) => Stream.value(
              const FocusedWindowStatus(
                appName: 'Zed',
                title: 'bar.tsx',
                hostname: 'workstation',
                monitors: <MonitorFocusedWindowStatus>[],
              ),
            ),
          ),
        ],
        child: _scopedSurface(
          child: const SizedBox(
            width: 520,
            height: 40,
            child: CenterCluster(maxWidth: 500),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Zed'), findsOneWidget);
    expect(find.text('bar.tsx'), findsOneWidget);
  });

  testWidgets('right cluster renders tray and managed utility anchors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trayStatusProvider.overrideWith((ref) => Stream.value(_trayStatus())),
          notificationStatusProvider.overrideWith(
            (ref) => Stream.value(_notificationStatus()),
          ),
          clockStatusProvider.overrideWith(
            (ref) => Stream.value(_clockStatus()),
          ),
          powerStatusProvider.overrideWith(
            (ref) => Stream.value(_powerStatus()),
          ),
        ],
        child: _scopedSurface(
          child: SizedBox(
            width: 720,
            height: 40,
            child: RightCluster(
              showSystemTray: true,
              showNotifications: true,
              showAudioDisplay: true,
              networkController: LayerShellDropdownController(),
              audioController: LayerShellDropdownController(),
              powerController: LayerShellDropdownController(),
              controlsController: LayerShellDropdownController(),
              trayMenuController: LayerShellDropdownController(),
              notificationController: LayerShellDropdownController(),
              clockController: LayerShellDropdownController(),
              powerButtonAnchorKey: GlobalKey(),
              networkRadius: BorderRadius.circular(18),
              audioRadius: BorderRadius.circular(18),
              clockCardRadius: BorderRadius.circular(17),
              sessionLauncherOpen: false,
              onToggleNetwork: () {},
              onToggleAudio: () {},
              onTogglePower: () {},
              onToggleControls: () {},
              onToggleNotifications: () {},
              onToggleClock: () {},
              onToggleSessionLauncher: () {},
              onSetNetworkWifiEnabled: (_) {},
              onConnectNetwork: (_, _) {},
              onOpenNetworkSettings: () {},
              onSetAudioVolume: (_, _) {},
              onSetAudioMuted: (_, {required bool muted}) {},
              onSetBrightness: (_) {},
              onOpenAudioMixer: () {},
              onSetPowerProfile: (_) {},
              onCaptureScreenshot: (_) {},
              onPickColor: () {},
              onToggleRecording: () {},
              onOpenSettings: () {},
              onControlToast: (_) {},
              onActivateTrayItem: (_, _) {},
              onOpenTrayContextMenu: (_, _) {},
              onActivateTrayMenuItem: (_, _) {},
              onDismissNotification: (_) {},
              onClearNotifications: () {},
              onSetDoNotDisturb: (_) {},
              onSetNightLight: (_) {},
              onSetCaffeine: (_) {},
              onClockCommand: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('tray-strip')), findsOneWidget);
    expect(find.bySemanticsLabel('Network'), findsOneWidget);
    expect(find.bySemanticsLabel('Audio and display controls'), findsOneWidget);
    expect(find.text('72%'), findsOneWidget);
    expect(find.bySemanticsLabel('Notifications, 2 unread'), findsOneWidget);
    expect(find.text('22:58'), findsOneWidget);
    expect(find.bySemanticsLabel('Session actions'), findsOneWidget);
    _expectStrokedIconsaxGlyph(tester, Iconsax.link_copy);
    _expectStrokedIconsaxGlyph(tester, Iconsax.notification_bing_copy);
  });

  testWidgets(
    'battery chip uses flash glyph instead of profile text on desktop',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _scopedSurface(
          child: BatteryChip(
            status: _desktopPowerStatus(),
            isOpen: false,
            onPressed: () {},
          ),
        ),
      );

      expect(find.text('SAV'), findsNothing);
      expect(find.text('BAL'), findsNothing);
      expect(find.text('PRF'), findsNothing);
      _expectStrokedIconsaxGlyph(tester, Iconsax.flash_circle_copy);
    },
  );

  testWidgets('workspace strip keeps a stable width while active changes', (
    WidgetTester tester,
  ) async {
    final StreamController<WorkspaceStatus> workspaces =
        StreamController<WorkspaceStatus>();
    addTearDown(workspaces.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceStatusProvider.overrideWith((ref) => workspaces.stream),
        ],
        child: const Hyprbaric(),
      ),
    );
    workspaces.add(
      const WorkspaceStatus(
        id: 2,
        name: '2',
        isSpecial: false,
        occupiedWorkspaceIds: <int>[],
        monitors: <MonitorWorkspaceStatus>[],
      ),
    );
    await tester.pumpAndSettle();

    final Finder strip = find.byKey(const ValueKey<String>('workspace-strip'));
    final double widthBefore = tester.getRect(strip).width;

    workspaces.add(
      const WorkspaceStatus(
        id: 3,
        name: '3',
        isSpecial: false,
        occupiedWorkspaceIds: <int>[],
        monitors: <MonitorWorkspaceStatus>[],
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));
    final double widthDuring = tester.getRect(strip).width;
    await tester.pumpAndSettle();
    final double widthAfter = tester.getRect(strip).width;

    expect(widthDuring, moreOrLessEquals(widthBefore));
    expect(widthAfter, moreOrLessEquals(widthBefore));
  });

  testWidgets('workspace strip keeps Roman continuity past VII', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceStatusProvider.overrideWith(
            (ref) => Stream.value(
              const WorkspaceStatus(
                id: 8,
                name: '8',
                isSpecial: false,
                occupiedWorkspaceIds: <int>[],
                monitors: <MonitorWorkspaceStatus>[],
              ),
            ),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pump();

    expect(find.text('V'), findsOneWidget);
    expect(find.text('VIII'), findsOneWidget);
    expect(find.text('XI'), findsOneWidget);
    expect(find.text('I'), findsNothing);
  });

  testWidgets('workspace strip can render numeric indicators', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceStatusProvider.overrideWith(
            (ref) => Stream.value(
              const WorkspaceStatus(
                id: 2,
                name: '2',
                isSpecial: false,
                occupiedWorkspaceIds: <int>[],
                monitors: <MonitorWorkspaceStatus>[],
              ),
            ),
          ),
          workspaceSettingsStatusProvider.overrideWith(
            (ref) => Stream.value(
              const WorkspaceSettingsStatus(
                indicatorStyle: WorkspaceIndicatorStyle.numeric,
                clickable: true,
                visibleRange: WorkspaceVisibleRange.medium,
                visibleCount: 7,
              ),
            ),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pump();

    final Finder strip = find.byKey(const ValueKey<String>('workspace-strip'));

    expect(
      find.descendant(of: strip, matching: find.text('1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: strip, matching: find.text('2')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: strip, matching: find.text('VII')),
      findsNothing,
    );
  });

  testWidgets('workspace visible range follows settings presets', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceStatusProvider.overrideWith(
            (ref) => Stream.value(
              const WorkspaceStatus(
                id: 3,
                name: '3',
                isSpecial: false,
                occupiedWorkspaceIds: <int>[],
                monitors: <MonitorWorkspaceStatus>[],
              ),
            ),
          ),
          workspaceSettingsStatusProvider.overrideWith(
            (ref) => Stream.value(
              const WorkspaceSettingsStatus(
                indicatorStyle: WorkspaceIndicatorStyle.numeric,
                clickable: true,
                visibleRange: WorkspaceVisibleRange.small,
                visibleCount: 5,
              ),
            ),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('workspace-indicator-5')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('workspace-indicator-6')),
      findsNothing,
    );
  });

  testWidgets('disabled workspace clicks keep arrows active', (
    WidgetTester tester,
  ) async {
    final _RecordingRustDispatcher dispatcher = _RecordingRustDispatcher();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rustCommandDispatcherProvider.overrideWith((ref) => dispatcher),
          workspaceStatusProvider.overrideWith(
            (ref) => Stream.value(
              const WorkspaceStatus(
                id: 2,
                name: '2',
                isSpecial: false,
                occupiedWorkspaceIds: <int>[],
                monitors: <MonitorWorkspaceStatus>[],
              ),
            ),
          ),
          workspaceSettingsStatusProvider.overrideWith(
            (ref) => Stream.value(
              const WorkspaceSettingsStatus(
                indicatorStyle: WorkspaceIndicatorStyle.numeric,
                clickable: false,
                visibleRange: WorkspaceVisibleRange.medium,
                visibleCount: 7,
              ),
            ),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-indicator-5')),
    );
    await tester.pump();

    expect(dispatcher.intents, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-nav-Previous workspace')),
    );
    await tester.pump();

    expect(
      dispatcher.intents.map((RustIntent intent) => intent.debugLabel),
      contains('workspace_delta:-1'),
    );
  });

  testWidgets('active workspace accents the symbol instead of the background', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceStatusProvider.overrideWith(
            (ref) => Stream.value(
              const WorkspaceStatus(
                id: 2,
                name: '2',
                isSpecial: false,
                occupiedWorkspaceIds: <int>[],
                monitors: <MonitorWorkspaceStatus>[],
              ),
            ),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pump();

    final Text activeLabel = tester.widget<Text>(find.text('II'));
    final AnimatedContainer activePlate = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text('II'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final ShapeDecoration decoration =
        activePlate.decoration! as ShapeDecoration;
    final HyprPalette palette = tester.element(find.text('II')).hyprPalette;

    expect(activeLabel.style?.color, palette.accentSoft);
    expect(decoration.color, isNot(HyprColors.accent));
  });

  testWidgets('workspace navigation controls are symmetric and faint', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceStatusProvider.overrideWith(
            (ref) => Stream.value(
              const WorkspaceStatus(
                id: 2,
                name: '2',
                isSpecial: false,
                occupiedWorkspaceIds: <int>[],
                monitors: <MonitorWorkspaceStatus>[],
              ),
            ),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pump();

    final IconButton previous = tester.widget<IconButton>(
      find.byKey(const ValueKey<String>('workspace-nav-Previous workspace')),
    );
    final IconButton next = tester.widget<IconButton>(
      find.byKey(const ValueKey<String>('workspace-nav-Next workspace')),
    );

    expect((previous.icon as Icon).icon, Icons.chevron_left_rounded);
    expect((next.icon as Icon).icon, Icons.chevron_right_rounded);
    expect(
      previous.style?.fixedSize?.resolve(<WidgetState>{}),
      const Size(28, 28),
    );
    expect(next.style?.fixedSize?.resolve(<WidgetState>{}), const Size(28, 28));
    expect(
      previous.style?.foregroundColor?.resolve(<WidgetState>{}),
      HyprColors.textFaint,
    );
    expect(
      next.style?.foregroundColor?.resolve(<WidgetState>{}),
      HyprColors.textFaint,
    );
  });

  testWidgets('workspace strip groups arrows and indicators without dividers', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceStatusProvider.overrideWith(
            (ref) => Stream.value(
              const WorkspaceStatus(
                id: 2,
                name: '2',
                isSpecial: false,
                occupiedWorkspaceIds: <int>[],
                monitors: <MonitorWorkspaceStatus>[],
              ),
            ),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pump();

    final Finder strip = find.byKey(const ValueKey<String>('workspace-strip'));

    expect(
      find.descendant(of: strip, matching: find.byType(HyprDivider)),
      findsNothing,
    );
  });

  testWidgets('workspace indicators send absolute workspace targets', (
    WidgetTester tester,
  ) async {
    final WorkspaceSwitch command = const WorkspaceSwitch(
      kind: WorkspaceSwitchKind.absolute,
      value: 5,
    );

    expect(
      WorkspaceSwitch.bincodeDeserialize(command.bincodeSerialize()),
      command,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceStatusProvider.overrideWith(
            (ref) => Stream.value(
              const WorkspaceStatus(
                id: 2,
                name: '2',
                isSpecial: false,
                occupiedWorkspaceIds: <int>[],
                monitors: <MonitorWorkspaceStatus>[],
              ),
            ),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-indicator-5')),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('clock renders HTML-style date button and calendar popup', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockStatusProvider.overrideWith(
            (ref) => Stream.value(_clockStatus()),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pump();

    final Finder timeFinder = find.text('22:58');
    final Text timeText = tester.widget<Text>(timeFinder);
    final Text dateText = tester.widget<Text>(find.text('Wed, Apr 22'));
    expect(timeFinder, findsOneWidget);
    expect(find.text('Wed, Apr 22'), findsOneWidget);
    expect(timeText.style?.fontFamily, HyprTypography.monoFamily);
    expect(timeText.style?.fontSize, HyprTypography.size(13));
    expect(timeText.style?.fontWeight, FontWeight.w600);
    expect(timeText.style?.letterSpacing, 0.13);
    expect(timeText.style?.height, 1);
    expect(dateText.style?.fontFamily, HyprTypography.uiFamily);
    expect(dateText.style?.fontSize, HyprTypography.size(12));
    expect(dateText.style?.fontWeight, FontWeight.w500);
    expect(dateText.style?.color, const Color(0xB8AAB4BD));
    expect(dateText.style?.height, 1);
    expect(
      tester.getTopLeft(find.text('Wed, Apr 22')).dx,
      lessThan(tester.getTopLeft(timeFinder).dx),
    );
    expect(find.byIcon(Icons.schedule_rounded), findsNothing);

    await tester.tap(timeFinder);
    await tester.pumpAndSettle();

    expect(find.text('April 2026'), findsOneWidget);
    expect(find.text('Week '), findsNothing);
    expect(find.textContaining('Week'), findsOneWidget);
    expect(find.text('UTC+02:00'), findsOneWidget);
  });

  testWidgets('open clock popup reflects live calendar updates', (
    WidgetTester tester,
  ) async {
    final StreamController<ClockStatus> clock = StreamController<ClockStatus>();
    addTearDown(clock.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [clockStatusProvider.overrideWith((ref) => clock.stream)],
        child: const Hyprbaric(),
      ),
    );

    clock.add(_clockStatus());
    await tester.pump();

    await tester.tap(find.text('22:58'));
    await tester.pumpAndSettle();

    expect(find.text('April 2026'), findsOneWidget);

    clock.add(_clockStatus(monthLabel: 'May 2026'));
    await tester.pumpAndSettle();

    expect(find.text('April 2026'), findsNothing);
    expect(find.text('May 2026'), findsOneWidget);
  });

  testWidgets('bar prefers the focused window title in the center slot', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusedWindowStatusProvider.overrideWith(
            (ref) => Stream.value(
              const FocusedWindowStatus(
                title: 'Neovim - hyprbaric',
                hostname: 'workstation',
                monitors: <MonitorFocusedWindowStatus>[],
              ),
            ),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pump();

    expect(find.text('Neovim - hyprbaric'), findsOneWidget);
    expect(find.text('workstation'), findsNothing);
  });

  testWidgets('bar splits focused app name from the active title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusedWindowStatusProvider.overrideWith(
            (ref) => Stream.value(
              const FocusedWindowStatus(
                appName: 'Zed',
                title: 'bar.tsx',
                hostname: 'workstation',
                monitors: <MonitorFocusedWindowStatus>[],
              ),
            ),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pump();

    expect(find.text('Zed'), findsOneWidget);
    expect(find.text('ZE'), findsOneWidget);
    expect(find.text('bar.tsx'), findsOneWidget);
    expect(find.text('workstation'), findsNothing);
  });

  testWidgets('bar normalizes focused app name casing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusedWindowStatusProvider.overrideWith(
            (ref) => Stream.value(
              const FocusedWindowStatus(
                appName: 'firefox',
                title: 'ChatGPT',
                hostname: 'workstation',
                monitors: <MonitorFocusedWindowStatus>[],
              ),
            ),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pump();

    expect(find.text('Firefox'), findsOneWidget);
    expect(find.text('firefox'), findsNothing);
    expect(find.text('ChatGPT'), findsOneWidget);
  });

  testWidgets('bar keeps the app badge when title duplicates the app label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusedWindowStatusProvider.overrideWith(
            (ref) => Stream.value(
              const FocusedWindowStatus(
                appName: 'alacritty',
                title: 'Alacritty',
                hostname: 'workstation',
                monitors: <MonitorFocusedWindowStatus>[],
              ),
            ),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pump();

    expect(find.text('Alacritty'), findsOneWidget);
    expect(find.text('AL'), findsOneWidget);
    expect(find.text('workstation'), findsNothing);
  });

  testWidgets('bar prefers an app label over hostname when title is empty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusedWindowStatusProvider.overrideWith(
            (ref) => Stream.value(
              const FocusedWindowStatus(
                appName: 'foot',
                title: null,
                hostname: 'workstation',
                monitors: <MonitorFocusedWindowStatus>[],
              ),
            ),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pump();

    expect(find.text('Foot'), findsOneWidget);
    expect(find.text('FO'), findsOneWidget);
    expect(find.text('workstation'), findsNothing);
  });

  testWidgets('bar renders no title on an empty desktop screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusedWindowStatusProvider.overrideWith(
            (ref) => Stream.value(
              const FocusedWindowStatus(
                appName: 'desktop',
                title: null,
                hostname: 'workstation',
                monitors: <MonitorFocusedWindowStatus>[],
              ),
            ),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pump();

    expect(find.text('Hyprbaric'), findsNothing);
    expect(find.text('Desktop'), findsNothing);
    expect(find.text('DE'), findsNothing);
    expect(find.text('workstation'), findsNothing);
  });

  testWidgets('bar renders no title for a desktop title sentinel', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusedWindowStatusProvider.overrideWith(
            (ref) => Stream.value(
              const FocusedWindowStatus(
                appName: 'hyprland',
                title: 'desktop',
                hostname: 'workstation',
                monitors: <MonitorFocusedWindowStatus>[],
              ),
            ),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pump();

    expect(find.text('Hyprbaric'), findsNothing);
    expect(find.text('desktop'), findsNothing);
    expect(find.text('workstation'), findsNothing);
  });

  testWidgets('bar renders no title for a desktop hostname fallback', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusedWindowStatusProvider.overrideWith(
            (ref) => Stream.value(
              const FocusedWindowStatus(
                title: null,
                hostname: 'desktop',
                monitors: <MonitorFocusedWindowStatus>[],
              ),
            ),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pump();

    expect(find.text('Hyprbaric'), findsNothing);
    expect(find.text('desktop'), findsNothing);
  });

  testWidgets('bar derives app labels without app-specific aliases', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusedWindowStatusProvider.overrideWith(
            (ref) => Stream.value(
              const FocusedWindowStatus(
                appName: 'org.example.some-browser.desktop',
                title: 'Example',
                hostname: 'workstation',
                monitors: <MonitorFocusedWindowStatus>[],
              ),
            ),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pump();

    expect(find.text('Some Browser'), findsOneWidget);
    expect(find.text('org.example.some-browser.desktop'), findsNothing);
    expect(find.text('Example'), findsOneWidget);
  });

  testWidgets('bar falls back to the hostname when no title is focused', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusedWindowStatusProvider.overrideWith(
            (ref) => Stream.value(
              const FocusedWindowStatus(
                title: null,
                hostname: 'workstation',
                monitors: <MonitorFocusedWindowStatus>[],
              ),
            ),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pump();

    expect(find.text('workstation'), findsOneWidget);
  });

  testWidgets('power button opens the session launcher', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: Hyprbaric()));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('session-actions-button')),
      findsOneWidget,
    );
    expect(find.text('Lock'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('session-actions-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Lock'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    expect(find.text('Reboot'), findsOneWidget);
    expect(find.text('Shutdown'), findsOneWidget);
    expect(find.text('Suspend'), findsNothing);
    expect(find.text('Reboot to Firmware'), findsNothing);
  });

  testWidgets('settings modal closes without disposed ref access', (
    WidgetTester tester,
  ) async {
    _setRegionMock((Object? message) => _pigeonSuccess());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStatusProvider.overrideWith(
            (ref) => Stream.value(const AppStatus(version: '9.8.7')),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    _expectStrokedIconsaxGlyph(tester, Iconsax.setting_5_copy);

    await tester.tap(find.bySemanticsLabel('Controls'));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('BAR SETTINGS'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsWidgets);
    expect(find.text('v9.8.7'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('settings hands input to a manually launched setup guide', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final List<Map<String, Object?>> regionRequests = <Map<String, Object?>>[];
    _setRegionMock((Object? message) {
      regionRequests.add(_regionPayloadFromMessage(message));
      return _pigeonSuccess();
    });
    final List<String> keyboardModes = <String>[];
    _setKeyboardModeMock((Object? message) {
      final List<Object?> arguments = message! as List<Object?>;
      keyboardModes.add(
        (arguments.single! as NativeLayerShellKeyboardMode).name,
      );
      return _pigeonSuccess();
    });
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      debugDefaultTargetPlatformOverride = null;
      LayerShellController.debugResetKeyboardOwners();
      _setRegionMock(null);
      _setKeyboardModeMock(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          setupGuideAutomaticHostProvider.overrideWithValue(false),
          setupStatusProvider.overrideWith(
            (_) => Stream<SetupStatus>.value(
              const SetupStatus(state: SetupState.complete),
            ),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Controls'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BAR SETTINGS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('run-setup-guide')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(find.text('GET STARTED'), findsOneWidget);
    await tester.tap(find.text('GET STARTED'));
    await tester.pumpAndSettle();

    expect(find.text('Frosted, or flat?'), findsOneWidget);
    // The settings modal closes underneath the guide. Its teardown must not
    // release the guide's still-open keyboard claim.
    expect(keyboardModes, isNotEmpty);
    expect(
      keyboardModes,
      everyElement(NativeLayerShellKeyboardMode.exclusive.name),
    );
    final List<Object?> regions =
        regionRequests.last['regions']! as List<Object?>;
    expect(regions, hasLength(1));
    final Map<String, Object?> guideRegion =
        regions.single! as Map<String, Object?>;
    expect(guideRegion['x'], 0);
    expect(guideRegion['y'], 0);
    expect(guideRegion['w']! as int, greaterThan(40));
    expect(guideRegion['h']! as int, greaterThan(40));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('settings content switches tabs and renders version footer', (
    WidgetTester tester,
  ) async {
    SettingsTab activeTab = SettingsTab.appearance;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStatusProvider.overrideWith(
            (ref) => Stream.value(const AppStatus(version: '1.2.3')),
          ),
          shortcutSettingsSnapshotProvider.overrideWith(
            (ref) => Stream.value(_shortcutSettingsSnapshot()),
          ),
        ],
        child: _scopedSurface(
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SettingsOverlayContent(
                tab: activeTab,
                onTabChanged: (SettingsTab tab) {
                  setState(() => activeTab = tab);
                },
                onClose: () {},
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final SizedBox settingsContent = tester.widget<SizedBox>(
      find.byKey(SettingsOverlayLayout.contentKey),
    );
    expect(settingsContent.width, SettingsOverlayLayout.width);
    expect(settingsContent.height, SettingsOverlayLayout.height);
    expect(find.text('Appearance'), findsWidgets);
    expect(find.text('v1.2.3'), findsOneWidget);
    expect(find.text('Position'), findsOneWidget);

    await tester.tap(find.text('Keybinds').first);
    await tester.pump();
    await tester.pump();

    expect(find.text('App launcher'), findsOneWidget);
    expect(find.text('Super'), findsOneWidget);

    await tester.tap(find.text('About').first);
    await tester.pump();

    expect(find.text('Hyprbaric'), findsOneWidget);
    expect(
      find.text('Flutter bar for Hyprland with a Rust runtime.'),
      findsOneWidget,
    );
  });

  testWidgets('modules settings renders persisted visibility toggles', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          modulesStatusProvider.overrideWith(
            (ref) => Stream.value(
              const ModulesStatus(
                entries: <ModuleEntry>[
                  ModuleEntry(
                    module: ModuleId.activeWindowTitle,
                    enabled: true,
                  ),
                  ModuleEntry(module: ModuleId.systemTray, enabled: false),
                  ModuleEntry(module: ModuleId.notifications, enabled: true),
                  ModuleEntry(module: ModuleId.audioDisplay, enabled: true),
                ],
              ),
            ),
          ),
        ],
        child: _scopedSurface(
          child: SettingsOverlayContent(
            tab: SettingsTab.modules,
            onTabChanged: (_) {},
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Modules'), findsWidgets);
    expect(find.text('Active window title'), findsOneWidget);
    expect(find.text('System tray'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Audio & Display'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('On'), findsNWidgets(3));
  });

  testWidgets('workspaces settings dispatches style range and clickability', (
    WidgetTester tester,
  ) async {
    final _RecordingRustDispatcher dispatcher = _RecordingRustDispatcher();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rustCommandDispatcherProvider.overrideWith((ref) => dispatcher),
          workspaceSettingsStatusProvider.overrideWith(
            (ref) => Stream.value(defaultWorkspaceSettingsStatus),
          ),
        ],
        child: _scopedSurface(
          child: SettingsOverlayContent(
            tab: SettingsTab.workspaces,
            onTabChanged: (_) {},
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Workspaces'), findsWidgets);
    expect(find.text('Indicator style'), findsOneWidget);
    expect(find.text('Clickable workspaces'), findsOneWidget);
    expect(find.text('Visible range'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);

    await tester.tap(find.text('Numeric'));
    await tester.pump();
    await tester.tap(find.text('Small'));
    await tester.pump();
    await tester.tap(find.text('Clickable workspaces'));
    await tester.pump();

    expect(
      dispatcher.intents.map((RustIntent intent) => intent.debugLabel),
      containsAll(<String>[
        'workspace_indicator_style:numeric',
        'workspace_visible_range:small',
        'workspace_clickable:false',
      ]),
    );
  });

  testWidgets('display settings sends night-light temperature updates', (
    WidgetTester tester,
  ) async {
    final _RecordingRustDispatcher dispatcher = _RecordingRustDispatcher();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStatusProvider.overrideWith(
            (ref) => Stream.value(const AppStatus(version: '1.2.3')),
          ),
          nightLightStatusProvider.overrideWith(
            (ref) => Stream.value(
              const NightLightStatusAvailable(
                enabled: false,
                temperature: 3500,
              ),
            ),
          ),
          scheduleStatusProvider.overrideWith(
            (ref) => Stream.value(
              const ScheduleStatus(
                entries: <ScheduleEntry>[
                  ScheduleEntry(
                    action: ScheduleAction.nightLight,
                    enabled: false,
                    startHour: 21,
                    stopHour: 7,
                  ),
                ],
              ),
            ),
          ),
          rustCommandDispatcherProvider.overrideWith((ref) => dispatcher),
        ],
        child: _scopedSurface(
          child: const SizedBox(
            width: 420,
            height: 240,
            child: NightLightSettingsPanel(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), '3000');
    await tester.tap(find.text('Apply'));
    await tester.pump();

    expect(find.text('Night light'), findsOneWidget);
    expect(
      dispatcher.intents.map((RustIntent intent) => intent.debugLabel),
      contains('night_light_temperature:3000'),
    );
  });

  testWidgets('appearance settings can restore defaults', (
    WidgetTester tester,
  ) async {
    final _RecordingRustDispatcher dispatcher = _RecordingRustDispatcher();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appearanceStatusProvider.overrideWith(
            (ref) => Stream.value(
              const AppearanceStatus(
                position: AppearancePosition.bottom,
                monitor: AppearanceMonitorTargetPrimary(),
                opacity: 42,
                cornerRadius: 4,
                accentHue: 300,
              ),
            ),
          ),
          rustCommandDispatcherProvider.overrideWith((ref) => dispatcher),
        ],
        child: _scopedSurface(
          child: const SizedBox(
            width: 420,
            height: 360,
            child: AppearanceSettingsPanel(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Restore defaults'),
      120,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Restore defaults'));
    await tester.pump();

    expect(
      dispatcher.intents.map((RustIntent intent) => intent.debugLabel),
      contains('appearance_restore_defaults'),
    );
  });

  testWidgets('display settings sends night-light schedule updates', (
    WidgetTester tester,
  ) async {
    final _RecordingRustDispatcher dispatcher = _RecordingRustDispatcher();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nightLightStatusProvider.overrideWith(
            (ref) => Stream.value(
              const NightLightStatusAvailable(
                enabled: false,
                temperature: 3500,
              ),
            ),
          ),
          scheduleStatusProvider.overrideWith(
            (ref) => Stream.value(
              const ScheduleStatus(
                entries: <ScheduleEntry>[
                  ScheduleEntry(
                    action: ScheduleAction.nightLight,
                    enabled: false,
                    startHour: 21,
                    stopHour: 7,
                  ),
                ],
              ),
            ),
          ),
          rustCommandDispatcherProvider.overrideWith((ref) => dispatcher),
        ],
        child: _scopedSurface(
          child: const SizedBox(
            width: 420,
            height: 340,
            child: NightLightSettingsPanel(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('night-light-schedule-toggle')),
    );
    await tester.pump();

    expect(find.text('Schedule'), findsOneWidget);
    expect(
      dispatcher.intents.map((RustIntent intent) => intent.debugLabel),
      contains('schedule_daily_window:nightLight:true:21:7'),
    );
  });

  testWidgets(
    'display settings stay editable when night light is unavailable',
    (WidgetTester tester) async {
      final _RecordingRustDispatcher dispatcher = _RecordingRustDispatcher();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nightLightStatusProvider.overrideWith(
              (ref) => Stream.value(
                const NightLightStatusUnavailable(
                  enabled: false,
                  temperature: 3500,
                  message: 'hyprsunset unavailable',
                ),
              ),
            ),
            scheduleStatusProvider.overrideWith(
              (ref) => Stream.value(
                const ScheduleStatus(
                  entries: <ScheduleEntry>[
                    ScheduleEntry(
                      action: ScheduleAction.nightLight,
                      enabled: false,
                      startHour: 21,
                      stopHour: 7,
                    ),
                  ],
                ),
              ),
            ),
            rustCommandDispatcherProvider.overrideWith((ref) => dispatcher),
          ],
          child: _scopedSurface(
            child: const SizedBox(
              width: 420,
              height: 340,
              child: NightLightSettingsPanel(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.enterText(find.byType(TextField), '3000');
      await tester.tap(find.text('Apply'));
      await tester.tap(
        find.byKey(const ValueKey<String>('night-light-schedule-toggle')),
      );
      await tester.pump();

      final Iterable<String> labels = dispatcher.intents.map(
        (RustIntent intent) => intent.debugLabel,
      );
      expect(labels, contains('night_light_temperature:3000'));
      expect(labels, contains('schedule_daily_window:nightLight:true:21:7'));
    },
  );

  testWidgets('settings content close button invokes callback', (
    WidgetTester tester,
  ) async {
    var closed = false;

    await tester.pumpWidget(
      ProviderScope(
        child: _scopedSurface(
          child: SettingsOverlayContent(
            tab: SettingsTab.appearance,
            onTabChanged: (_) {},
            onClose: () => closed = true,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();

    expect(closed, true);
  });

  testWidgets('keybindings panel renders Rust snapshot rows and records keys', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutSettingsSnapshotProvider.overrideWith(
            (ref) => Stream.value(_shortcutSettingsSnapshot()),
          ),
        ],
        child: _scopedSurface(
          child: const SizedBox(
            width: 560,
            height: 420,
            child: KeybindingsPanel(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('App launcher'), findsOneWidget);
    expect(find.text('Lock session'), findsOneWidget);
    expect(find.text('Super'), findsOneWidget);
    expect(find.text('Disabled'), findsOneWidget);
    expect(
      find.text('Writing /home/example/.config/hyprbaric/config.toml'),
      findsOneWidget,
    );

    await tester.tap(find.text('Record').first);
    await tester.pump();

    expect(find.text('Press keys...'), findsOneWidget);
    expect(find.text('Press a new shortcut for App launcher'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.pump();

    expect(find.text('Press keys...'), findsNothing);
    expect(find.text('K'), findsOneWidget);
    expect(find.text('Saving shortcut...'), findsOneWidget);
  });

  testWidgets('keybindings panel does not clip the first row at rest', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutSettingsSnapshotProvider.overrideWith(
            (ref) => Stream.value(_shortcutSettingsSnapshot()),
          ),
        ],
        child: _scopedSurface(
          child: const SizedBox(
            width: 560,
            height: 420,
            child: KeybindingsPanel(),
          ),
        ),
      ),
    );
    await tester.pump();

    final Offset panelTopLeft = tester.getTopLeft(
      find.byType(KeybindingsPanel),
    );
    final Offset firstRowTopLeft = tester.getTopLeft(find.text('App launcher'));

    expect(firstRowTopLeft.dy, greaterThan(panelTopLeft.dy));
  });

  testWidgets('keybindings panel hides disable action for disabled rows', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutSettingsSnapshotProvider.overrideWith(
            (ref) => Stream.value(
              _shortcutSettingsSnapshot(appLauncherDisabled: true),
            ),
          ),
        ],
        child: _scopedSurface(
          child: const SizedBox(
            width: 560,
            height: 420,
            child: KeybindingsPanel(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Restore'), findsNWidgets(2));
    expect(find.text('Disable'), findsNothing);
  });

  testWidgets('keybindings panel shows and records the logo modifier', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutSettingsSnapshotProvider.overrideWith(
            (ref) => Stream.value(_shortcutSettingsSnapshot()),
          ),
        ],
        child: _scopedSurface(
          child: const SizedBox(
            width: 560,
            height: 420,
            child: KeybindingsPanel(),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Record').first);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    expect(find.text('LOGO+...'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.pump();

    expect(find.text('LOGO+K'), findsOneWidget);
    expect(find.text('Saving shortcut...'), findsOneWidget);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  });

  testWidgets(
    'keybindings panel does not replay stale saved results on entry',
    (WidgetTester tester) async {
      ShortcutSettingsCommandResult.latestRustSignal = RustSignalPack(
        const ShortcutSettingsCommandResult(
          command: ShortcutSettingsRequestLoad(),
          outcome: ShortcutSettingsCommandOutcome.saved,
        ),
        Uint8List(0),
      );
      addTearDown(() {
        ShortcutSettingsCommandResult.latestRustSignal = null;
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shortcutSettingsSnapshotProvider.overrideWith(
              (ref) => Stream.value(_shortcutSettingsSnapshot()),
            ),
          ],
          child: _scopedSurface(
            child: const SizedBox(
              width: 560,
              height: 420,
              child: KeybindingsPanel(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('App launcher'), findsOneWidget);
      expect(find.text('Shortcut settings saved'), findsNothing);
    },
  );

  testWidgets(
    'keybindings panel keeps disable visible across stale snapshots',
    (WidgetTester tester) async {
      final StreamController<ShortcutSettingsSnapshot> snapshots =
          StreamController<ShortcutSettingsSnapshot>();
      addTearDown(snapshots.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shortcutSettingsSnapshotProvider.overrideWith(
              (ref) => snapshots.stream,
            ),
          ],
          child: _scopedSurface(
            child: const SizedBox(
              width: 560,
              height: 420,
              child: KeybindingsPanel(),
            ),
          ),
        ),
      );

      snapshots.add(_shortcutSettingsSnapshot());
      await tester.pump();
      expect(find.text('Super'), findsOneWidget);

      await tester.tap(find.text('Disable').first);
      await tester.pump();

      expect(find.text('Super'), findsNothing);
      expect(find.text('Disabled'), findsNWidgets(2));

      snapshots.add(_shortcutSettingsSnapshot());
      await tester.pump();

      expect(find.text('Super'), findsNothing);
      expect(find.text('Disabled'), findsNWidgets(2));

      snapshots.add(_shortcutSettingsSnapshot(appLauncherDisabled: true));
      await tester.pump();

      expect(find.text('Super'), findsNothing);
      expect(find.text('Disabled'), findsNWidgets(2));
    },
  );

  testWidgets('settings rows render label subtitle and value badge', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _scopedSurface(
        child: const SizedBox(
          width: 420,
          height: 120,
          child: SettingsRows(
            rows: <SettingsRowData>[
              SettingsRowData('Opacity', 'Background transparency.', '55%'),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Opacity'), findsOneWidget);
    expect(find.text('Background transparency.'), findsOneWidget);
    expect(find.text('55%'), findsOneWidget);
  });

  testWidgets('external dropdown controller opens and closes menu', (
    WidgetTester tester,
  ) async {
    final LayerShellDropdownController controller =
        LayerShellDropdownController();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: LayerShellDropdown(
                controller: controller,
                buttonBuilder:
                    (
                      BuildContext context,
                      LayerShellDropdownController controller, {
                      required bool isOpen,
                    }) => const SizedBox(
                      width: 96,
                      height: 32,
                      child: Text('Toggle'),
                    ),
                menuBuilder:
                    (
                      BuildContext context,
                      LayerShellDropdownController controller,
                    ) => const Material(child: Text('Menu content')),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Toggle'), findsOneWidget);
    expect(find.text('Menu content'), findsNothing);

    controller.open();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Menu content'), findsOneWidget);

    controller.close();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Toggle'), findsOneWidget);
    expect(find.text('Menu content'), findsNothing);
  });

  testWidgets('dropdown can right-anchor the popup to the trigger button', (
    WidgetTester tester,
  ) async {
    final LayerShellDropdownController controller =
        LayerShellDropdownController();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 8),
                child: LayerShellDropdown(
                  controller: controller,
                  menuWidth: 220,
                  horizontalAnchor: LayerShellDropdownAnchor.right,
                  buttonBuilder:
                      (
                        BuildContext context,
                        LayerShellDropdownController controller, {
                        required bool isOpen,
                      }) => const SizedBox(
                        key: ValueKey<String>('edge-clamped-button'),
                        width: 28,
                        height: 28,
                        child: Text('B'),
                      ),
                  menuBuilder:
                      (
                        BuildContext context,
                        LayerShellDropdownController controller,
                      ) => Container(
                        key: const ValueKey<String>('edge-clamped-menu'),
                        width: 220,
                        height: 80,
                        color: Colors.black,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    controller.open();
    await tester.pump();
    await tester.pumpAndSettle();

    final Rect scaffoldRect = tester.getRect(find.byType(Scaffold));
    final Rect buttonRect = tester.getRect(
      find.byKey(const ValueKey<String>('edge-clamped-button')),
    );
    final Rect menuRect = tester.getRect(
      find.byKey(const ValueKey<String>('edge-clamped-menu')),
    );
    await tester.pump();
    final Rect settledMenuRect = tester.getRect(
      find.byKey(const ValueKey<String>('edge-clamped-menu')),
    );

    expect(menuRect.left, greaterThanOrEqualTo(0));
    expect(menuRect.right, lessThanOrEqualTo(scaffoldRect.right));
    expect(menuRect.top, math.max(buttonRect.bottom, 40) + 8);
    expect(settledMenuRect, equals(menuRect));
  });

  testWidgets('network popup opens and hands off cleanly to audio', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkStatusProvider.overrideWith(
            (ref) => Stream.value(_networkStatus()),
          ),
          audioStatusProvider.overrideWith(
            (ref) => Stream.value(_audioStatus()),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Network'), findsNothing);
    expect(find.bySemanticsLabel('Network'), findsOneWidget);
    _expectStrokedIconsaxGlyph(tester, Iconsax.link_copy);
    expect(find.text('Fiber_5G'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Network'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Fiber_5G'), findsOneWidget);
    expect(find.text('MIXER'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Audio and display controls'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('MIXER'), findsOneWidget);
    expect(find.text('Fiber_5G'), findsNothing);
  });

  testWidgets('network panel renders typed snapshot data directly', (
    WidgetTester tester,
  ) async {
    var openedSettings = false;

    await tester.pumpWidget(
      _scopedSurface(
        child: NetworkPanel(
          borderRadius: BorderRadius.circular(18),
          status: AsyncValue<NetworkStatus>.data(_networkStatus()),
          latestResult: null,
          onSetWifiEnabled: (_) {},
          onConnect: (_, _) {},
          onOpenSettings: () => openedSettings = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Fiber_5G'), findsOneWidget);
    expect(find.text('wlo1'), findsOneWidget);
    expect(find.text('192.168.1.42'), findsOneWidget);
    expect(find.text('Network settings…'), findsOneWidget);

    await tester.tap(find.text('Network settings…'));
    await tester.pump();

    expect(openedSettings, true);
  });

  testWidgets('open network popup reflects live network updates', (
    WidgetTester tester,
  ) async {
    final StreamController<NetworkStatus> network =
        StreamController<NetworkStatus>();
    addTearDown(network.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkStatusProvider.overrideWith((ref) => network.stream),
        ],
        child: const Hyprbaric(),
      ),
    );
    network.add(_networkStatus());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Network'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Fiber_5G'), findsOneWidget);
    expect(find.text('CoffeeShop'), findsNothing);

    network.add(_networkStatus(activeSsid: 'CoffeeShop'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('CoffeeShop'), findsOneWidget);
    expect(find.text('Fiber_5G'), findsNothing);
  });

  testWidgets(
    'network Wi-Fi toggle hides stale SSIDs while state is in flight',
    (WidgetTester tester) async {
      final StreamController<NetworkStatus> network =
          StreamController<NetworkStatus>();
      addTearDown(network.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkStatusProvider.overrideWith((ref) => network.stream),
          ],
          child: const Hyprbaric(),
        ),
      );
      network.add(_networkStatus());
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Network'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Fiber_5G'), findsOneWidget);
      expect(find.text('on'), findsOneWidget);

      await tester.tap(find.text('on'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('off'), findsOneWidget);
      expect(find.text('Wi-Fi is turned off.'), findsOneWidget);
      expect(find.text('Fiber_5G'), findsNothing);

      await tester.tap(find.text('off'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('on'), findsOneWidget);
    },
  );

  testWidgets(
    'network Wi-Fi toggle keeps newest target across delayed snapshots',
    (WidgetTester tester) async {
      final StreamController<NetworkStatus> network =
          StreamController<NetworkStatus>();
      final StreamController<NetworkCommandResult> results =
          StreamController<NetworkCommandResult>();
      addTearDown(network.close);
      addTearDown(results.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkStatusProvider.overrideWith((ref) => network.stream),
            networkCommandResultProvider.overrideWith((ref) => results.stream),
          ],
          child: const Hyprbaric(),
        ),
      );
      network.add(_networkStatus());
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Network'));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('on'));
      await tester.pump();
      await tester.tap(find.text('off'));
      await tester.pump();

      results.add(
        const NetworkCommandResultStarted(
          command: NetworkCommandSetWifiEnabled(enabled: false),
        ),
      );
      await tester.pump();
      network.add(_networkStatus(wifiEnabled: false).copyWith(networks: []));
      await tester.pumpAndSettle();

      expect(find.text('on'), findsOneWidget);
      expect(find.text('off'), findsNothing);
    },
  );

  testWidgets('network popup keeps interfaces visible with many SSIDs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkStatusProvider.overrideWith(
            (ref) => Stream.value(
              _networkStatus(
                extraNetworks: List<NetworkEntry>.generate(
                  16,
                  (int index) => NetworkEntry(
                    ssid: 'Neighbor_${index + 1}',
                    bssid: 'neighbor-${index + 1}',
                    strength: 50,
                    secure: true,
                    state: NetworkEntryState.available,
                  ),
                ),
              ),
            ),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Network'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('INTERFACES'), findsOneWidget);
    expect(find.text('wlo1'), findsOneWidget);
    expect(find.text('lo'), findsOneWidget);
  });

  testWidgets('audio popup renders output and input controls', (
    WidgetTester tester,
  ) async {
    final _RecordingRustDispatcher dispatcher = _RecordingRustDispatcher();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rustCommandDispatcherProvider.overrideWith((ref) => dispatcher),
          audioStatusProvider.overrideWith(
            (ref) => Stream.value(_audioStatus()),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MIXER'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('bar-volume-knob-icon')),
      findsOneWidget,
    );
    expect(_iconsaxGlyphFinder(Iconsax.volume_high_copy), findsNothing);
    expect(_iconsaxGlyphFinder(Iconsax.sun_1_copy), findsNothing);

    await tester.tap(find.bySemanticsLabel('Audio and display controls'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('MIXER'), findsOneWidget);
    expect(find.text('OUT'), findsOneWidget);
    expect(find.text('MIC'), findsNWidgets(2));
    expect(find.text('EVO4 Analog Surround 4.0'), findsOneWidget);
    expect(find.text('MASTER'), findsOneWidget);
    expect(find.text('PAVUCONTROL →'), findsOneWidget);
    expect(find.text('Built-in Mic'), findsOneWidget);
    expect(find.text('M'), findsNWidgets(2));
    expect(
      find.bySemanticsLabel('EVO4 Analog Surround 4.0 volume'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Built-in Mic volume'), findsOneWidget);
    expect(find.text('pipewire'), findsNothing);

    await tester.tap(find.text('PAVUCONTROL →'));
    await tester.pumpAndSettle();

    expect(
      dispatcher.intents.map((RustIntent intent) => intent.debugLabel),
      contains('app_launch:pavucontrol.desktop'),
    );
    expect(find.text('MIXER'), findsNothing);
  });

  testWidgets('audio panel renders mixer and brightness state directly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _scopedSurface(
        child: AudioPanel(
          borderRadius: BorderRadius.circular(18),
          status: AsyncValue<AudioStatus>.data(_audioStatus()),
          brightnessStatus: const AsyncValue<BrightnessStatus>.data(
            BrightnessStatusAvailable(device: 'eDP-1', value: 72),
          ),
          onSetVolume: (_, _) {},
          onSetMuted: (_, {required bool muted}) {},
          onSetBrightness: (_) {},
          onOpenMixer: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('MIXER'), findsOneWidget);
    expect(find.text('DISPLAY 72%'), findsOneWidget);
    expect(find.text('OUT'), findsOneWidget);
    expect(find.text('MIC'), findsNWidgets(2));
    expect(find.text('MASTER'), findsOneWidget);
    expect(find.text('PAVUCONTROL →'), findsOneWidget);
    expect(tester.getSize(find.byType(AudioPanel)).width, 336);
  });

  testWidgets('brightness control renders available and unavailable states', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _scopedSurface(
        child: BrightnessControl(
          status: const BrightnessStatusAvailable(device: 'eDP-1', value: 72),
          loading: false,
          onSetBrightness: (_) {},
        ),
      ),
    );
    await tester.pump();

    final Finder availableSemantics = find.byWidgetPredicate(
      (Widget widget) =>
          widget is Semantics && widget.properties.label == 'eDP-1 brightness',
    );
    expect(availableSemantics, findsOneWidget);
    Semantics semanticsWidget = tester.widget<Semantics>(availableSemantics);
    expect(semanticsWidget.properties.label, 'eDP-1 brightness');
    expect(semanticsWidget.properties.value, '72');
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text && widget.textSpan?.toPlainText() == '72%',
      ),
      findsOneWidget,
    );
    expect(find.text('BRIGHTNESS'), findsOneWidget);

    await tester.pumpWidget(
      _scopedSurface(
        child: BrightnessControl(
          status: const BrightnessStatusUnavailable(message: 'No displays'),
          loading: false,
          onSetBrightness: (_) {},
        ),
      ),
    );
    await tester.pump();

    final Finder unavailableSemantics = find.byWidgetPredicate(
      (Widget widget) =>
          widget is Semantics && widget.properties.label == 'No displays',
    );
    expect(unavailableSemantics, findsOneWidget);
    semanticsWidget = tester.widget<Semantics>(unavailableSemantics);
    expect(semanticsWidget.properties.label, 'No displays');
    expect(semanticsWidget.properties.value, '--');
    final Opacity opacity = tester.widget<Opacity>(find.byType(Opacity));
    expect(opacity.opacity, 0.45);
  });

  testWidgets('brightness knob dispatches drag changes and final value', (
    WidgetTester tester,
  ) async {
    final List<int> changed = <int>[];
    final List<int> ended = <int>[];

    await tester.pumpWidget(
      _scopedSurface(
        child: BrightnessKnob(
          value: 50,
          enabled: true,
          onChanged: changed.add,
          onChangeEnd: ended.add,
        ),
      ),
    );
    await tester.pump();

    await tester.drag(find.byType(BrightnessKnob), const Offset(0, -75));
    await tester.pump();

    expect(changed, isNotEmpty);
    expect(changed.last, greaterThan(50));
    expect(ended, isNotEmpty);
    expect(ended.last, changed.last);
  });

  testWidgets('brightness control presents a frame before committing effects', (
    WidgetTester tester,
  ) async {
    final List<int> committed = <int>[];

    await tester.pumpWidget(
      _scopedSurface(
        child: BrightnessControl(
          status: const BrightnessStatusAvailable(device: 'eDP-1', value: 50),
          loading: false,
          onSetBrightness: committed.add,
        ),
      ),
    );
    await tester.pump();

    final Offset center = tester.getCenter(find.byType(BrightnessKnob));
    await tester.sendEventToBinding(
      PointerScrollEvent(position: center, scrollDelta: const Offset(0, -10)),
    );

    expect(committed, isEmpty);

    await tester.pump();

    expect(committed, <int>[54]);
  });

  testWidgets('brightness knob painter repaints for visual state changes', (
    WidgetTester tester,
  ) async {
    const BrightnessKnobPainter painter = BrightnessKnobPainter(
      value: 0.42,
      enabled: true,
    );

    expect(
      painter.shouldRepaint(
        const BrightnessKnobPainter(value: 0.42, enabled: true),
      ),
      false,
    );
    expect(
      painter.shouldRepaint(
        const BrightnessKnobPainter(value: 0.43, enabled: true),
      ),
      true,
    );
    expect(
      painter.shouldRepaint(
        const BrightnessKnobPainter(value: 0.42, enabled: false),
      ),
      true,
    );
  });

  testWidgets('power panel renders battery profile state and dispatches pads', (
    WidgetTester tester,
  ) async {
    PowerProfile? selectedProfile;

    await tester.pumpWidget(
      _scopedSurface(
        child: PowerPanel(
          borderRadius: BorderRadius.circular(18),
          status: AsyncValue<PowerStatus>.data(_powerStatus()),
          latestResult: null,
          onSetProfile: (PowerProfile profile) => selectedProfile = profile,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('BATTERY'), findsOneWidget);
    expect(find.text('POWER PROFILE'), findsOneWidget);
    expect(find.text('CHARGE'), findsOneWidget);
    expect(find.text('REMAINING'), findsOneWidget);
    expect(find.text('-8.2W'), findsOneWidget);
    expect(find.text('BALANCED'), findsOneWidget);

    await tester.tap(find.text('SAVER'));
    await tester.pumpAndSettle();

    expect(selectedProfile, PowerProfile.saver);
  });

  testWidgets('audio fader updates volume while dragging', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioStatusProvider.overrideWith(
            (ref) => Stream.value(_audioStatus()),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Audio and display controls'));
    await tester.pump();
    await tester.pumpAndSettle();

    final Finder outputFader = find.bySemanticsLabel(
      'EVO4 Analog Surround 4.0 volume',
    );
    final Rect outputFaderRect = tester.getRect(outputFader);
    // Only the track takes drags; the level ladder beside it is a readout.
    // The panel renders scaled here, so place the drag proportionally.
    const double trackFraction =
        (AudioFaderMetrics.trackLeft + AudioFaderMetrics.trackWidth / 2) /
        AudioFaderMetrics.width;
    final double trackX =
        outputFaderRect.left + outputFaderRect.width * trackFraction;
    final TestGesture drag = await tester.startGesture(
      Offset(trackX, outputFaderRect.center.dy),
    );
    await drag.moveTo(Offset(trackX, outputFaderRect.top + 0.1));
    await tester.pump(const Duration(milliseconds: 90));

    expect(find.text('VOLUME'), findsOneWidget);
    expect(find.text('0.0 dB'), findsWidgets);

    await drag.up();
  });

  testWidgets('tray strip renders inline tray items from Rust state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trayStatusProvider.overrideWith((ref) => Stream.value(_trayStatus())),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('tray-strip')), findsOneWidget);
    expect(find.bySemanticsLabel('Dropbox'), findsOneWidget);
    expect(find.bySemanticsLabel('Spotify, Playing'), findsOneWidget);
  });

  testWidgets('tray strip routes primary and secondary clicks separately', (
    WidgetTester tester,
  ) async {
    String? primaryId;
    String? contextId;

    await tester.pumpWidget(
      _scopedSurface(
        child: TrayStrip(
          status: _trayStatus(),
          onActivate: (String id, Offset position) {
            primaryId = id;
          },
          onContextMenu: (String id, Offset position) {
            contextId = id;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Dropbox'));
    await tester.pump();

    expect(primaryId, 'org.example.Dropbox');
    expect(contextId, isNull);

    await tester.tap(
      find.bySemanticsLabel('Spotify, Playing'),
      buttons: kSecondaryMouseButton,
    );
    await tester.pump();

    expect(contextId, 'org.example.Spotify');
  });

  testWidgets('tray menu panel renders DBusMenu rows and dispatches item ids', (
    WidgetTester tester,
  ) async {
    String? itemId;
    int? menuItemId;
    const TrayMenuStatus menu = TrayMenuStatus(
      itemId: ':1.27/org/ayatana/NotificationItem/indicator_solaar',
      x: 100,
      y: 10,
      items: <TrayMenuItem>[
        TrayMenuItem(
          id: 4,
          label: 'About Solaar',
          enabled: true,
          kind: TrayMenuItemKind.standard,
          depth: 0,
        ),
        TrayMenuItem(
          id: 3,
          label: '',
          enabled: false,
          kind: TrayMenuItemKind.separator,
          depth: 0,
        ),
        TrayMenuItem(
          id: 5,
          label: 'Quit Solaar',
          enabled: true,
          kind: TrayMenuItemKind.standard,
          depth: 1,
        ),
      ],
    );

    await tester.pumpWidget(
      _scopedSurface(
        child: TrayMenuPanel(
          menu: menu,
          borderRadius: BorderRadius.circular(12),
          onActivateItem: (String id, int rowId) {
            itemId = id;
            menuItemId = rowId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('About Solaar'), findsOneWidget);
    expect(find.text('Quit Solaar'), findsOneWidget);

    await tester.tap(find.text('About Solaar'));
    await tester.pump();

    expect(itemId, ':1.27/org/ayatana/NotificationItem/indicator_solaar');
    expect(menuItemId, 4);
  });

  testWidgets('tray menu status opens the bar tray menu dropdown', (
    WidgetTester tester,
  ) async {
    final StreamController<TrayMenuStatus> trayMenus =
        StreamController<TrayMenuStatus>();
    addTearDown(trayMenus.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trayStatusProvider.overrideWith((ref) => Stream.value(_trayStatus())),
          trayMenuStatusProvider.overrideWith((ref) => trayMenus.stream),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    trayMenus.add(
      const TrayMenuStatus(
        itemId: 'org.example.Dropbox',
        x: 100,
        y: 10,
        items: <TrayMenuItem>[
          TrayMenuItem(
            id: 8,
            label: 'Open Folder',
            enabled: true,
            kind: TrayMenuItemKind.standard,
            depth: 0,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open Folder'), findsOneWidget);
  });

  testWidgets('tray strip sits to the left of managed bar widgets', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trayStatusProvider.overrideWith((ref) => Stream.value(_trayStatus())),
          networkStatusProvider.overrideWith(
            (ref) => Stream.value(_networkStatus()),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    final Rect trayRect = tester.getRect(
      find.byKey(const ValueKey<String>('tray-strip')),
    );
    final Rect networkRect = tester.getRect(find.bySemanticsLabel('Network'));

    expect(trayRect.right, lessThan(networkRect.left));
  });

  testWidgets('tray strip collapses cleanly when there are no tray items', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trayStatusProvider.overrideWith(
            (ref) => Stream.value(const TrayStatus(items: <TrayItem>[])),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('tray-strip')), findsNothing);
  });

  testWidgets('notification popup renders the HTML-style inbox rows', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationStatusProvider.overrideWith(
            (ref) => Stream.value(_notificationStatus()),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('notifications-button')),
      findsOneWidget,
    );
    _expectStrokedIconsaxGlyph(tester, Iconsax.notification_bing_copy);
    expect(_iconsaxGlyphFinder(Iconsax.notification_copy), findsNothing);
    expect(find.text('Slack'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('notifications-button')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('NOTIFICATIONS'), findsOneWidget);
    expect(find.text('clear all'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('notifications-count-pill')),
      findsOneWidget,
    );
    expect(find.text('SLACK'), findsOneWidget);
    expect(
      find.text('Maya: "wfh today, ping me before standup"'),
      findsOneWidget,
    );
    expect(find.text('SYSTEM'), findsOneWidget);
  });

  testWidgets('new notification shows clickable toast that opens inbox', (
    WidgetTester tester,
  ) async {
    final StreamController<NotificationStatus> notifications =
        StreamController<NotificationStatus>();
    addTearDown(notifications.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationStatusProvider.overrideWith(
            (ref) => notifications.stream,
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    notifications.add(
      const NotificationStatus(
        available: true,
        unreadCount: 0,
        dndEnabled: false,
        entries: <NotificationEntry>[],
      ),
    );
    await tester.pump();

    final NotificationStatus status = _notificationStatus();
    notifications.add(status);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Maya: "wfh today, ping me before standup"'),
      findsOneWidget,
    );
    expect(find.text('NOTIFICATIONS'), findsNothing);

    await tester.tap(find.text('Maya: "wfh today, ping me before standup"'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('NOTIFICATIONS'), findsOneWidget);
    expect(find.text('SLACK'), findsOneWidget);
  });

  testWidgets(
    'notification popup shows a quiet empty state when there is nothing to render',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationStatusProvider.overrideWith(
              (ref) => Stream.value(
                const NotificationStatus(
                  available: true,
                  unreadCount: 0,
                  dndEnabled: false,
                  entries: <NotificationEntry>[],
                ),
              ),
            ),
          ],
          child: const Hyprbaric(),
        ),
      );
      await tester.pumpAndSettle();

      _expectStrokedIconsaxGlyph(tester, Iconsax.notification_copy);
      expect(_iconsaxGlyphFinder(Iconsax.notification_bing_copy), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('notifications-button')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('no new notifications'), findsOneWidget);
    },
  );

  testWidgets('open notification popup reflects live notification updates', (
    WidgetTester tester,
  ) async {
    final StreamController<NotificationStatus> notifications =
        StreamController<NotificationStatus>();
    addTearDown(notifications.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationStatusProvider.overrideWith(
            (ref) => notifications.stream,
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    notifications.add(_notificationStatus());
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('notifications-button')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('SLACK'), findsOneWidget);

    notifications.add(
      const NotificationStatus(
        available: true,
        unreadCount: 0,
        dndEnabled: false,
        entries: <NotificationEntry>[],
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('SLACK'), findsNothing);
    expect(find.text('no new notifications'), findsOneWidget);
  });

  testWidgets('output mute control shows the volume OSD', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioStatusProvider.overrideWith(
            (ref) => Stream.value(_audioStatus()),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Audio and display controls'));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Mute EVO4 Analog Surround 4.0'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('VOLUME'), findsOneWidget);
    expect(find.text('Muted'), findsOneWidget);
    expect(
      tester.getCenter(find.text('VOLUME')).dy,
      inInclusiveRange(420, 465),
    );
  });

  testWidgets('controls panel sends screenshot intents directly', (
    WidgetTester tester,
  ) async {
    ScreenshotMode? capturedMode;
    bool settingsOpened = false;
    final List<String> toasts = <String>[];

    await tester.pumpWidget(
      _scopedSurface(
        child: ControlsPanel(
          borderRadius: BorderRadius.circular(18),
          onCaptureScreenshot: (ScreenshotMode mode) => capturedMode = mode,
          onPickColor: () => toasts.add('pick color'),
          onToggleRecording: () => toasts.add('toggle recording'),
          onOpenSettings: () => settingsOpened = true,
          onToast: toasts.add,
          dndEnabled: false,
          onSetDoNotDisturb: (_) {},
          nightLightStatus: const NightLightStatusAvailable(
            enabled: false,
            temperature: 3500,
          ),
          onSetNightLight: (_) {},
          caffeineStatus: const CaffeineStatusAvailable(enabled: false),
          onSetCaffeine: (_) {},
          recordingStatus: const RecordingStatusIdle(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('CAPTURE'), findsOneWidget);
    expect(find.text('REGION'), findsOneWidget);
    expect(find.text('BAR SETTINGS'), findsOneWidget);
    expect(find.text('KBD'), findsOneWidget);
    expect(find.byType(ControlSectionTray), findsNWidgets(3));
    expect(find.byType(ControlRocker), findsNWidgets(4));
    expect(
      tester.getSize(find.byType(ControlSettingsRow)),
      const Size(398, 62),
    );

    await tester.tap(find.text('REGION'));
    await tester.pump();

    expect(capturedMode, ScreenshotMode.region);

    await tester.tap(find.text('COLOR PICK'));
    await tester.pump();

    expect(toasts, contains('pick color'));

    await tester.tap(find.text('STBY'));
    await tester.pump();

    expect(toasts, contains('toggle recording'));

    await tester.tap(find.text('MAGNIFY'));
    await tester.pump();

    expect(toasts, contains('Magnifier support is not available yet'));

    await tester.tap(find.text('KBD'));
    await tester.pump();

    expect(toasts, contains('Keyboard lock support is not available yet'));

    await tester.tap(find.text('BAR SETTINGS'));
    await tester.pump();

    expect(settingsOpened, true);
  });

  testWidgets('controls panel disables recording when unavailable', (
    WidgetTester tester,
  ) async {
    bool toggled = false;

    await tester.pumpWidget(
      _scopedSurface(
        child: ControlsPanel(
          borderRadius: BorderRadius.circular(18),
          onCaptureScreenshot: (_) {},
          onPickColor: () {},
          onToggleRecording: () => toggled = true,
          onOpenSettings: () {},
          onToast: (_) {},
          dndEnabled: false,
          onSetDoNotDisturb: (_) {},
          nightLightStatus: const NightLightStatusAvailable(
            enabled: false,
            temperature: 3500,
          ),
          onSetNightLight: (_) {},
          caffeineStatus: const CaffeineStatusAvailable(enabled: false),
          onSetCaffeine: (_) {},
          recordingStatus: const RecordingStatusUnavailable(
            message: '`wf-recorder` is unavailable',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('N/A'), findsOneWidget);

    await tester.tap(find.text('N/A'));
    await tester.pump();

    expect(toggled, false);
  });

  testWidgets('controls panel routes DND rocker state outward', (
    WidgetTester tester,
  ) async {
    bool? dndTarget;

    await tester.pumpWidget(
      _scopedSurface(
        child: ControlsPanel(
          borderRadius: BorderRadius.circular(18),
          onCaptureScreenshot: (_) {},
          onPickColor: () {},
          onToggleRecording: () {},
          onOpenSettings: () {},
          onToast: (_) {},
          dndEnabled: true,
          onSetDoNotDisturb: (bool value) => dndTarget = value,
          nightLightStatus: const NightLightStatusAvailable(
            enabled: false,
            temperature: 3500,
          ),
          onSetNightLight: (_) {},
          caffeineStatus: const CaffeineStatusAvailable(enabled: false),
          onSetCaffeine: (_) {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('DND'));
    await tester.pump();

    expect(dndTarget, false);
  });

  testWidgets('controls panel routes Night rocker state outward', (
    WidgetTester tester,
  ) async {
    bool? nightTarget;

    await tester.pumpWidget(
      _scopedSurface(
        child: ControlsPanel(
          borderRadius: BorderRadius.circular(18),
          onCaptureScreenshot: (_) {},
          onPickColor: () {},
          onToggleRecording: () {},
          onOpenSettings: () {},
          onToast: (_) {},
          dndEnabled: false,
          onSetDoNotDisturb: (_) {},
          nightLightStatus: const NightLightStatusAvailable(
            enabled: false,
            temperature: 3500,
          ),
          onSetNightLight: (bool value) => nightTarget = value,
          caffeineStatus: const CaffeineStatusAvailable(enabled: false),
          onSetCaffeine: (_) {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('NIGHT'));
    await tester.pump();

    expect(nightTarget, true);
  });

  testWidgets('controls panel disables Night rocker when unavailable', (
    WidgetTester tester,
  ) async {
    bool? nightTarget;

    await tester.pumpWidget(
      _scopedSurface(
        child: ControlsPanel(
          borderRadius: BorderRadius.circular(18),
          onCaptureScreenshot: (_) {},
          onPickColor: () {},
          onToggleRecording: () {},
          onOpenSettings: () {},
          onToast: (_) {},
          dndEnabled: false,
          onSetDoNotDisturb: (_) {},
          nightLightStatus: const NightLightStatusUnavailable(
            enabled: true,
            temperature: 3500,
            message: 'hyprsunset is unavailable',
          ),
          onSetNightLight: (bool value) => nightTarget = value,
          caffeineStatus: const CaffeineStatusAvailable(enabled: false),
          onSetCaffeine: (_) {},
        ),
      ),
    );
    await tester.pump();

    final ControlRocker rocker = tester.widget<ControlRocker>(
      find.byKey(const ValueKey<String>('controls-night-light-rocker')),
    );
    expect(rocker.value, true);
    expect(rocker.enabled, false);

    await tester.tap(find.text('NIGHT'));
    await tester.pump();

    expect(nightTarget, isNull);
  });

  testWidgets('controls panel routes Caffeine rocker state outward', (
    WidgetTester tester,
  ) async {
    bool? caffeineTarget;

    await tester.pumpWidget(
      _scopedSurface(
        child: ControlsPanel(
          borderRadius: BorderRadius.circular(18),
          onCaptureScreenshot: (_) {},
          onPickColor: () {},
          onToggleRecording: () {},
          onOpenSettings: () {},
          onToast: (_) {},
          dndEnabled: false,
          onSetDoNotDisturb: (_) {},
          nightLightStatus: const NightLightStatusAvailable(
            enabled: false,
            temperature: 3500,
          ),
          onSetNightLight: (_) {},
          caffeineStatus: const CaffeineStatusAvailable(enabled: false),
          onSetCaffeine: (bool value) => caffeineTarget = value,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('CAFFEINE'));
    await tester.pump();

    expect(caffeineTarget, true);
  });

  testWidgets('controls panel disables Caffeine rocker when unavailable', (
    WidgetTester tester,
  ) async {
    bool? caffeineTarget;

    await tester.pumpWidget(
      _scopedSurface(
        child: ControlsPanel(
          borderRadius: BorderRadius.circular(18),
          onCaptureScreenshot: (_) {},
          onPickColor: () {},
          onToggleRecording: () {},
          onOpenSettings: () {},
          onToast: (_) {},
          dndEnabled: false,
          onSetDoNotDisturb: (_) {},
          nightLightStatus: const NightLightStatusAvailable(
            enabled: false,
            temperature: 3500,
          ),
          onSetNightLight: (_) {},
          caffeineStatus: const CaffeineStatusUnavailable(
            message: 'login1 is unavailable',
          ),
          onSetCaffeine: (bool value) => caffeineTarget = value,
        ),
      ),
    );
    await tester.pump();

    final ControlRocker rocker = tester.widget<ControlRocker>(
      find.byKey(const ValueKey<String>('controls-caffeine-rocker')),
    );
    expect(rocker.value, false);
    expect(rocker.enabled, false);

    await tester.tap(find.text('CAFFEINE'));
    await tester.pump();

    expect(caffeineTarget, isNull);
  });

  testWidgets('open controls popup reflects live DND updates', (
    WidgetTester tester,
  ) async {
    final StreamController<NotificationStatus> notifications =
        StreamController<NotificationStatus>();
    addTearDown(notifications.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationStatusProvider.overrideWith(
            (ref) => notifications.stream,
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    notifications.add(
      const NotificationStatus(
        available: true,
        unreadCount: 0,
        dndEnabled: false,
        entries: <NotificationEntry>[],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Controls'));
    await tester.pump();
    await tester.pumpAndSettle();

    ControlRocker rocker = tester.widget<ControlRocker>(
      find.byKey(const ValueKey<String>('controls-dnd-rocker')),
    );
    expect(rocker.value, false);

    notifications.add(
      const NotificationStatus(
        available: true,
        unreadCount: 0,
        dndEnabled: true,
        entries: <NotificationEntry>[],
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    rocker = tester.widget<ControlRocker>(
      find.byKey(const ValueKey<String>('controls-dnd-rocker')),
    );
    expect(rocker.value, true);
  });

  test('DND notification snapshots do not create toasts', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final TransientOverlayNotifier overlays = container.read(
      transientOverlayProvider.notifier,
    );

    overlays.reconcileNotifications(
      const NotificationStatus(
        available: true,
        unreadCount: 0,
        dndEnabled: false,
        entries: <NotificationEntry>[],
      ),
    );
    overlays.reconcileNotifications(
      _notificationStatus().copyWith(dndEnabled: true),
    );

    expect(container.read(transientOverlayProvider).toasts, isEmpty);
  });

  test('volume OSD updates in place while visible', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final TransientOverlayNotifier overlays = container.read(
      transientOverlayProvider.notifier,
    );
    overlays.showVolumeOsd(value: 20, muted: false);
    final OsdEvent first = container.read(transientOverlayProvider).osd!;

    overlays.showVolumeOsd(value: 55, muted: false);
    final OsdEvent second = container.read(transientOverlayProvider).osd!;

    expect(second.id, first.id);
    expect(second.value, 55);
  });

  testWidgets('network popup closes when clicking outside the popup bounds', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkStatusProvider.overrideWith(
            (ref) => Stream.value(_networkStatus()),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Network'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Fiber_5G'), findsOneWidget);

    await tester.tapAt(const Offset(400, 120));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Fiber_5G'), findsNothing);
  });

  testWidgets('secured network row expands password entry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkStatusProvider.overrideWith(
            (ref) => Stream.value(_networkStatus()),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Network'));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fiber_2.4G'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'enter password'), findsOneWidget);
    expect(find.text('JOIN'), findsOneWidget);
    final InkWell networkRow = tester.widget<InkWell>(
      find
          .ancestor(of: find.text('Fiber_2.4G'), matching: find.byType(InkWell))
          .first,
    );
    expect(networkRow.onTap, isNotNull);

    await tester.tap(
      find.byKey(const ValueKey<String>('network-connect-submit')),
    );
    await tester.pump();

    expect(find.text('Password required.'), findsOneWidget);
  });

  testWidgets('secured network password field accepts text and digits', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkStatusProvider.overrideWith(
            (ref) => Stream.value(_networkStatus()),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Network'));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fiber_2.4G'));
    await tester.pump();
    await tester.pumpAndSettle();

    final Finder passwordField = find.widgetWithText(
      TextField,
      'enter password',
    );
    await tester.enterText(passwordField, 'pass1234');
    await tester.pump();

    final TextField field = tester.widget<TextField>(passwordField);
    expect(field.controller?.text, 'pass1234');
    expect(tester.takeException(), isNull);
  });

  testWidgets('open network row does not show password entry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkStatusProvider.overrideWith(
            (ref) => Stream.value(_networkStatus()),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Network'));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('starbucks-guest'));
    await tester.pump();

    expect(find.widgetWithText(TextField, 'password'), findsNothing);
  });

  testWidgets('session launcher opens from hotkey and closes with escape', (
    WidgetTester tester,
  ) async {
    final StreamController<ShortcutEvent> hotkeys =
        StreamController<ShortcutEvent>();
    addTearDown(hotkeys.close);
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final List<NativeLayerShellKeyboardMode> keyboardModes =
        <NativeLayerShellKeyboardMode>[];
    _setKeyboardModeMock((Object? message) {
      final List<Object?> arguments = message! as List<Object?>;
      keyboardModes.add(arguments.single! as NativeLayerShellKeyboardMode);
      return _pigeonSuccess();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutEventProvider.overrideWith((ref) => hotkeys.stream),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    hotkeys.add(_shortcut(0, const HotkeyEventToggleSessionLauncher()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('SESSION'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('session-action-shutdown')),
      findsOneWidget,
    );
    expect(keyboardModes.last, NativeLayerShellKeyboardMode.exclusive);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('SESSION'), findsNothing);
    expect(keyboardModes.last, NativeLayerShellKeyboardMode.none);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('session launcher arrow keys browse actions before confirming', (
    WidgetTester tester,
  ) async {
    final StreamController<ShortcutEvent> hotkeys =
        StreamController<ShortcutEvent>();
    addTearDown(hotkeys.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutEventProvider.overrideWith((ref) => hotkeys.stream),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    hotkeys.add(_shortcut(0, const HotkeyEventToggleSessionLauncher()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    Material rowMaterial(SessionAction action) {
      final Finder row = find.byKey(
        ValueKey<String>('session-action-${action.name}'),
      );
      final Finder material = find.ancestor(
        of: row,
        matching: find.byType(Material),
      );
      return tester.widget<Material>(material.first);
    }

    expect(rowMaterial(SessionAction.lock).color, SessionMenuColors.selected);
    expect(rowMaterial(SessionAction.logout).color, Colors.transparent);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(rowMaterial(SessionAction.lock).color, Colors.transparent);
    expect(rowMaterial(SessionAction.logout).color, SessionMenuColors.selected);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('End the current Hyprland session?'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('SESSION'), findsOneWidget);
    expect(find.text('End the current Hyprland session?'), findsNothing);
  });

  testWidgets('repeated identical hotkeys still reach the UI', (
    WidgetTester tester,
  ) async {
    final StreamController<ShortcutEvent> hotkeys =
        StreamController<ShortcutEvent>();
    addTearDown(hotkeys.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutEventProvider.overrideWith((ref) => hotkeys.stream),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    hotkeys.add(_shortcut(0, const HotkeyEventToggleControls()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('CAPTURE'), findsOneWidget);

    hotkeys.add(_shortcut(1, const HotkeyEventToggleControls()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('CAPTURE'), findsNothing);
  });

  testWidgets('audio hardware hotkeys drive the optimistic OSD', (
    WidgetTester tester,
  ) async {
    final StreamController<ShortcutEvent> hotkeys =
        StreamController<ShortcutEvent>();
    addTearDown(hotkeys.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutEventProvider.overrideWith((ref) => hotkeys.stream),
          audioStatusProvider.overrideWith(
            (ref) => Stream<AudioStatus>.value(_audioStatus()),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    hotkeys.add(_shortcut(0, const HotkeyEventVolumeUp(step: 5)));
    await tester.pump();
    await tester.pump();

    expect(find.text('VOLUME'), findsOneWidget);
    expect(find.text('Output level'), findsOneWidget);

    hotkeys.add(_shortcut(1, const HotkeyEventToggleMute()));
    await tester.pump();
    await tester.pump();

    expect(find.text('VOLUME'), findsOneWidget);
    expect(find.text('Muted'), findsOneWidget);
  });

  testWidgets('brightness hardware hotkeys drive the optimistic OSD', (
    WidgetTester tester,
  ) async {
    final StreamController<ShortcutEvent> hotkeys =
        StreamController<ShortcutEvent>();
    addTearDown(hotkeys.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutEventProvider.overrideWith((ref) => hotkeys.stream),
          brightnessStatusProvider.overrideWith(
            (ref) => Stream<BrightnessStatus>.value(
              const BrightnessStatusAvailable(device: 'eDP-1', value: 72),
            ),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    hotkeys.add(_shortcut(0, const HotkeyEventBrightnessUp()));
    await tester.pump();
    await tester.pump();

    expect(find.text('BRIGHTNESS'), findsOneWidget);
    expect(find.text('Display · backlight'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is RichText && widget.text.toPlainText() == '77 %',
      ),
      findsOneWidget,
    );
  });

  testWidgets('color picker hotkey dispatches the color pick command', (
    WidgetTester tester,
  ) async {
    final StreamController<ShortcutEvent> hotkeys =
        StreamController<ShortcutEvent>();
    final _RecordingRustDispatcher dispatcher = _RecordingRustDispatcher();
    addTearDown(hotkeys.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutEventProvider.overrideWith((ref) => hotkeys.stream),
          rustCommandDispatcherProvider.overrideWithValue(dispatcher),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    hotkeys.add(_shortcut(0, const HotkeyEventColorPick()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(dispatcher.intents, hasLength(1));
    expect(dispatcher.intents.single, isA<ColorPickerIntent>());
  });

  testWidgets('recording hotkey dispatches the recording command', (
    WidgetTester tester,
  ) async {
    final StreamController<ShortcutEvent> hotkeys =
        StreamController<ShortcutEvent>();
    final _RecordingRustDispatcher dispatcher = _RecordingRustDispatcher();
    addTearDown(hotkeys.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutEventProvider.overrideWith((ref) => hotkeys.stream),
          rustCommandDispatcherProvider.overrideWithValue(dispatcher),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    hotkeys.add(_shortcut(0, const HotkeyEventToggleRecording()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(dispatcher.intents, hasLength(1));
    expect(dispatcher.intents.single, isA<RecordingIntent>());
  });

  testWidgets('DND hotkey toggles notification quiet mode', (
    WidgetTester tester,
  ) async {
    final StreamController<ShortcutEvent> hotkeys =
        StreamController<ShortcutEvent>();
    final _RecordingRustDispatcher dispatcher = _RecordingRustDispatcher();
    addTearDown(hotkeys.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutEventProvider.overrideWith((ref) => hotkeys.stream),
          notificationStatusProvider.overrideWith(
            (ref) => Stream.value(_notificationStatus()),
          ),
          rustCommandDispatcherProvider.overrideWithValue(dispatcher),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    hotkeys.add(_shortcut(0, const HotkeyEventToggleDoNotDisturb()));
    await tester.pump();

    expect(dispatcher.intents, hasLength(1));
    expect(dispatcher.intents.single, isA<NotificationIntent>());
    expect(dispatcher.intents.single.debugLabel, 'notification_dnd:true');
  });

  testWidgets('Night light hotkey toggles the available Night light state', (
    WidgetTester tester,
  ) async {
    final StreamController<ShortcutEvent> hotkeys =
        StreamController<ShortcutEvent>();
    final _RecordingRustDispatcher dispatcher = _RecordingRustDispatcher();
    addTearDown(hotkeys.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutEventProvider.overrideWith((ref) => hotkeys.stream),
          nightLightStatusProvider.overrideWith(
            (ref) => Stream.value(
              const NightLightStatusAvailable(
                enabled: false,
                temperature: 3500,
              ),
            ),
          ),
          rustCommandDispatcherProvider.overrideWithValue(dispatcher),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    hotkeys.add(_shortcut(0, const HotkeyEventToggleNightLight()));
    await tester.pump();

    expect(dispatcher.intents, hasLength(1));
    expect(dispatcher.intents.single, isA<NightLightIntent>());
    expect(dispatcher.intents.single.debugLabel, 'night_light_enabled:true');
  });

  testWidgets('Caffeine hotkey toggles the available Caffeine state', (
    WidgetTester tester,
  ) async {
    final StreamController<ShortcutEvent> hotkeys =
        StreamController<ShortcutEvent>();
    final _RecordingRustDispatcher dispatcher = _RecordingRustDispatcher();
    addTearDown(hotkeys.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutEventProvider.overrideWith((ref) => hotkeys.stream),
          caffeineStatusProvider.overrideWith(
            (ref) =>
                Stream.value(const CaffeineStatusAvailable(enabled: false)),
          ),
          rustCommandDispatcherProvider.overrideWithValue(dispatcher),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    hotkeys.add(_shortcut(0, const HotkeyEventToggleCaffeine()));
    await tester.pump();

    expect(dispatcher.intents, hasLength(1));
    expect(dispatcher.intents.single, isA<CaffeineIntent>());
    expect(dispatcher.intents.single.debugLabel, 'caffeine_enabled:true');
  });

  testWidgets('session launcher confirms and closes on started result', (
    WidgetTester tester,
  ) async {
    final StreamController<ShortcutEvent> hotkeys =
        StreamController<ShortcutEvent>();
    final StreamController<SessionCommandResult> results =
        StreamController<SessionCommandResult>();
    addTearDown(hotkeys.close);
    addTearDown(results.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutEventProvider.overrideWith((ref) => hotkeys.stream),
          sessionCommandResultProvider.overrideWith((ref) => results.stream),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    hotkeys.add(_shortcut(0, const HotkeyEventToggleSessionLauncher()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(
      find.byKey(const ValueKey<String>('session-action-shutdown')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Power off the machine now?'), findsOneWidget);

    await tester.tap(find.text('Confirm Shutdown'));
    await tester.pump();

    results.add(
      const SessionCommandResult(
        action: SessionAction.shutdown,
        outcome: SessionCommandOutcome.started,
        message: null,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Session Launcher'), findsNothing);
  });

  testWidgets('app launcher console omits filter status and brand labels', (
    WidgetTester tester,
  ) async {
    final TextEditingController queryController = TextEditingController();
    final FocusNode queryFocusNode = FocusNode();
    addTearDown(queryController.dispose);
    addTearDown(queryFocusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 680,
              child: AppLauncherConsole(
                results: AppLauncherResults(
                  phase: AppLauncherPhase.ready,
                  query: '',
                  entries: <AppLauncherEntry>[_appEntry()],
                ),
                queryController: queryController,
                queryFocusNode: queryFocusNode,
                selectedIndex: 0,
                iconPathsByEntryId: const <String, String>{},
                borderRadius: HyprRadii.launcherRadius,
                onSelect: (_) {},
                onLaunch: (_) {},
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('app-launcher-query')),
      findsOneWidget,
    );
    expect(find.text('ALL'), findsNothing);
    expect(find.text('READY'), findsNothing);
    expect(find.text('HYPRBARIC'), findsNothing);
    expect(find.text('1 RESULT'), findsOneWidget);
  });

  testWidgets('app launcher result rail shares its scrollbar controller', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 220,
            child: AppLauncherResultsList(
              results: AppLauncherResults(
                phase: AppLauncherPhase.ready,
                query: '',
                entries: <AppLauncherEntry>[
                  for (int index = 0; index < 16; index++)
                    _appEntry(id: 'app-$index.desktop', name: 'App $index'),
                ],
              ),
              loading: false,
              iconPathsByEntryId: const <String, String>{},
              selectedIndex: 0,
              onSelect: (_) {},
              onLaunch: (_) {},
            ),
          ),
        ),
      ),
    );

    final Scrollbar scrollbar = tester.widget(find.byType(Scrollbar));
    final ListView listView = tester.widget(
      find.byKey(const ValueKey<String>('app-launcher-results')),
    );

    expect(scrollbar.controller, isNotNull);
    expect(identical(scrollbar.controller, listView.controller), isTrue);
  });

  test('app launcher icon file requires finite icon dimensions', () {
    const AppLauncherIconFile icon = AppLauncherIconFile(
      path: '/tmp/example.svg',
      dimension: 24,
      fallback: SizedBox.square(dimension: 24),
    );

    expect(icon.dimension, 24);
  });

  testWidgets('app launcher bitmap icons decode at display size', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(devicePixelRatio: 2),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppLauncherIconFile(
            path: '/tmp/example.png',
            dimension: 26,
            fallback: SizedBox.square(dimension: 26),
          ),
        ),
      ),
    );

    final Image image = tester.widget(find.byType(Image));
    final ResizeImage provider = image.image as ResizeImage;

    expect(image.width, 26);
    expect(image.height, 26);
    expect(provider.width, 52);
    expect(provider.height, 52);
  });

  testWidgets('app launcher opens from hotkey and closes with escape', (
    WidgetTester tester,
  ) async {
    final StreamController<ShortcutEvent> hotkeys =
        StreamController<ShortcutEvent>();
    addTearDown(hotkeys.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutEventProvider.overrideWith((ref) => hotkeys.stream),
          appLauncherResultsProvider.overrideWith(
            (ref) => Stream.value(
              AppLauncherResults(
                phase: AppLauncherPhase.ready,
                query: '',
                entries: <AppLauncherEntry>[_appEntry()],
              ),
            ),
          ),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    hotkeys.add(_shortcut(0, const HotkeyEventToggleAppLauncher()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey<String>('app-launcher-query')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('app-launcher-entry-firefox.desktop')),
      findsOneWidget,
    );
    expect(find.text('Open Firefox'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey<String>('app-launcher-entry-firefox.desktop')),
      findsNothing,
    );
  });

  testWidgets('app launcher closes on started launch result', (
    WidgetTester tester,
  ) async {
    final StreamController<ShortcutEvent> hotkeys =
        StreamController<ShortcutEvent>();
    final StreamController<AppLaunchResult> launches =
        StreamController<AppLaunchResult>();
    addTearDown(hotkeys.close);
    addTearDown(launches.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutEventProvider.overrideWith((ref) => hotkeys.stream),
          appLauncherResultsProvider.overrideWith(
            (ref) => Stream.value(
              AppLauncherResults(
                phase: AppLauncherPhase.ready,
                query: '',
                entries: <AppLauncherEntry>[_appEntry()],
              ),
            ),
          ),
          appLaunchResultProvider.overrideWith((ref) => launches.stream),
        ],
        child: const Hyprbaric(),
      ),
    );
    await tester.pumpAndSettle();

    hotkeys.add(_shortcut(0, const HotkeyEventToggleAppLauncher()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(
      find.byKey(const ValueKey<String>('app-launcher-entry-firefox.desktop')),
    );
    await tester.pump();

    launches.add(
      const AppLaunchResult(
        id: 'firefox.desktop',
        outcome: AppLaunchOutcome.started,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey<String>('app-launcher-entry-firefox.desktop')),
      findsNothing,
    );
  });

  testWidgets(
    'region manager coalesces overlapping updates to the latest rect',
    (WidgetTester tester) async {
      final List<Map<String, Object?>> payloads = <Map<String, Object?>>[];
      final Completer<void> gate = Completer<void>();
      int invocationCount = 0;

      _setRegionMock((Object? message) {
        invocationCount += 1;
        payloads.add(_regionPayloadFromMessage(message));
        if (invocationCount == 1) {
          return gate.future.then((_) => _pigeonSuccess());
        }
        return _pigeonSuccess();
      });

      final LayerShellRegionManager manager = LayerShellRegionManager(
        barHeight: 36,
      );
      final Rect firstRect = const Rect.fromLTWH(12, 36, 180, 24);
      final Rect secondRect = const Rect.fromLTWH(12, 36, 180, 64);
      final Rect thirdRect = const Rect.fromLTWH(12, 36, 180, 120);

      final Future<void> first = manager.updateRegion(
        menuRect: firstRect,
        debugLabel: 'first',
      );
      final Future<void> second = manager.updateRegion(
        menuRect: secondRect,
        debugLabel: 'second',
      );
      final Future<void> third = manager.updateRegion(
        menuRect: thirdRect,
        debugLabel: 'third',
      );

      await tester.pump();
      expect(invocationCount, 1);

      gate.complete();
      await Future.wait(<Future<void>>[first, second, third]);
      await tester.pump();

      expect(invocationCount, 2);
      final Map<String, Object?> latestPayload = payloads.last;
      expect(latestPayload['bar_h'], 36);
      expect(latestPayload['bar_edge'], 'top');
      expect(latestPayload['capture_all_clicks'], false);

      final Map<Object?, Object?> menu =
          latestPayload['menu']! as Map<Object?, Object?>;
      expect(menu['x'], thirdRect.left.round());
      expect(menu['w'], thirdRect.width.round());
      expect(menu['h'], thirdRect.height.round());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets('region manager includes bottom bar edge in native requests', (
    WidgetTester tester,
  ) async {
    final List<Map<String, Object?>> payloads = <Map<String, Object?>>[];
    _setRegionMock((Object? message) {
      payloads.add(_regionPayloadFromMessage(message));
      return _pigeonSuccess();
    });

    final LayerShellRegionManager manager = LayerShellRegionManager(
      barHeight: 36,
      barEdge: LayerShellBarEdge.bottom,
    );

    await manager.updateRegion(menuRect: null, debugLabel: 'bottom');
    await tester.pump();

    expect(payloads.single['bar_edge'], 'bottom');
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('region manager skips duplicate requests', (
    WidgetTester tester,
  ) async {
    int invocationCount = 0;
    _setRegionMock((Object? message) {
      invocationCount += 1;
      return _pigeonSuccess();
    });

    final LayerShellRegionManager manager = LayerShellRegionManager(
      barHeight: 36,
    );
    const Rect rect = Rect.fromLTWH(0, 36, 140, 48);

    await manager.updateRegion(menuRect: rect, debugLabel: 'first');
    await tester.pump();
    await manager.updateRegion(menuRect: rect, debugLabel: 'duplicate');
    await tester.pump();

    expect(invocationCount, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('region manager preserves passive regions across menu updates', (
    WidgetTester tester,
  ) async {
    final List<Map<String, Object?>> payloads = <Map<String, Object?>>[];
    _setRegionMock((Object? message) {
      payloads.add(_regionPayloadFromMessage(message));
      return _pigeonSuccess();
    });

    final LayerShellRegionManager manager = LayerShellRegionManager(
      barHeight: 36,
    );
    const Rect menuRect = Rect.fromLTWH(600, 36, 180, 120);
    const Rect toastRect = Rect.fromLTWH(240, 52, 320, 48);

    await manager.setPassiveRegions(
      owner: 'toasts',
      regions: const <LayerShellMenuRegion>[
        LayerShellMenuRegion(
          rect: toastRect,
          radius: BorderRadius.all(Radius.circular(24)),
        ),
      ],
    );
    await manager.updateRegion(
      menuRect: menuRect,
      radius: BorderRadius.circular(18),
      captureAllClicks: true,
      debugLabel: 'menu',
    );
    await manager.updateRegion(menuRect: null, debugLabel: 'menu-close');
    await tester.pump();

    final Map<String, Object?> withMenu = payloads[1];
    expect(withMenu['capture_all_clicks'], true);
    expect(withMenu['menu'], isNotNull);
    final List<Object?> regions = withMenu['regions']! as List<Object?>;
    expect(regions, hasLength(1));
    expect(
      (regions.single! as Map<Object?, Object?>)['x'],
      toastRect.left.round(),
    );

    final Map<String, Object?> afterClose = payloads.last;
    expect(afterClose['capture_all_clicks'], false);
    expect(afterClose['menu'], null);
    expect(afterClose['regions'], hasLength(1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets(
    'dropdown keeps region updates bounded while opening and closing',
    (WidgetTester tester) async {
      final List<Map<String, Object?>> payloads = <Map<String, Object?>>[];
      _setRegionMock((Object? message) {
        payloads.add(_regionPayloadFromMessage(message));
        return _pigeonSuccess();
      });

      final LayerShellDropdownController controller =
          LayerShellDropdownController();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: LayerShellDropdown(
                  controller: controller,
                  buttonBuilder:
                      (
                        BuildContext context,
                        LayerShellDropdownController controller, {
                        required bool isOpen,
                      }) => const SizedBox(
                        width: 96,
                        height: 32,
                        child: Text('Toggle'),
                      ),
                  menuBuilder:
                      (
                        BuildContext context,
                        LayerShellDropdownController controller,
                      ) => const Material(
                        child: SizedBox(
                          width: 180,
                          height: 160,
                          child: Text('Menu content'),
                        ),
                      ),
                ),
              ),
            ),
          ),
        ),
      );

      controller.open();
      await tester.pump();
      for (int index = 0; index < 12; index += 1) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      controller.close();
      await tester.pump();
      for (int index = 0; index < 12; index += 1) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(payloads.length, lessThanOrEqualTo(4));
      expect(payloads.first['capture_all_clicks'], true);
      expect(
        payloads.any(
          (Map<String, Object?> payload) =>
              payload['capture_all_clicks'] == false,
        ),
        true,
      );
      expect(payloads.last['menu'], null);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}
