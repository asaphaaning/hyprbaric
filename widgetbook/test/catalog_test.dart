import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:hyprbaric_widgetbook/catalog/catalog_theme.dart';
import 'package:hyprbaric_widgetbook/main.dart';
import 'package:hyprbaric_widgetbook/use_cases/controls/control_atom_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/controls/controls_fixtures.dart';
import 'package:hyprbaric_widgetbook/use_cases/controls/controls_panel_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/notifications/notification_atom_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/notifications/notification_fixtures.dart';
import 'package:hyprbaric_widgetbook/use_cases/notifications/notification_panel_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/power/battery_chip_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/power/power_fixtures.dart';
import 'package:hyprbaric_widgetbook/use_cases/power/power_panel_use_cases.dart';

void main() {
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
    expect(find.byType(ControlSectionTray), findsOneWidget);
    expect(find.byType(ControlSectionLabel), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildControlChassis),
      ),
    );
    expect(find.byType(ControlChassis), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildControlSectionLabel),
      ),
    );
    expect(find.byType(ControlSectionLabel), findsOneWidget);
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
    expect(find.byType(ControlSectionTray), findsNWidgets(3));
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

  testWidgets('Widgetbook exposes the generated catalog navigation', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const HyprbaricWidgetbook());
    await tester.pumpAndSettle();

    expect(find.text('Building blocks'), findsOneWidget);
    expect(find.text('Widgets'), findsOneWidget);
    expect(find.text('Notifications'), findsNWidgets(2));
  });
}
