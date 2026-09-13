import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/widgets/motion/hypr_text_swap.dart';

void main() {
  Future<void> render(WidgetTester tester, String value) => tester.pumpWidget(
    MaterialApp(
      home: HyprTextSwap(child: Text(value, key: ValueKey(value))),
    ),
  );

  testWidgets('early interruption cancels and settles the newest content', (
    tester,
  ) async {
    await render(tester, 'First');
    await render(tester, 'Second');
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(FadeThroughTransition), findsNWidgets(2));
    await render(tester, 'Latest');
    expect(find.text('Latest'), findsOneWidget);
    expect(find.text('Second'), findsNothing);
    expect(find.byType(FadeThroughTransition), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('grace period finishes once and coalesces late updates', (
    tester,
  ) async {
    await render(tester, 'First');
    await render(tester, 'Second');
    await tester.pump(const Duration(milliseconds: 190));
    await render(tester, 'Third');
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('Third'), findsNothing);
    await render(tester, 'Latest');
    await tester.pump(const Duration(milliseconds: 31));
    expect(find.text('Latest'), findsOneWidget);
    expect(find.text('Second'), findsNothing);
    expect(find.text('Third'), findsNothing);
    expect(find.byType(FadeThroughTransition), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
