import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:hyprbaric_widgetbook/audio/controls_panel_preview.dart';
import 'package:hyprbaric_widgetbook/audio/preview_registry.dart';
import 'package:hyprbaric_widgetbook/embed/embed_theme.dart';
import 'package:hyprbaric_widgetbook/embed/preview_viewport.dart';

void main() {
  for (final double width in <double>[480, 320, 240, 180]) {
    testWidgets('all Controls rows fit a $width px landing host', (
      tester,
    ) async {
      final Size host = Size(width, width / .65);
      tester.view.physicalSize = host;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: embedTheme,
          home: const Scaffold(
            body: PreviewViewport(preview: LandingPreview.controls),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(ControlsPanel), findsOneWidget);
      for (final String label in <String>[
        'REGION',
        'COLOR PICK',
        'MAGNIFY',
        'DND',
        'BAR SETTINGS',
      ]) {
        final Finder text = find.text(label);
        expect(text, findsOneWidget);
        final Rect bounds = tester.getRect(text);
        expect((Offset.zero & host).contains(bounds.topLeft), isTrue);
        expect((Offset.zero & host).contains(bounds.bottomRight), isTrue);
        expect(text.hitTestable(), findsOneWidget);
      }
      for (final ScrollableState scrollable
          in tester.stateList<ScrollableState>(find.byType(Scrollable))) {
        expect(scrollable.position.maxScrollExtent, 0);
      }
    });
  }

  testWidgets('the desktop panel still scrolls on a short display', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: embedTheme,
        home: const Scaffold(body: Center(child: ControlsPanelPreview())),
      ),
    );
    expect(tester.takeException(), isNull);
    final ScrollableState scrollable = tester.state(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
  });
}
