import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:hyprbaric_widgetbook/catalog/catalog_theme.dart';
import 'package:hyprbaric_widgetbook/audio/preview_registry.dart';

/// Reads the preview names the web component is prepared to render.
List<String> _webPreviewNames() {
  final File source = File('../website/src/components/FlutterDemo/index.jsx');
  expect(
    source.existsSync(),
    isTrue,
    reason: 'The landing-page component moved, so this guard cannot run.',
  );

  final String body = source.readAsStringSync();
  final int start = body.indexOf('const SKELETONS = {');
  expect(start, isNonNegative, reason: 'SKELETONS map not found.');
  final String block = body.substring(start, body.indexOf('};', start));

  return RegExp(r'^\s*(\w+):', multiLine: true)
      .allMatches(block)
      .map((RegExpMatch match) => match.group(1)!)
      .toList(growable: false);
}

void main() {
  test('the web component and the Dart registry agree on preview names', () {
    expect(
      _webPreviewNames()..sort(),
      LandingPreview.values
          .map((LandingPreview preview) => preview.name)
          .toList()
        ..sort(),
    );
  });

  test('an unknown preview name resolves to nothing rather than the mixer', () {
    expect(LandingPreview.byName('workspaces'), isNull);
    expect(LandingPreview.byName(null), isNull);
    expect(LandingPreview.byName(''), isNull);
    expect(LandingPreview.byName('mixer'), LandingPreview.mixer);
  });

  testWidgets('each preview declares its panel\'s real production width', (
    WidgetTester tester,
  ) async {
    // The declared widths are copies of each panel's own BoxConstraints. Laying
    // the panel out unconstrained and measuring it is what stops the copy and
    // the original drifting apart silently.
    for (final LandingPreview preview in LandingPreview.values) {
      final GlobalKey key = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          theme: catalogTheme,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: KeyedSubtree(key: key, child: preview.build()),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        tester.getSize(find.byKey(key)).width,
        preview.width,
        reason:
            '${preview.name} lays out wider or narrower than the width the '
            'embed scales it to',
      );
    }
  });

  test('previews render at the shipping popover radius', () {
    expect(HyprRadii.popoverRadius, const BorderRadius.all(Radius.circular(18)));
  });
}
