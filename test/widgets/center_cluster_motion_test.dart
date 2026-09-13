import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/state/providers.dart';
import 'package:hyprbaric/src/widgets/center_cluster.dart';
import 'package:hyprbaric/src/widgets/motion/hypr_text_swap.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('title swaps stay bounded (reduced motion: $reduced)', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          currentWindowDisplayProvider.overrideWithValue(
            const FocusedWindowDisplay(appName: 'Firefox', title: 'First tab'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: const Center(
                child: SizedBox(
                  width: 260,
                  height: 36,
                  child: CenterCluster(maxWidth: 260),
                ),
              ),
            ),
          ),
        ),
      );
      for (var index = 0; index < 8; index++) {
        container.updateOverrides([
          currentWindowDisplayProvider.overrideWithValue(
            FocusedWindowDisplay(
              appName: 'Terminal',
              title: 'A very long focused window title $index',
            ),
          ),
        ]);
        await tester.pump(const Duration(milliseconds: 25));
        expect(find.text('Firefox'), findsNothing);
        expect(find.text('Terminal'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(HyprTextSwap),
            matching: find.text('Terminal'),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(find.text('A very long focused window title 7'), findsOneWidget);
      expect(find.text('First tab'), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  }
}
