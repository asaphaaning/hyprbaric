import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/widgets/hypr_surface.dart';
import 'package:hyprbaric/src/widgets/primitives/primitives.dart';

void main() {
  testWidgets('HyprToggleSwitch aligns the thumb from left to right', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              HyprToggleSwitch(value: false),
              HyprToggleSwitch(value: true),
            ],
          ),
        ),
      ),
    );

    final List<Align> aligns = tester
        .widgetList<Align>(find.byType(Align))
        .where(
          (Align align) =>
              align.alignment == Alignment.centerLeft ||
              align.alignment == Alignment.centerRight,
        )
        .toList();

    expect(aligns[0].alignment, Alignment.centerLeft);
    expect(aligns[1].alignment, Alignment.centerRight);
  });

  testWidgets('HyprMetricCard renders label, value, unit, and detail', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HyprMetricCard(
            label: 'UP',
            value: '12.3',
            unit: 'MB/s',
            detail: '1.2 GB tx',
          ),
        ),
      ),
    );

    expect(find.text('UP'), findsOneWidget);
    expect(find.text('1.2 GB tx'), findsOneWidget);
    final Iterable<RichText> richTexts = tester.widgetList<RichText>(
      find.descendant(
        of: find.byType(HyprMetricCard),
        matching: find.byType(RichText),
      ),
    );
    final RichText rich = richTexts.firstWhere((RichText candidate) {
      final InlineSpan text = candidate.text;
      return text is TextSpan &&
          text.children?.whereType<TextSpan>().any(
                (TextSpan span) => span.text == '12.3',
              ) ==
              true;
    });
    final TextSpan root = rich.text as TextSpan;
    expect(
      root.children?.whereType<TextSpan>().map((TextSpan span) => span.text),
      containsAll(<String>['12.3', 'MB/s']),
    );
  });

  testWidgets('HyprInteractiveTile reports hover and press state', (
    WidgetTester tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: HyprInteractiveTile(
              onPressed: () => taps += 1,
              color: Colors.black,
              hoverColor: Colors.white,
              selectedColor: Colors.blue,
              builder: (BuildContext context, HyprInteractiveTileState state) =>
                  Text(
                    '${state.hovered ? 'hover' : 'idle'}:'
                    '${state.pressed ? 'down' : 'up'}',
                  ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('idle:up'), findsOneWidget);

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(HyprInteractiveTile)));
    await tester.pumpAndSettle();
    expect(find.text('hover:up'), findsOneWidget);

    final TestGesture press = await tester.press(
      find.byType(HyprInteractiveTile),
    );
    await tester.pump();
    expect(find.text('hover:down'), findsOneWidget);

    await press.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    await mouse.removePointer();
  });

  testWidgets('HyprCommandButton keeps confirmation text visible', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HyprCommandButton(
            label: 'Confirm Shutdown',
            onPressed: () {},
            variant: HyprCommandButtonVariant.danger,
          ),
        ),
      ),
    );

    final Text text = tester.widget<Text>(find.text('Confirm Shutdown'));
    expect(text.softWrap, isTrue);
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.visible);
  });

  testWidgets('HyprTextFieldChrome reacts to focus changes', (
    WidgetTester tester,
  ) async {
    final FocusNode focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HyprTextFieldChrome(
            focusNode: focusNode,
            borderColor: Colors.red,
            focusedBorderColor: Colors.blue,
            child: SizedBox(
              width: 120,
              child: TextField(
                focusNode: focusNode,
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),
          ),
        ),
      ),
    );

    ShapeDecoration decoration =
        tester
                .widget<AnimatedContainer>(find.byType(AnimatedContainer).last)
                .decoration!
            as ShapeDecoration;
    RoundedSuperellipseBorder shape =
        decoration.shape as RoundedSuperellipseBorder;
    expect(shape.side.color, Colors.red);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    decoration =
        tester
                .widget<AnimatedContainer>(find.byType(AnimatedContainer).last)
                .decoration!
            as ShapeDecoration;
    shape = decoration.shape as RoundedSuperellipseBorder;
    expect(shape.side.color, Colors.blue);
  });

  testWidgets('HyprInlineTag renders uppercase labels', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              HyprInlineTag(label: 'github'),
              HyprInlineTag(label: 'live'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('GITHUB'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
  });

  testWidgets('HyprBracketedTag renders uppercase bracketed label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HyprBracketedTag(label: 'discord', accent: HyprColors.accent),
        ),
      ),
    );

    expect(find.text('<'), findsOneWidget);
    expect(find.text('DISCORD'), findsOneWidget);
    expect(find.text('>'), findsOneWidget);
  });
}
