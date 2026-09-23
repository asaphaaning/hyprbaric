import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/bindings/bindings.dart';
import 'package:hyprbaric/src/features/tray/tray_strip.dart';

void main() {
  testWidgets('unchanged tray PNG reuses its image cache key', (
    WidgetTester tester,
  ) async {
    final List<int> red = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
      'AAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
    );
    final List<int> green = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
      'AAAADUlEQVR4nGNg+M/wHwAEAQH/cetH5QAAAABJRU5ErkJggg==',
    );

    Future<MemoryImage> show(List<int> bytes) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(devicePixelRatio: 2),
              child: TrayStrip(
                status: TrayStatus(
                  items: <TrayItem>[
                    TrayItem(
                      id: 'notifier',
                      title: 'Notifier',
                      status: TrayItemStatus.active,
                      icon: TrayIcon(
                        kind: TrayIconKind.pngBytes,
                        pngBytes: bytes,
                        symbolic: false,
                      ),
                    ),
                  ],
                ),
                onActivate: (_, _) {},
                onContextMenu: (_, _) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final Image image = tester.widget<Image>(find.byType(Image));
      final ResizeImage resized = image.image as ResizeImage;
      expect(resized.width, 29);
      return resized.imageProvider as MemoryImage;
    }

    final MemoryImage first = await show(red);
    final MemoryImage unchanged = await show(List<int>.of(red));
    expect(identical(unchanged.bytes, first.bytes), isTrue);

    final MemoryImage changed = await show(green);
    expect(identical(changed.bytes, first.bytes), isFalse);
    expect(tester.takeException(), isNull);
  });
}
