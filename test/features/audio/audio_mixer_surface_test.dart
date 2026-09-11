import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/features/audio/audio_mixer_surface.dart';

void main() {
  for (final double scale in <double>[1, 1.2, 2]) {
    testWidgets('mixer glass preserves desktop alpha at scale $scale', (
      WidgetTester tester,
    ) async {
      final GlobalKey boundaryKey = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: const AudioMixerSurface(
                borderRadius: BorderRadius.all(Radius.circular(17)),
                child: SizedBox(width: 120, height: 160),
              ),
            ),
          ),
        ),
      );

      final RenderRepaintBoundary boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final ui.Image image = await boundary.toImage(pixelRatio: scale);
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        int alpha(int column, int row) =>
            pixels.getUint8((row * image.width + column) * 4 + 3);

        // The compositor needs meaningful transparency beneath the tint.
        expect(
          alpha(image.width ~/ 2, image.height ~/ 2),
          inInclusiveRange(170, 215),
        );
        for (final (int column, int row) in <(int, int)>[
          (0, 0),
          (image.width - 1, 0),
          (0, image.height - 1),
          (image.width - 1, image.height - 1),
        ]) {
          expect(alpha(column, row), 0, reason: 'Corners must remain clear');
        }
        image.dispose();
      });
    });
  }
}
