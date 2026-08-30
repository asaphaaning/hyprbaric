import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:hyprbaric_widgetbook/catalog/catalog_theme.dart';
import 'package:hyprbaric_widgetbook/main.dart';
import 'package:hyprbaric_widgetbook/use_cases/power/battery_chip_use_cases.dart';
import 'package:hyprbaric_widgetbook/use_cases/power/power_fixtures.dart';

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
  });
}
