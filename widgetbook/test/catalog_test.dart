import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:hyprbaric_widgetbook/catalog/catalog_theme.dart';
import 'package:hyprbaric_widgetbook/main.dart';
import 'package:hyprbaric_widgetbook/use_cases/notifications/notification_atom_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/notifications/notification_fixtures.dart';
import 'package:hyprbaric_widgetbook/use_cases/notifications/notification_panel_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/power/battery_chip_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/power/power_fixtures.dart';
import 'package:hyprbaric_widgetbook/use_cases/power/power_panel_use_cases.dart';

void main() {
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
