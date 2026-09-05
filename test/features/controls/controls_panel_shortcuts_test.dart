import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/bindings/bindings.dart';
import 'package:hyprbaric/src/features/controls/controls_panel.dart';
import 'package:hyprbaric/src/state/rust_signals.dart';

void main() {
  testWidgets('control faces stamp the user\'s configured chords', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _panel(
        shortcutLabels: const <ShortcutSettingId, String>{
          ShortcutSettingId.captureRegion: 'Super+Shift+S',
          ShortcutSettingId.captureWindow: 'Super+Print',
          ShortcutSettingId.captureFullScreen: 'Print',
          ShortcutSettingId.colorPick: 'Super+Shift+P',
          ShortcutSettingId.toggleRecording: 'Super+Shift+R',
          ShortcutSettingId.barSettings: 'Super+Shift+C',
        },
      ),
    );
    await tester.pump();

    expect(find.text('Super+Shift+S'), findsOneWidget);
    expect(find.text('Super+Print'), findsOneWidget);
    expect(find.text('Print'), findsOneWidget);
    expect(find.text('Super+Shift+P'), findsOneWidget);
    expect(find.text('Super+Shift+R'), findsOneWidget);
    expect(find.text('Super+Shift+C'), findsOneWidget);
  });

  testWidgets('a control with no known binding stamps no chord at all', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _panel(
        shortcutLabels: const <ShortcutSettingId, String>{
          ShortcutSettingId.captureRegion: 'Super+Shift+S',
        },
      ),
    );
    await tester.pump();

    // Everything else the panel used to hardcode is simply absent rather than
    // guessed: a wrong chord teaches the user a keystroke that does nothing.
    expect(find.text('Super+Shift+S'), findsOneWidget);
    expect(find.textContaining('Mod'), findsNothing);
    expect(find.text('PrtSc'), findsNothing);
    expect(find.text('MAGNIFY'), findsOneWidget);
  });

  testWidgets('an overlong user chord ellipsises instead of overflowing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _panel(
        shortcutLabels: const <ShortcutSettingId, String>{
          ShortcutSettingId.barSettings:
              'Super+Ctrl+Alt+Shift+Num+BACKSLASH_AND_THEN_SOME',
          ShortcutSettingId.captureRegion:
              'Super+Ctrl+Alt+Shift+Num+BACKSLASH_AND_THEN_SOME',
        },
      ),
    );
    await tester.pump();

    // Chords are user configurable, so a long one must not blow out the row.
    expect(tester.takeException(), isNull);
  });

  test('a bound chord renders in the console\'s short spelling', () {
    const ShortcutBindingView binding = ShortcutBindingView(
      phase: ShortcutBindingPhase.press,
      modifiers: <ShortcutModifier>[
        ShortcutModifier.logo,
        ShortcutModifier.shift,
      ],
      key: 'S',
      display: 'LOGO+SHIFT+S',
    );

    expect(shortcutChordLabel(binding), 'Super+Shift+S');
  });
}

Widget _panel({required Map<ShortcutSettingId, String> shortcutLabels}) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ControlsPanel(
          borderRadius: BorderRadius.circular(18),
          onCaptureScreenshot: (_) {},
          onPickColor: () {},
          onToggleRecording: () {},
          onOpenSettings: () {},
          onToast: (_) {},
          dndEnabled: false,
          onSetDoNotDisturb: (_) {},
          nightLightStatus: const NightLightStatusAvailable(
            enabled: false,
            temperature: 3500,
          ),
          onSetNightLight: (_) {},
          caffeineStatus: const CaffeineStatusAvailable(enabled: false),
          onSetCaffeine: (_) {},
          recordingStatus: const RecordingStatusIdle(),
          shortcutLabels: shortcutLabels,
        ),
      ),
    ),
  );
}
