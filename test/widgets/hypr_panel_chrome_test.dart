import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/widgets/hypr_surface.dart';
import 'package:hyprbaric/src/widgets/primitives/primitives.dart';

void main() {
  testWidgets(
    'HyprPopoverPanel applies popover surface constraints and padding',
    (WidgetTester tester) async {
      const BoxConstraints constraints = BoxConstraints(
        minWidth: 120,
        maxWidth: 120,
        maxHeight: 80,
      );
      const EdgeInsets padding = EdgeInsets.all(12);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyprPopoverPanel(
              borderRadius: BorderRadius.circular(10),
              constraints: constraints,
              padding: padding,
              child: const Text('panel'),
            ),
          ),
        ),
      );

      final HyprPopoverSurface surface = tester.widget<HyprPopoverSurface>(
        find.byType(HyprPopoverSurface),
      );
      final ConstrainedBox constrained = tester.widget<ConstrainedBox>(
        find.descendant(
          of: find.byType(HyprPopoverPanel),
          matching: find.byType(ConstrainedBox),
        ),
      );
      final Padding panelPadding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(HyprPopoverPanel),
          matching: find.byType(Padding),
        ),
      );

      expect(surface.color, HyprColors.popoverSurface);
      expect(surface.borderColor, HyprColors.popupStroke);
      expect(constrained.constraints, constraints);
      expect(panelPadding.padding, padding);
    },
  );

  testWidgets(
    'HyprSectionLabel uppercases text and can render a trailing line',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: HyprSectionLabel('Capture', trailingLine: true)),
        ),
      );

      expect(find.text('CAPTURE'), findsOneWidget);
      expect(find.byType(Row), findsOneWidget);
      expect(find.byType(Expanded), findsOneWidget);
    },
  );

  testWidgets('HyprPanelHeader renders title, subtitle, trailing, and action', (
    WidgetTester tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HyprPanelHeader(
            title: 'Notifications',
            subtitle: 'Latest events',
            uppercaseTitle: true,
            titleTrailing: const Text('3'),
            trailing: const Icon(Icons.close_rounded),
            actionLabel: 'clear all',
            onAction: () => taps += 1,
          ),
        ),
      ),
    );

    expect(find.text('NOTIFICATIONS'), findsOneWidget);
    expect(find.text('Latest events'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    await tester.tap(find.text('clear all'));
    expect(taps, 1);
  });

  testWidgets('HyprPanelDivider uses the provided divider color', (
    WidgetTester tester,
  ) async {
    const Color color = Color(0xFF123456);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: HyprPanelDivider(color: color)),
      ),
    );

    final DecoratedBox box = tester.widget<DecoratedBox>(
      find.byType(DecoratedBox),
    );
    final BoxDecoration decoration = box.decoration as BoxDecoration;
    final LinearGradient gradient = decoration.gradient! as LinearGradient;

    expect(gradient.colors, <Color>[
      const Color(0x00FFFFFF),
      color,
      const Color(0x00FFFFFF),
    ]);
  });

  testWidgets('HyprSectionBreak wraps a divider with configured spacing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: HyprSectionBreak(before: 7, after: 9)),
      ),
    );

    expect(find.byType(HyprPanelDivider), findsOneWidget);
    final List<SizedBox> boxes = tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .where((SizedBox box) => box.height == 7 || box.height == 9)
        .toList();
    expect(boxes, hasLength(2));
  });

  testWidgets(
    'HyprEmptyState renders optional symbol and transformed message',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HyprEmptyState(
              symbol: '◎',
              message: 'No New Notifications',
              messageTransform: (String value) => value.toLowerCase(),
              borderColor: HyprColors.popupStroke,
            ),
          ),
        ),
      );

      expect(find.text('◎'), findsOneWidget);
      expect(find.text('no new notifications'), findsOneWidget);
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final ShapeDecoration decoration = box.decoration as ShapeDecoration;
      final RoundedSuperellipseBorder shape =
          decoration.shape as RoundedSuperellipseBorder;
      expect(shape.side.color, HyprColors.popupStroke);
    },
  );
}
