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

    expect(frameDecoration.color, const Color(0xFF24262A));
    expect(frameDecoration.gradient, isNull);
    expect(frameDecoration.shadows, isNull);
    expect(faceDecoration.gradient, isA<LinearGradient>());
    expect(faceDecoration.shadows, isNotEmpty);
  });
}

void _ignore() {}
