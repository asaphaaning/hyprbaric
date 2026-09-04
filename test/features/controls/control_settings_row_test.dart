import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/features/controls/control_settings_row.dart';

void main() {
  testWidgets('settings gasket stays flat around the dimensional face', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: ControlSettingsRow(onPressed: _ignore)),
      ),
    );

    final DecoratedBox frame = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('control-settings-frame')),
    );
    final ShapeDecoration frameDecoration = frame.decoration as ShapeDecoration;
    final AnimatedContainer face = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey<String>('control-settings-face')),
    );
    final ShapeDecoration faceDecoration = face.decoration! as ShapeDecoration;

    // The gasket is a single flat slab: one solid tone, no gradient and no
    // drop shadow to lift it off the tray.
    expect(frameDecoration.color, const Color(0xFF16181D));
    expect(frameDecoration.gradient, isNull);
    expect(frameDecoration.shadows, isNull);

    // All of the face's lighting rides in its gradient; inner shadows offset
    // the wrong way in Flutter, so none are used.
    expect(faceDecoration.gradient, isA<LinearGradient>());
    expect(faceDecoration.shadows, isNull);
  });

  testWidgets('the settings row shows a chord only when one is bound', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: ControlSettingsRow(onPressed: _ignore)),
      ),
    );

    expect(find.text('BAR SETTINGS'), findsOneWidget);
    expect(find.text('Super+⇧+C'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: ControlSettingsRow(onPressed: _ignore, shortcut: 'Super+⇧+C'),
        ),
      ),
    );

    expect(find.text('Super+⇧+C'), findsOneWidget);
  });

  testWidgets('the settings row announces itself as one button', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: ControlSettingsRow(onPressed: _ignore, shortcut: 'Super+⇧+C'),
        ),
      ),
    );

    // The authored label is the whole announcement: the caption, the chord
    // hint and the chevron underneath it must not be read out with it.
    expect(find.bySemanticsLabel('Bar settings'), findsOneWidget);
    expect(find.bySemanticsLabel('BAR SETTINGS'), findsNothing);
    expect(find.bySemanticsLabel('Super+⇧+C'), findsNothing);

    handle.dispose();
  });
}

void _ignore() {}
