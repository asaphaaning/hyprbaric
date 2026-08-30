import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/features/controls/controls_chrome.dart';
import 'package:hyprbaric/src/widgets/hypr_surface.dart';

void main() {
  testWidgets('control chassis preserves translucent popover framing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ControlChassis(
            borderRadius: BorderRadius.circular(16),
            constraints: const BoxConstraints.tightFor(width: 200),
            padding: EdgeInsets.zero,
            child: const SizedBox(width: 200, height: 300),
          ),
        ),
      ),
    );

    final HyprPopoverSurface surface = tester.widget<HyprPopoverSurface>(
      find.byType(HyprPopoverSurface),
    );
    final DecoratedBox chassis = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(ControlChassis),
            matching: find.byType(DecoratedBox),
          ),
        )
        .last;
    final BoxDecoration decoration = chassis.decoration as BoxDecoration;
    final LinearGradient gradient = decoration.gradient! as LinearGradient;

    expect(surface.color, Colors.transparent);
    expect(surface.borderColor, HyprColors.popupStroke);
    expect(gradient.colors, <Color>[
      ControlColors.chassisTop,
      ControlColors.chassisBottom,
    ]);
    expect(gradient.colors.every((Color color) => color.a < 0.5), isTrue);
  });
}
