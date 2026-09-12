import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/features/network/network_console.dart';
import 'package:hyprbaric/src/features/network/network_connection_views.dart';
import 'package:hyprbaric_widgetbook/catalog/catalog_theme.dart';
import 'package:hyprbaric_widgetbook/use_cases/network/network_panel_use_cases.dart';

void main() {
  Future<void> mount(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: catalogTheme,
        home: Builder(builder: buildReferenceNetworkPanel),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hover does not repaint the traffic backlight', (tester) async {
    await mount(tester);
    final backdrop = tester.renderObject<RenderDecoratedBox>(
      find
          .descendant(
            of: find.byType(NetworkTrafficBacklight),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    var paints = 0;
    backdrop.decoration = _CountedDecoration(
      backdrop.decoration,
      () => paints++,
    );
    await tester.pump();
    final before = paints;
    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Choose network…')));
    await tester.pump();
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      paints - before,
      0,
      reason: 'Hover must not repaint the graph backdrop',
    );
    await mouse.removePointer();
  });

  testWidgets('tabs stay under the pointer as connection content changes', (
    tester,
  ) async {
    await mount(tester);
    final before = tester.getTopLeft(find.byType(NetworkTabs));
    await tester.tap(find.text('ETHERNET'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(NetworkTabs)), before);
    await tester.tap(find.text('VPN'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(NetworkTabs)), before);
  });
}

class _CountedDecoration extends Decoration {
  const _CountedDecoration(this.source, this.onPaint);
  final Decoration source;
  final VoidCallback onPaint;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _CountedPainter(source.createBoxPainter(onChanged ?? () {}), onPaint);
}

class _CountedPainter extends BoxPainter {
  _CountedPainter(this.source, this.onPaint);
  final BoxPainter source;
  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    onPaint();
    source.paint(canvas, offset, configuration);
  }

  @override
  void dispose() {
    source.dispose();
    super.dispose();
  }
}
