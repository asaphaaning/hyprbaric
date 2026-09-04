import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:hyprbaric_widgetbook/catalog/catalog_theme.dart';
import 'package:hyprbaric_widgetbook/main.directories.g.dart'
    as generated_catalog;
import 'package:hyprbaric_widgetbook/audio/audio_fixtures.dart';
import 'package:hyprbaric_widgetbook/use_cases/audio/audio_atom_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/audio/audio_panel_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/bar/bar_cluster_button_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/bar/bar_cluster_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/bar/bar_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/bar/workspace_fixtures.dart';
import 'package:hyprbaric_widgetbook/use_cases/bar/workspace_strip_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/controls/control_atom_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/controls/controls_fixtures.dart';
import 'package:hyprbaric_widgetbook/use_cases/controls/controls_panel_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/network/network_fixtures.dart';
import 'package:hyprbaric_widgetbook/use_cases/network/network_panel_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/notifications/notification_atom_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/notifications/notification_fixtures.dart';
import 'package:hyprbaric_widgetbook/use_cases/notifications/notification_panel_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/notifications/toast_atom_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/osd/osd_atom_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/power/battery_chip_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/power/power_fixtures.dart';
import 'package:hyprbaric_widgetbook/use_cases/power/power_panel_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/primitives/shared_primitives_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/primitives/surface_primitive_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/settings/settings_chrome_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/settings/settings_fixtures.dart';
import 'package:hyprbaric_widgetbook/use_cases/settings/settings_subpanel_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/settings/settings_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/setup/setup_fixtures.dart';
import 'package:hyprbaric_widgetbook/use_cases/setup/setup_guide_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/tray/tray_fixtures.dart';
import 'package:hyprbaric_widgetbook/use_cases/tray/tray_use_cases.dart';
import 'package:widgetbook/widgetbook.dart';

