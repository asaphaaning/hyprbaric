import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:hyprbaric_widgetbook/catalog/catalog_theme.dart';
import 'package:hyprbaric_widgetbook/use_cases/motion/motion_use_cases.dart';

void main() {
  testWidgets('rapid value changes settle on the newest content', (
    tester,
  ) async {
    for (var value = 0; value < 16; value++) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                HyprTextSwap(child: Text('App $value', key: ValueKey(value))),
                HyprDigitPop(
                  value: '$value',
                  style: const TextStyle(fontSize: 30),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 25));
    }
    await tester.pumpAndSettle();
    expect(find.text('App 15'), findsOneWidget);
    expect(find.text('App 14'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('reduced motion immediately removes outgoing text', (
    tester,
  ) async {
    Future<void> render(String value, bool reduced) => tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Column(
            children: [
              HyprTextSwap(child: Text(value, key: ValueKey(value))),
              HyprDigitPop(value: value, style: const TextStyle(fontSize: 30)),
            ],
          ),
        ),
      ),
    );
    await render('10', false);
    await render('20', false);
    await tester.pump(const Duration(milliseconds: 40));
    await render('30', true);
    expect(find.text('30'), findsNWidgets(2));
    expect(find.byType(AnimatedSwitcher), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('banner stack limits depth and only front card accepts input', (
    tester,
  ) async {
    final tapped = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 400,
            child: HyprBannerStack(
              banners: [
                for (var id = 0; id < 5; id++)
                  HyprBanner(
                    id: id,
                    child: GestureDetector(
                      onTap: () => tapped.add(id),
                      child: ColoredBox(
                        color: Colors.black,
                        child: Text('Banner $id'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Banner 3'), findsNothing);
    await tester.tap(find.text('Banner 0'));
    expect(tapped, [0]);
    expect(find.text('Banner 1').hitTestable(), findsNothing);
  });

  testWidgets('test drive playback can be disposed without pending timers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: catalogTheme, home: const MotionPlayground()),
    );
    await tester.tap(find.text('Play all'));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('Pause'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
