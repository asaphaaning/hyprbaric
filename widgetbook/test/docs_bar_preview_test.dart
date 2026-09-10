import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/native/layer_shell_api.g.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:hyprbaric_widgetbook/audio/docs_bar_preview.dart';

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
    expect(find.text('Hyprbaric'), findsOneWidget);
  });

  testWidgets('the centered title navigates home', (WidgetTester tester) async {
    final List<String> navigated = <String>[];

    await _pumpBar(
      tester,
      DocsBarPreview(baseUrl: '/hyprbaric/', onNavigate: navigated.add),
    );

    await tester.tap(find.text('Hyprbaric'));
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