void main() {
  test('audio fixtures preserve endpoint availability and identity', () {
    expect(AudioFixtures.ready.output, AudioFixtures.output);
    expect(AudioFixtures.ready.input, AudioFixtures.input);
    expect(AudioFixtures.unavailable, isA<AudioStatusUnavailable>());
    expect(AudioFixtures.brightness.value, 75);
  });

  testWidgets('audio atoms use their production components', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildAudioChannelStripStates),
      ),
    );
    expect(find.byType(AudioChannelStrip), findsNWidgets(3));
    expect(find.byType(AudioFader), findsNWidgets(2));
    expect(find.byType(AudioDisabledFader), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildAudioDbReadoutStates),
      ),
    );
    expect(find.byType(AudioDbReadout), findsNWidgets(3));

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildAudioMuteButtonStates),
      ),
    );
    expect(find.byType(AudioMuteButton), findsNWidgets(3));

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildAudioDisabledFader),
      ),
    );
    expect(find.byType(AudioDisabledFader), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildBrightnessControlStates),
      ),
    );
    expect(find.byType(BrightnessControl), findsNWidgets(2));

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildAudioMixerStage),
      ),
    );
    expect(find.byType(AudioMixerStage), findsOneWidget);
    expect(find.byType(AudioMasterRail), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildAudioChromeAtoms),
      ),
    );
    expect(find.byType(HyprPanelDivider), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildAudioMessageStates),
      ),
    );
    expect(find.byType(AudioMessage), findsNWidgets(2));

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildAudioMixerFooter),
      ),
    );
    expect(find.byType(AudioMixerFooter), findsOneWidget);
  });

  testWidgets('composed audio story uses the complete production panel', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildReadyAudioPanel),
      ),
    );

    expect(find.byType(AudioPanel), findsOneWidget);
    expect(find.byType(AudioMixerHeader), findsOneWidget);
    expect(find.byType(AudioMixerStage), findsOneWidget);
    expect(find.byType(AudioMasterRail), findsOneWidget);
    expect(find.byType(AudioMixerFooter), findsOneWidget);
    expect(find.byType(AudioChannelStrip), findsNWidgets(2));
    expect(tester.getSize(find.byType(AudioPanel)).width, 336);
  });

  testWidgets('full bar story is the production composition', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(Builder(builder: buildLaptopBar));
    await tester.pump();
    await tester.pump();

    expect(find.byType(Hyprbaric), findsOneWidget);
    expect(find.text('II'), findsOneWidget);
    expect(find.text('Zed'), findsOneWidget);
    expect(find.text('widget_catalog.dart — Hyprbaric'), findsOneWidget);
    expect(find.text('72%', findRichText: true), findsOneWidget);
    expect(find.text('Sun, Aug 30'), findsOneWidget);
  });

  testWidgets('full bar story leaves no region waiting on a real signal', (
    WidgetTester tester,
  ) async {
    // The catalog never initialises RINF, so any provider the story forgets to
    // override stays in AsyncLoading forever and renders as a dead region
    // rather than as a visible failure. The tray is the canary: it is the
    // furthest-downstream cluster fed by its own provider.
    await tester.pumpWidget(Builder(builder: buildLaptopBar));
    await tester.pump();
    await tester.pump();

    // TrayStrip collapses to a shrink box when it has no items, so this key
    // is present only once trayStatusProvider has actually yielded.
    expect(
      find.byKey(const ValueKey<String>('tray-strip')),
      findsOneWidget,
      reason: 'the tray only renders once trayStatusProvider is overridden',
    );
  });

  testWidgets('settings story uses the complete production menu', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildSettingsMenu),
      ),
    );

    expect(find.byType(SettingsOverlayContent), findsOneWidget);
    expect(find.byType(SettingsSidebar), findsOneWidget);
    expect(find.byType(SettingsContentHeader), findsOneWidget);
    expect(find.text('Appearance'), findsNWidgets(2));

    await tester.tap(find.text('Modules'));
    await tester.pumpAndSettle();

    expect(find.text('Show and hide bar modules.'), findsOneWidget);
  });

  testWidgets('interactive audio story toggles a production mute control', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildInteractiveAudioPanel),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Mute Built-in · Analog Stereo'));
    await tester.pump();

    final AudioChannelStrip output = tester.widget<AudioChannelStrip>(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is AudioChannelStrip &&
            widget.channel == AudioMixerChannel.output,
      ),
    );
    expect(output.endpoint!.muted, isTrue);
  });

  test('controls fixtures preserve distinct operational states', () {
    expect(ControlsFixtures.ready.dndEnabled, isFalse);
    expect(ControlsFixtures.active.dndEnabled, isTrue);
    expect(
      ControlsFixtures.unavailable.recordingStatus,
      isA<RecordingStatusUnavailable>(),
    );
    expect(
      ControlsFixtures.unavailable.nightLightStatus,
      isA<NightLightStatusUnavailable>(),
    );
  });

  testWidgets('controls atoms use their production components', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildControlCapturePadStates),
      ),
    );

    expect(find.byType(ControlCapturePad), findsNWidgets(3));
    expect(find.text('REGION'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildControlRecordPadStates),
      ),
    );
    expect(find.byType(ControlRecordPad), findsNWidgets(4));

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildControlInspectButtonStates),
      ),
    );
    expect(find.byType(ControlInspectButton), findsNWidgets(2));

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildControlRockerStates),
      ),
    );
    expect(find.byType(ControlRocker), findsNWidgets(3));

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildControlSettingsRow),
      ),
    );
    expect(find.byType(ControlSettingsRow), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildControlSectionTray),
      ),
    );
    expect(find.byType(HyprConsoleTray), findsOneWidget);
    expect(find.byType(HyprConsoleSectionLabel), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildControlChassis),
      ),
    );
    expect(find.byType(HyprConsoleChassis), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildControlSectionLabel),
      ),
    );
    expect(find.byType(HyprConsoleSectionLabel), findsOneWidget);
  });

  testWidgets('composed controls story uses the complete production panel', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildReadyControlsPanel),
      ),
    );

    expect(find.byType(ControlsPanel), findsOneWidget);
    expect(find.byType(HyprConsoleTray), findsNWidgets(3));
    expect(find.byType(ControlCapturePad), findsNWidgets(3));
    expect(find.byType(ControlRecordPad), findsOneWidget);
    expect(find.byType(ControlInspectButton), findsNWidgets(2));
    expect(find.byType(ControlRocker), findsNWidgets(4));
    expect(find.byType(ControlSettingsRow), findsOneWidget);
    expect(tester.getSize(find.byType(ControlsPanel)).width, 432);
  });

  testWidgets('interactive controls story updates a production rocker', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildInteractiveControlsPanel),
      ),
    );

    await tester.tap(find.text('NIGHT'));
    await tester.pumpAndSettle();

    final ControlRocker night = tester.widget<ControlRocker>(
      find.byKey(const ValueKey<String>('controls-night-light-rocker')),
    );
    expect(night.value, isTrue);
  });

  test('power fixtures distinguish desktops from battery-powered systems', () {
    expect(PowerFixtures.desktop.batteryPresent, isFalse);
    expect(PowerFixtures.desktop.percentage, isNull);

    final PowerStatus laptop = PowerFixtures.battery(
      percentage: 72,
      state: PowerBatteryState.discharging,
    );

    expect(laptop.batteryPresent, isTrue);
    expect(laptop.percentage, 72);
    expect(laptop.state, PowerBatteryState.discharging);
  });

  testWidgets('battery state matrix renders every domain state and desktop', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildBatteryStateMatrix),
      ),
    );

    expect(find.byType(BatteryChip), findsNWidgets(8));
    expect(find.text('DESKTOP'), findsOneWidget);
    expect(find.text('PENDING CHARGE'), findsOneWidget);
    expect(find.text('PENDING DISCHARGE'), findsOneWidget);
  });

  testWidgets('composed power story uses production panel and profile pads', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildDischargingPowerPanel),
      ),
    );

    expect(find.byType(PowerPanel), findsOneWidget);
    expect(find.byType(PowerProfilePad), findsNWidgets(3));
    expect(find.text('BATTERY'), findsOneWidget);
    expect(find.text('POWER PROFILE'), findsOneWidget);
    expect(find.text('72%', findRichText: true), findsOneWidget);
    expect(find.text('-8.2W'), findsOneWidget);
    expect(tester.getSize(find.byType(PowerPanel)).width, 320);
  });

  testWidgets('interactive power story changes the selected production pad', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildInteractivePowerPanel),
      ),
    );

    await tester.tap(find.text('SAVER'));
    await tester.pumpAndSettle();

    final PowerProfilePad saver = tester.widget<PowerProfilePad>(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is PowerProfilePad && widget.profile == PowerProfile.saver,
      ),
    );
    expect(saver.active, isTrue);
  });

  test('settings fixtures cover every subpanel and keybinding state', () {
    expect(
      SettingsFixtures.appearanceCustom.position,
      AppearancePosition.bottom,
    );
    expect(SettingsFixtures.modulesFocused.entries, hasLength(4));
    expect(SettingsFixtures.workspacesNumeric.visibleCount, 9);
    expect(
      SettingsFixtures.nightLightUnavailable,
      isA<NightLightStatusUnavailable>(),
    );
    expect(SettingsFixtures.scheduleEnabled.entries, hasLength(1));
    expect(SettingsFixtures.capabilities.entries, hasLength(3));
    expect(SettingsFixtures.shortcuts.rows, hasLength(8));
  });

  testWidgets('settings subpanel stories use production panels', (
    WidgetTester tester,
  ) async {
    Future<void> pumpStory(WidgetBuilder builder) async {
      // Each story owns a ProviderScope with a different override set. Tear
      // down the previous scope instead of asking Riverpod to mutate it.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          theme: catalogTheme,
          home: Builder(builder: builder),
        ),
      );
      await tester.pump();
    }

    await pumpStory(buildCustomizedAppearanceSettingsPanel);
    expect(find.byType(AppearanceSettingsPanel), findsOneWidget);

    await pumpStory(buildFocusedModulesSettingsPanel);
    expect(find.byType(ModulesSettingsPanel), findsOneWidget);

    await pumpStory(buildNumericWorkspacesSettingsPanel);
    expect(find.byType(WorkspacesSettingsPanel), findsOneWidget);

    await pumpStory(buildEnabledNightLightSettingsPanel);
    expect(find.byType(NightLightSettingsPanel), findsOneWidget);

    await pumpStory(buildAboutSettingsPanel);
    expect(find.byType(AboutSettingsPanel), findsOneWidget);
  });

  testWidgets('keybindings story renders typed shortcut rows', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildKeybindingsPanel),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(KeybindingsPanel), findsOneWidget);
    expect(find.text('App launcher'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pump();
    expect(find.text('Disabled'), findsOneWidget);
    expect(find.text('Conflicts with Volume up'), findsOneWidget);
  });

  testWidgets(
    'notification atoms render each urgency through production rows',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: catalogTheme,
          home: Builder(builder: buildNotificationRowUrgencies),
        ),
      );

      expect(find.byType(NotificationRow), findsNWidgets(3));
      expect(find.text('GITHUB'), findsOneWidget);
      expect(find.text('DISCORD'), findsOneWidget);
      expect(find.text('SYSTEM'), findsOneWidget);
    },
  );

  testWidgets('composed notification story uses the production panel at 1:1', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildPopulatedNotificationPanel),
      ),
    );

    expect(find.byType(NotificationPanel), findsOneWidget);
    expect(find.byType(NotificationHeader), findsOneWidget);
    expect(find.byType(NotificationCountPill), findsOneWidget);
    expect(find.byType(NotificationList), findsOneWidget);
    expect(find.byType(NotificationRow), findsNWidgets(3));
    expect(tester.getSize(find.byType(NotificationPanel)).width, 380);
  });

  test(
    'notification fixtures cover empty, unavailable, DND, and populated',
    () {
      expect(NotificationFixtures.empty.entries, isEmpty);
      expect(NotificationFixtures.unavailable.available, isFalse);
      expect(NotificationFixtures.doNotDisturb.dndEnabled, isTrue);
      expect(NotificationFixtures.populated().entries, hasLength(3));
    },
  );

  test(
    'network fixtures cover connected, scanning, and unavailable states',
    () {
      expect(NetworkFixtures.connected.activeSsid, 'Hyprnet_5G');
      expect(NetworkFixtures.connected.networks, hasLength(4));
      expect(NetworkFixtures.scanning.scanning, isTrue);
      expect(NetworkFixtures.wifiOff.wifiEnabled, isFalse);
      expect(NetworkFixtures.noDevice.devicePresent, isFalse);
    },
  );

  testWidgets('composed network story uses the production panel', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildConnectedNetworkPanel),
      ),
    );

    expect(find.byType(NetworkPanel), findsOneWidget);
    expect(find.text('Hyprnet_5G'), findsOneWidget);
    expect(find.text('Neighbor_2G'), findsOneWidget);
    expect(find.text('INTERFACES'), findsOneWidget);
    expect(tester.getSize(find.byType(NetworkPanel)).width, 340);
  });

  test('tray fixtures preserve item status and menu hierarchy', () {
    expect(TrayFixtures.populated.items, hasLength(4));
    expect(
      TrayFixtures.populated.items.where(
        (TrayItem item) => item.status == TrayItemStatus.active,
      ),
      hasLength(1),
    );
    expect(
      TrayFixtures.menu.items.where(
        (TrayMenuItem item) => item.kind == TrayMenuItemKind.separator,
      ),
      hasLength(1),
    );
    expect(TrayFixtures.nestedMenu.items[1].depth, 1);
  });

  testWidgets('tray stories use the production strip and menu', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildPopulatedTrayStrip),
      ),
    );
    expect(find.byType(TrayStrip), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildPopulatedTrayMenu),
      ),
    );
    expect(find.byType(TrayMenuPanel), findsOneWidget);
    expect(find.text('Open update manager'), findsOneWidget);
    expect(find.text('Quit'), findsOneWidget);
  });

  test('live value preserves its bounded commit lifecycle', () {
    final HyprLiveValue value = HyprLiveValue(initialValue: 70);

    expect(value.begin(120), 100);
    expect(value.preview(-4), 0);
    expect(value.commit(), 0);
    expect(value.end(), 0);
    expect(value.active, isFalse);
  });

  testWidgets('shared primitive stories use production components', (
    WidgetTester tester,
  ) async {
    Future<void> pumpStory(WidgetBuilder builder) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: catalogTheme,
          home: Builder(builder: builder),
        ),
      );
      await tester.pump();
    }

    await pumpStory(buildCommandButtonVariants);
    expect(find.byType(HyprCommandButton), findsNWidgets(4));

    await pumpStory(buildGlassFrameTreatments);
    expect(find.byType(HyprGlassFrame), findsNWidgets(2));

    await pumpStory(buildPanelChrome);
    expect(find.byType(HyprPanelHeader), findsOneWidget);
    expect(find.byType(HyprSectionBreak), findsOneWidget);

    await pumpStory(buildPlateButton);
    expect(find.byType(HyprPlateButton), findsOneWidget);

    await pumpStory(buildTextFieldChromeStates);
    expect(find.byType(HyprTextFieldChrome), findsNWidgets(2));

    await pumpStory(buildSurface);
    expect(find.byType(HyprSurface), findsOneWidget);

    await pumpStory(buildPopoverSurface);
    expect(find.byType(HyprPopoverSurface), findsOneWidget);
  });

  testWidgets('bar control stories use production buttons', (
    WidgetTester tester,
  ) async {
    Future<void> pumpStory(WidgetBuilder builder) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: catalogTheme,
          home: Builder(builder: builder),
        ),
      );
      await tester.pump();
    }

    await pumpStory(buildBarIconActionButtonStates);
    expect(find.byType(BarIconActionButton), findsNWidgets(2));

    await pumpStory(buildAudioDisplayButtonStates);
    expect(find.byType(AudioDisplayButton), findsNWidgets(2));

    await pumpStory(buildBarNotificationButtonStates);
    expect(find.byType(NotificationButton), findsNWidgets(3));
    expect(find.bySemanticsLabel('Notifications, 3 unread'), findsOneWidget);

    await pumpStory(buildClockButtonStates);
    expect(find.byType(ClockButton), findsNWidgets(2));

    await pumpStory(buildPowerButtonStates);
    expect(find.byType(PowerButton), findsNWidgets(2));
    expect(find.bySemanticsLabel('Session actions'), findsNWidgets(2));
  });


  test('workspace fixtures cover occupancy, special and read-only states', () {
    expect(WorkspaceFixtures.occupied.occupiedWorkspaceIds, contains(5));
    expect(WorkspaceFixtures.special.isSpecial, isTrue);
    expect(WorkspaceFixtures.readOnly.clickable, isFalse);
  });

  testWidgets('workspace strip stories render each indicator style', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildRomanWorkspaceStrip),
      ),
    );

    expect(find.byType(WorkspaceStrip), findsOneWidget);
    expect(find.byType(WorkspaceButton), findsNWidgets(7));
    expect(find.byType(WorkspaceNavButton), findsNWidgets(2));
    expect(find.text('III'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildNumericWorkspaceStrip),
      ),
    );
    expect(find.byType(WorkspaceButton), findsNWidgets(5));
    expect(find.text('3'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildSpecialWorkspaceStrip),
      ),
    );
    expect(find.text('magic'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildReadOnlyWorkspaceStrip),
      ),
    );
    final WorkspaceButton readOnly = tester.widget<WorkspaceButton>(
      find.byKey(const ValueKey<String>('workspace-indicator-3')),
    );
    expect(readOnly.onPressed, isNull);
  });

  testWidgets('interactive workspace story moves the active indicator', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildInteractiveWorkspaceStrip),
      ),
    );

    expect(find.text('IV'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-indicator-4')),
    );
    await tester.pumpAndSettle();

    final WorkspaceButton active = tester.widget<WorkspaceButton>(
      find.byKey(const ValueKey<String>('workspace-indicator-4')),
    );
    expect(active.active, isTrue);
  });

  testWidgets('workspace atom stories cover placeholders and button states', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildWorkspaceStripPlaceholders),
      ),
    );
    expect(find.byType(WorkspaceStripPlaceholder), findsNWidgets(2));
    expect(find.text('…'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildWorkspaceButtonStates),
      ),
    );
    expect(find.byType(WorkspaceButton), findsNWidgets(4));

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildWorkspaceNavButtonStates),
      ),
    );
    expect(find.byType(WorkspaceNavButton), findsNWidgets(3));
  });

  testWidgets('cluster stories compose the production bar clusters', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildRomanLeftCluster),
      ),
    );
    await tester.pump();

    expect(find.byType(LeftCluster), findsOneWidget);
    expect(find.byType(WorkspaceStrip), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildLoadingLeftCluster),
      ),
    );
    await tester.pump();
    expect(find.byType(WorkspaceStripPlaceholder), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildFocusedCenterCluster),
      ),
    );
    await tester.pump();
    expect(find.byType(CenterCluster), findsOneWidget);
    expect(find.text('widget_catalog.dart — Hyprbaric'), findsOneWidget);
  });

  test('setup fixtures cover the default and a tuned first run', () {
    expect(SetupFixtures.appearanceDefault.position, AppearancePosition.top);
    expect(SetupFixtures.appearanceTuned.opacity, 46);
    expect(SetupFixtures.appearanceTuned.accentHue, 310);
    expect(SetupFixtures.accentPresets, hasLength(8));
    expect(SetupFixtures.workspacesNumeric.visibleCount, 5);
  });

  testWidgets('setup guide stories use the production card at every step', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildWelcomeSetupGuide),
      ),
    );
    await tester.pump();

    expect(find.byType(SetupGuideCard), findsOneWidget);
    expect(find.byType(SetupGuidePreview), findsOneWidget);
    expect(find.byType(SetupGuideControls), findsOneWidget);
    expect(find.text('01 — WELCOME'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildLayoutSetupGuide),
      ),
    );
    await tester.pump();
    expect(find.text('04 — LAYOUT'), findsOneWidget);
  });

  testWidgets('interactive setup story advances through the real sequence', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildInteractiveSetupGuide),
      ),
    );
    await tester.pump();

    expect(find.text('01 — WELCOME'), findsOneWidget);

    final SetupGuideControls controls = tester.widget<SetupGuideControls>(
      find.byType(SetupGuideControls),
    );
    controls.onNext();
    await tester.pumpAndSettle();

    expect(find.text('02 — TRANSPARENCY'), findsOneWidget);

    tester
        .widget<SetupGuideControls>(find.byType(SetupGuideControls))
        .onOpacityCommitted(30);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SetupGuidePreview>(find.byType(SetupGuidePreview))
          .appearance
          .opacity,
      30,
    );
  });

  testWidgets('osd atom stories use the production meter parts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildOsdHeaderStates),
      ),
    );
    expect(find.byType(OsdHeader), findsNWidgets(3));
    expect(find.widgetWithText(OsdHeader, 'BRIGHTNESS'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildOsdReadoutViewStates),
      ),
    );
    expect(find.byType(OsdReadoutView), findsNWidgets(3));
    expect(find.textContaining('−∞', findRichText: true), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildOsdMeterStates),
      ),
    );
    expect(find.byType(OsdMeter), findsNWidgets(4));
    expect(find.byType(OsdSegment), findsNWidgets(4 * 32));

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildOsdScaleStates),
      ),
    );
    expect(find.byType(OsdScale), findsNWidgets(2));
    expect(find.text('-18'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildOsdSegmentStates),
      ),
    );
    expect(find.byType(OsdSegment), findsNWidgets(3));
  });

  testWidgets('toast atom stories render tags and corner brackets', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildToastAppTagStates),
      ),
    );
    expect(find.byType(ToastAppTag), findsNWidgets(3));
    expect(find.text('GITHUB'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildToastCornerBrackets),
      ),
    );
    expect(find.byType(ToastCornerBrackets), findsOneWidget);
  });

  testWidgets('bar volume knob icon story paints each accent tint', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildBarVolumeKnobIconStates),
      ),
    );
    expect(find.byType(BarVolumeKnobIcon), findsNWidgets(3));
  });

  testWidgets('settings chrome stories use the production sidebar and rows', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildSettingsSidebar),
      ),
    );
    expect(find.byType(SettingsSidebar), findsOneWidget);
    expect(
      find.byType(SettingsTabButton),
      findsNWidgets(SettingsTab.values.length),
    );

    await tester.tap(find.text('Keybinds'));
    await tester.pumpAndSettle();
    final SettingsTabButton keybinds = tester.widget<SettingsTabButton>(
      find.ancestor(
        of: find.text('Keybinds'),
        matching: find.byType(SettingsTabButton),
      ),
    );
    expect(keybinds.active, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildSettingsTabButtonStates),
      ),
    );
    expect(find.byType(SettingsTabButton), findsNWidgets(3));

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildSettingsContentHeaderStates),
      ),
    );
    expect(
      find.byType(SettingsContentHeader),
      findsNWidgets(SettingsTab.values.length),
    );
    expect(find.text('Build info and licenses.'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildKeybindingRowStates),
      ),
    );
    expect(find.byType(KeybindingRow), findsNWidgets(5));
    expect(find.text('Press a shortcut…'), findsOneWidget);
    expect(find.text('Conflicts with Volume up'), findsOneWidget);
  });

  testWidgets('settings tab body stories route each tab to its panel', (
    WidgetTester tester,
  ) async {
    Future<void> pumpTab(WidgetBuilder builder) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          theme: catalogTheme,
          home: Builder(builder: builder),
        ),
      );
      await tester.pump();
    }

    await pumpTab(buildAppearanceSettingsTabBody);
    expect(find.byType(AppearanceSettingsPanel), findsOneWidget);

    await pumpTab(buildModulesSettingsTabBody);
    expect(find.byType(ModulesSettingsPanel), findsOneWidget);

    await pumpTab(buildWorkspacesSettingsTabBody);
    expect(find.byType(WorkspacesSettingsPanel), findsOneWidget);

    await pumpTab(buildDisplaySettingsTabBody);
    expect(find.byType(NightLightSettingsPanel), findsOneWidget);

    await pumpTab(buildAboutSettingsTabBody);
    expect(find.byType(AboutSettingsPanel), findsOneWidget);

    await pumpTab(buildKeybindsSettingsTabBody);
    expect(find.byType(KeybindingsPanel), findsOneWidget);
    expect(find.text('App launcher'), findsOneWidget);
  });

  test('generated catalog navigation includes component and panel groups', () {
    final List<WidgetbookCategory> categories = generated_catalog.directories
        .whereType<WidgetbookCategory>()
        .toList();
    final WidgetbookCategory buildingBlocks = categories.singleWhere(
      (WidgetbookCategory category) => category.name == 'Building blocks',
    );
    final WidgetbookCategory widgets = categories.singleWhere(
      (WidgetbookCategory category) => category.name == 'Widgets',
    );

    expect(
      buildingBlocks.children!.whereType<WidgetbookFolder>().map(
        (WidgetbookFolder folder) => folder.name,
      ),
      containsAll(<String>[
        'Audio',
        'Bar controls',
        'Controls',
        'Feedback',
        'Notifications',
        'Rows',
        'Surfaces',
      ]),
    );
    expect(
      widgets.children!.whereType<WidgetbookFolder>().map(
        (WidgetbookFolder folder) => folder.name,
      ),
      containsAll(<String>[
        'Audio',
        'Bar',
        'Controls',
        'Network',
        'Notifications',
        'Power',
        'Settings',
        'Setup',
        'Tray',
      ]),
    );

    final WidgetbookFolder audioAtoms = buildingBlocks.children!
        .whereType<WidgetbookFolder>()
        .singleWhere((WidgetbookFolder folder) => folder.name == 'Audio');
    expect(
      audioAtoms.children!.whereType<WidgetbookComponent>().map(
        (WidgetbookComponent component) => component.name,
      ),
      containsAll(<String>[
        'AudioChannelStrip',
        'AudioDbReadout',
        'AudioDisabledFader',
        'AudioFader',
        'AudioMasterRail',
        'AudioMessage',
        'AudioMixerFooter',
        'AudioMixerHeader',
        'AudioMixerStage',
        'AudioMuteButton',
        'BrightnessControl',
        'BrightnessKnob',
        'BrightnessKnobReadout',
        'HyprPanelDivider',
      ]),
    );
  });
}
