import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:hyprbaric_widgetbook/catalog/catalog_theme.dart';
import 'package:hyprbaric_widgetbook/use_cases/settings/settings_use_cases.dart';

void main() {
  for (final size in [const Size(1100, 760), const Size(760, 600)]) {
    testWidgets('settings controls stay reachable at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: catalogTheme,
          home: Builder(builder: buildSettingsMenu),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Bottom'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bottom'));
      await tester.pumpAndSettle();
      expect(
        find.text('Anchor the bar to the bottom of the screen.'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text('Restore defaults'),
        180,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore defaults'));
      await tester.pumpAndSettle();
      expect(
        find.text('Anchor the bar to the top of the screen.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Modules').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('System tray'));
      await tester.pumpAndSettle();
      final toggles = tester.widgetList<HyprAmberToggle>(
        find.byType(HyprAmberToggle),
      );
      expect(toggles.where((toggle) => !toggle.value), hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }
}
