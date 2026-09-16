import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/native/layer_shell_api.g.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:hyprbaric_widgetbook/audio/docs_bar_preview.dart';
import 'package:hyprbaric_widgetbook/audio/site_module.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

const BasicMessageChannel<Object?> _regionChannel =
    BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.hyprbaric.NativeLayerShellHostApi.setRegion',
      NativeLayerShellHostApi.pigeonChannelCodec,
    );

/// Answers the region channel so dropdowns can open in tests, mirroring
/// `global_menu_test.dart`. Without a handler the position correction never
/// completes and menus stay shut.
void _answerRegionChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(_regionChannel.name, (ByteData? message) async {
        return _regionChannel.codec.encodeMessage(<Object?>[null]);
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(_regionChannel.name, null),
  );
}

void main() {
  setUp(_answerRegionChannel);

  test('destinations resolve against the reported site root', () {
    expect(
      DocsDestination.getStarted.resolve('/hyprbaric/'),
      '/hyprbaric/docs/intro',
    );
    expect(
      DocsDestination.modules.resolve('/hyprbaric/'),
      '/hyprbaric/#modules',
    );
    expect(DocsDestination.home.resolve('/'), '/');
    expect(
      DocsDestination.github.resolve('/hyprbaric/'),
      'https://github.com/asaphaaning/hyprbaric',
    );
  });

  test('item ids round-trip back to their destination', () {
    expect(
      DocsDestination.byItemId(const GlobalMenuItemIdDbusMenu(id: 102)),
      DocsDestination.getStarted,
    );
    expect(
      DocsDestination.byItemId(const GlobalMenuItemIdDbusMenu(id: 999)),
      isNull,
    );
  });

  testWidgets('the docs bar hangs docs navigation off the menu', (
    WidgetTester tester,
  ) async {
    await _pumpBar(tester, const DocsBarPreview());

    expect(find.text('Docs'), findsOneWidget);
    expect(find.text('Site'), findsOneWidget);
    expect(find.text('Project'), findsOneWidget);
    expect(find.text('hyprbaric'), findsOneWidget);
  });

  testWidgets('the workspace strip keeps a few indicators', (
    WidgetTester tester,
  ) async {
    await _pumpBar(tester, const DocsBarPreview());

    for (final int id in <int>[1, 2, 3, 4, 5]) {
      expect(
        find.byKey(ValueKey<String>('workspace-indicator-$id')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const ValueKey<String>('workspace-indicator-6')),
      findsNothing,
    );
  });

  testWidgets('workspace navigation visits sections and wraps at the ends', (
    WidgetTester tester,
  ) async {
    final List<String> navigated = <String>[];
    await _pumpBar(
      tester,
      DocsBarPreview(baseUrl: '/hyprbaric/', onNavigate: navigated.add),
    );

    for (final String label in <String>['II', 'III', 'IV', 'V', 'I']) {
      await tester.tap(find.text(label));
      await tester.pump();
    }
    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-nav-Previous workspace')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-nav-Next workspace')),
    );
    await tester.pump();

    expect(navigated, <String>[
      '/hyprbaric/#install',
      '/hyprbaric/#modules',
      '/hyprbaric/#desktop',
      '/hyprbaric/#config',
      '/hyprbaric/#hero',
      '/hyprbaric/#config',
      '/hyprbaric/#hero',
    ]);
    expect(find.text('VI'), findsNothing);
    expect(
      find.ancestor(of: find.text('hyprbaric'), matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(
      Theme.of(tester.element(find.text('hyprbaric'))).splashFactory,
      NoSplash.splashFactory,
    );
  });

  testWidgets('host section changes update the indicator without navigating', (
    tester,
  ) async {
    final List<String> navigated = <String>[];
    await _pumpBar(
      tester,
      DocsBarPreview(
        activeSection: DocsDestination.modules,
        onNavigate: navigated.add,
      ),
    );
    WorkspaceStrip strip = tester.widget(find.byType(WorkspaceStrip));
    expect(strip.resolution.activeWorkspaceId, 3);
    await _pumpBar(
      tester,
      DocsBarPreview(
        activeSection: DocsDestination.installer,
        onNavigate: navigated.add,
      ),
    );
    strip = tester.widget(find.byType(WorkspaceStrip));
    expect(strip.resolution.activeWorkspaceId, 2);
    expect(navigated, isEmpty);
  });

  testWidgets('module shortcuts show introductions and navigate to modules', (
    tester,
  ) async {
    final List<String> navigated = <String>[];
    final List<ModuleHint?> hints = <ModuleHint?>[];
    await _pumpBar(
      tester,
      DocsBarPreview(
        baseUrl: '/hyprbaric/',
        onNavigate: navigated.add,
        onModuleHint: hints.add,
      ),
    );
    final TestGesture pointer = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await pointer.addPointer(location: Offset.zero);
    addTearDown(pointer.removePointer);
    await tester.pump();

    for (final SiteModule module in SiteModule.values) {
      final Finder button = find.byWidgetPredicate(
        (widget) => widget is SiteModuleButton && widget.module == module,
      );
      await pointer.moveTo(tester.getCenter(button));
      await tester.pump();
      expect(hints.last?.module, module);
      expect(hints.last?.rect.isEmpty, isFalse);
      await tester.tap(button);
      await tester.pump();
    }
    expect(navigated, List<String>.filled(5, '/hyprbaric/#modules'));
    final SiteModuleButton first = tester.widget(
      find.byType(SiteModuleButton).first,
    );
    expect(first.module, SiteModule.network);
    expect(hints.last, isNull);
    expect(find.byType(AudioMixerIcon), findsNothing);
    expect(find.byIcon(Icons.battery_5_bar_rounded), findsNothing);
    expect(find.byIcon(Icons.tune_rounded), findsNothing);
    for (final IconData icon in <IconData>[
      Iconsax.link_copy,
      Iconsax.sun_1_copy,
      Iconsax.flash_circle_copy,
      Iconsax.setting_5_copy,
      Iconsax.notification_copy,
    ]) {
      expect(
        find.byKey(ValueKey<String>('iconsax-glyph-${icon.codePoint}')),
        findsOneWidget,
      );
    }
  });

  testWidgets('the centered title navigates home', (WidgetTester tester) async {
    final List<String> navigated = <String>[];

    await _pumpBar(
      tester,
      DocsBarPreview(baseUrl: '/hyprbaric/', onNavigate: navigated.add),
    );

    await tester.tap(find.text('hyprbaric'));
    await tester.pump();

    expect(navigated, <String>['/hyprbaric/']);
  });

  testWidgets('a menu row navigates to its docs route', (
    WidgetTester tester,
  ) async {
    final List<String> navigated = <String>[];

    await _pumpBar(
      tester,
      DocsBarPreview(baseUrl: '/hyprbaric/', onNavigate: navigated.add),
    );

    await tester.tap(find.text('Docs'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started').last);
    await tester.pump();

    expect(navigated, <String>['/hyprbaric/docs/intro']);
  });
  testWidgets('the search entry opens popular destinations', (
    WidgetTester tester,
  ) async {
    final List<String> navigated = <String>[];

    await _pumpBar(
      tester,
      DocsBarPreview(baseUrl: '/hyprbaric/', onNavigate: navigated.add),
    );

    await tester.tap(find.text('Search the docs'));
    await tester.pumpAndSettle();

    expect(find.text('POPULAR'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pump();

    expect(navigated, <String>['/hyprbaric/docs/intro']);
  });

  testWidgets('a fruitless query offers the full search page', (
    WidgetTester tester,
  ) async {
    final List<String> navigated = <String>[];

    await _pumpBar(
      tester,
      DocsBarPreview(baseUrl: '/hyprbaric/', onNavigate: navigated.add),
    );

    // The index fetch needs a browser, so under test every query misses.
    await tester.tap(find.text('Search the docs'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hyprsunset');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No results for "hyprsunset"'), findsOneWidget);
    await tester.tap(find.text('Open full search'));
    await tester.pump();

    expect(navigated, <String>['/hyprbaric/search']);
  });

  testWidgets('the clock opens a calendar that walks months', (
    WidgetTester tester,
  ) async {
    await _pumpBar(tester, const DocsBarPreview());

    await tester.tap(find.byType(ClockButton));
    await tester.pumpAndSettle();

    expect(find.byType(ClockPanel), findsOneWidget);
    final String before = tester
        .widget<ClockPanel>(find.byType(ClockPanel))
        .status
        .monthLabel;

    await tester.tap(
      find.byKey(const ValueKey<String>('calendar-nav-Next month')),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<ClockPanel>(find.byType(ClockPanel)).status.monthLabel,
      isNot(before),
    );
  });

  testWidgets('hovering calendar month buttons does not throw', (
    WidgetTester tester,
  ) async {
    await _pumpBar(tester, const DocsBarPreview());

    await tester.tap(find.byType(ClockButton));
    await tester.pumpAndSettle();

    final TestGesture gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    final Offset previous = tester.getCenter(
      find.byKey(const ValueKey<String>('calendar-nav-Previous month')),
    );
    final Offset today = tester.getCenter(
      find.byKey(const ValueKey<String>('calendar-nav-Today')),
    );
    final Offset next = tester.getCenter(
      find.byKey(const ValueKey<String>('calendar-nav-Next month')),
    );

    for (final Offset position in <Offset>[
      previous,
      today,
      previous,
      today,
      next,
    ]) {
      await gesture.moveTo(position);
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('the open menu region is reported for page frost', (
    WidgetTester tester,
  ) async {
    final List<LayerShellMenuRegion?> regions = <LayerShellMenuRegion?>[];

    await _pumpBar(
      tester,
      DocsBarPreview(baseUrl: '/hyprbaric/', onMenuRect: regions.add),
    );
    await tester.pumpAndSettle();

    // Closed bar, so the last report carries no region.
    expect(regions.last, isNull);

    await tester.tap(find.text('Docs'));
    await tester.pumpAndSettle();

    final LayerShellMenuRegion? open = regions.last;
    expect(open, isNotNull);
    expect(open!.rect.width, greaterThan(200));
    expect(open.rect.height, greaterThan(200));

    await tester.tap(find.text('Docs'));
    await tester.pumpAndSettle();

    expect(regions.last, isNull);
  });
}

/// Pumps the bar at a desktop viewport, which is how the site embeds it.
///
/// The bar fills its host like it fills a monitor; at the 800px test default
/// the clusters squeeze past what fits and the headings stop hit-testing.
Future<void> _pumpBar(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}
