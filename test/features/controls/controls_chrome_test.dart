import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/features/controls/control_capture_pads.dart';
import 'package:hyprbaric/src/features/controls/controls_chrome.dart';
import 'package:hyprbaric/src/widgets/hypr_surface.dart';
import 'package:hyprbaric/src/widgets/primitives/primitives.dart';

void main() {
  testWidgets('the controls panel sits on the shared popover contrast floor', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: HyprPopoverPanel(
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
    final DecoratedBox chassis = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(HyprPopoverSurface),
            matching: find.byType(DecoratedBox),
          )
          .last,
    );
    final BoxDecoration decoration = chassis.decoration as BoxDecoration;
    final LinearGradient gradient = decoration.gradient! as LinearGradient;

    // The console no longer carries a chassis tint of its own: it would
    // double-darken the shared popover tint underneath it.
    expect(surface.color, isNull);
    expect(
      tester.widget<HyprGlassSurface>(find.byType(HyprGlassSurface)).color,
      HyprColors.surfaceStrong,
    );
    expect(surface.borderColor, HyprColors.popupStroke);
    expect(gradient.colors, <Color>[
      HyprChassisRamp.console.top,
      HyprChassisRamp.console.bottom,
    ]);
  });

  test('console wells are lit from above', () {
    final ShapeDecoration decoration = controlWellDecoration();
    final LinearGradient gradient = decoration.gradient! as LinearGradient;

    expect(gradient.begin, Alignment.topCenter);
    expect(gradient.end, Alignment.bottomCenter);
    expect(
      gradient.colors.first.computeLuminance(),
      greaterThan(gradient.colors.last.computeLuminance()),
    );
  });

  test('console faces have a visible press step', () {
    const HyprInteractionState hovered = HyprInteractionState(
      hovered: true,
      pressed: false,
      enabled: true,
    );
    const HyprInteractionState pressed = HyprInteractionState(
      hovered: true,
      pressed: true,
      enabled: true,
    );

    // The rocker ramp is what makes press visible: reusing the tile ramp on a
    // face this dark leaves a delta of about 2/255.
    expect(
      controlFaceColor(
        hovered,
        rest: HyprConsoleColors.face,
        hover: HyprConsoleColors.faceHover,
        pressed: HyprConsoleColors.facePressed,
      ),
      HyprConsoleColors.faceHover,
    );
    expect(
      controlFaceColor(
        pressed,
        rest: HyprConsoleColors.face,
        hover: HyprConsoleColors.faceHover,
        pressed: HyprConsoleColors.facePressed,
      ),
      HyprConsoleColors.facePressed,
    );
    expect(
      (HyprConsoleColors.face.computeLuminance() -
              HyprConsoleColors.facePressed.computeLuminance())
          .abs(),
      greaterThan(
        (HyprConsoleColors.face.computeLuminance() -
                HyprConsoleColors.tilePressed.computeLuminance())
            .abs(),
      ),
    );
  });

  test('a disabled face never lights up', () {
    const HyprInteractionState state = HyprInteractionState(
      hovered: true,
      pressed: true,
      enabled: false,
    );

    expect(controlFaceColor(state), HyprConsoleColors.tile);
  });

  group('formatRecordingElapsed', () {
    test('reads 00:00 with no start stamp', () {
      expect(formatRecordingElapsed(null), '00:00');
    });

    test('formats minutes and seconds', () {
      final int startedAt = DateTime.now()
          .subtract(const Duration(minutes: 3, seconds: 7))
          .millisecondsSinceEpoch;

      expect(formatRecordingElapsed(startedAt), '03:07');
    });

    test('clamps a start stamp in the future to zero', () {
      final int startedAt = DateTime.now()
          .add(const Duration(seconds: 7))
          .millisecondsSinceEpoch;

      expect(formatRecordingElapsed(startedAt), '00:00');
    });

    test('saturates rather than widening past 99:59', () {
      final int startedAt = DateTime.now()
          .subtract(const Duration(hours: 4))
          .millisecondsSinceEpoch;

      expect(formatRecordingElapsed(startedAt), '99:59');
    });
  });
}
