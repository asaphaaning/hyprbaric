import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/bindings/bindings.dart';
import 'package:hyprbaric/src/features/global_menu/global_menu_bar.dart';
import 'package:hyprbaric/src/features/global_menu/global_menu_section.dart';
import 'package:hyprbaric/src/features/rust_commands.dart';
import 'package:hyprbaric/src/native/layer_shell_api.g.dart';
import 'package:hyprbaric/src/state/rust_signals/compositor.dart';
import 'package:hyprbaric/src/state/rust_signals/global_menu.dart';
import 'package:hyprbaric/src/widgets/hypr_surface.dart';

const BasicMessageChannel<Object?> _regionChannel =
    BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.hyprbaric.NativeLayerShellHostApi.setRegion',
      NativeLayerShellHostApi.pigeonChannelCodec,
    );

/// Answers the region channel so the dropdown's position correction actually
/// iterates. Without a handler the call never completes, the correction runs
/// once, and a menu that chases its own position looks perfectly still.
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

class _RecordingDispatcher extends RustCommandDispatcher {
  final List<RustIntent> intents = <RustIntent>[];

  @override
  void dispatch(RustIntent intent) => intents.add(intent);
}

const GlobalMenuSectionId _file = GlobalMenuSectionIdDbusMenu(id: 1);
const GlobalMenuSectionId _edit = GlobalMenuSectionIdDbusMenu(id: 2);
const GlobalMenuSectionId _recent = GlobalMenuSectionIdDbusMenu(id: 20);

final GlobalMenuSession _session = GlobalMenuSession(
  generation: Uint64(BigInt.one),
  window: '0x1',
);
GlobalMenuAddress _address(GlobalMenuSectionId id) =>
    GlobalMenuAddress(session: _session, section: id);
final GlobalMenuStatus _twoHeadings = GlobalMenuStatus(
  session: _session,
  sections: const <GlobalMenuSection>[
    GlobalMenuSection(id: _file, label: 'File', enabled: true),
    GlobalMenuSection(id: _edit, label: 'Edit', enabled: true),
  ],
  message: null,
);

GlobalMenuItem _item({
  String label = '',
  GlobalMenuItemId? activation,
  GlobalMenuSectionId? submenu,
  GlobalMenuItemKind kind = const GlobalMenuItemKindStandard(),
  String? shortcut,
  bool enabled = true,
}) {
  return GlobalMenuItem(
    label: label,
    enabled: enabled,
    kind: kind,
    shortcut: shortcut,
    activation: activation,
    submenu: submenu,
  );
}

dynamic _section(GlobalMenuSectionId id, List<GlobalMenuItem> items) {
  return globalMenuSectionProvider(_address(id)).overrideWith(
    (ref) => Stream<GlobalMenuSectionStatus>.value(
      GlobalMenuSectionStatus(
        session: _session,
        section: id,
        items: items,
        message: null,
      ),
    ),
  );
}

Widget _surface({required Widget child, required List<dynamic> overrides}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'nested flyouts reach deep commands and dismiss all descendants',
    (tester) async {
      const third = GlobalMenuSectionIdDbusMenu(id: 30);
      const fourth = GlobalMenuSectionIdDbusMenu(id: 40);
      final dispatcher = _RecordingDispatcher();
      await tester.pumpWidget(
        _surface(
          overrides: [
            rustCommandDispatcherProvider.overrideWith((ref) => dispatcher),
            _section(_file, [_item(label: 'Recent', submenu: _recent)]),
            _section(_recent, [_item(label: 'Projects', submenu: third)]),
            _section(third, [_item(label: 'Archives', submenu: fourth)]),
            _section(fourth, [
              _item(
                label: 'Deep command',
                activation: const GlobalMenuItemIdDbusMenu(id: 41),
              ),
            ]),
          ],
          child: GlobalMenuSectionPanel(
            session: _session,
            section: _file,
            onActivated: () {},
          ),
        ),
      );
      await tester.pump();
      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: Offset.zero);
      addTearDown(pointer.removePointer);
      for (final label in ['Recent', 'Projects', 'Archives']) {
        await pointer.moveTo(tester.getCenter(find.text(label)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Deep command'), findsOneWidget);
      await tester.tap(find.text('Deep command'));
      expect(dispatcher.intents.last.debugLabel, 'global_menu_activate');
      final before = dispatcher.intents.length;
      await tester.pumpWidget(const SizedBox());
      final dismissals = dispatcher.intents
          .skip(before)
          .where((intent) => intent.debugLabel == 'global_menu_dismiss')
          .toList();
      expect(dismissals, hasLength(3));
    },
  );

  testWidgets('changing an ancestor submenu removes every deeper panel', (
    tester,
  ) async {
    const third = GlobalMenuSectionIdDbusMenu(id: 30);
    final dispatcher = _RecordingDispatcher();
    await tester.pumpWidget(
      _surface(
        overrides: [
          rustCommandDispatcherProvider.overrideWith((ref) => dispatcher),
          _section(_file, [
            _item(label: 'Recent', submenu: _recent),
            _item(label: 'Other', submenu: _edit),
          ]),
          _section(_recent, [_item(label: 'Projects', submenu: third)]),
          _section(third, [_item(label: 'Deep row')]),
          _section(_edit, [_item(label: 'Other row')]),
        ],
        child: GlobalMenuSectionPanel(
          session: _session,
          section: _file,
          onActivated: () {},
        ),
      ),
    );
    await tester.pump();
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: Offset.zero);
    addTearDown(pointer.removePointer);
    for (final label in ['Recent', 'Projects']) {
      await pointer.moveTo(tester.getCenter(find.text(label)));
      await tester.pumpAndSettle();
    }
    final horizontal = tester.widget<SingleChildScrollView>(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
    );
    horizontal.controller!.jumpTo(0);
    await tester.pump();
    await pointer.moveTo(tester.getCenter(find.text('Other')));
    await tester.pumpAndSettle();
    expect(find.text('Other row'), findsOneWidget);
    expect(find.text('Deep row'), findsNothing);
    expect(find.text('Projects'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('GTK row removal replaces the open rows and cached snapshot', () async {
    const section = GlobalMenuSectionIdGtk(group: 0, menu: 1);
    final container = ProviderContainer(
      overrides: [
        globalMenuStatusProvider.overrideWith(
          (ref) => Stream.value(_twoHeadings),
        ),
      ],
    );
    addTearDown(container.dispose);
    final cache = container.listen(globalMenuSectionCacheProvider, (_, _) {});
    addTearDown(cache.close);
    await container.read(globalMenuStatusProvider.future);
    final provider = globalMenuSectionProvider(_address(section));
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);
    void publish(List<GlobalMenuItem> items) =>
        assignRustSignal['GlobalMenuSectionStatus']!(
          GlobalMenuSectionStatus(
            session: _session,
            section: section,
            items: items,
          ).bincodeSerialize(),
          Uint8List(0),
        );
    publish([_item(label: 'Removed row')]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(provider).value?.items, hasLength(1));
    publish([]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(provider).value?.items, isEmpty);
    expect(
      container.read(globalMenuSectionCacheProvider)[_address(section)]?.items,
      isEmpty,
    );
  });

  test(
    'late D-BusMenu replies cannot refill a dismissed popup cache',
    () async {
      final container = ProviderContainer(
        overrides: [
          globalMenuStatusProvider.overrideWith(
            (ref) => Stream.value(_twoHeadings),
          ),
        ],
      );
      addTearDown(container.dispose);
      final cache = container.listen(globalMenuSectionCacheProvider, (_, _) {});
      addTearDown(cache.close);
      await container.read(globalMenuStatusProvider.future);
      container
          .read(globalMenuSectionCacheProvider.notifier)
          .forget(_address(_file));
      assignRustSignal['GlobalMenuSectionStatus']!(
        GlobalMenuSectionStatus(
          session: _session,
          section: _file,
          items: [_item(label: 'Late row')],
        ).bincodeSerialize(),
        Uint8List(0),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(globalMenuSectionCacheProvider), isEmpty);
    },
  );

  testWidgets(
    'window identity refreshes same-app menus but title edits do not',
    (tester) async {
      final focus = StreamController<FocusedWindowStatus>();
      final dispatcher = _RecordingDispatcher();
      addTearDown(focus.close);
      await tester.pumpWidget(
        _surface(
          overrides: [
            rustCommandDispatcherProvider.overrideWith((ref) => dispatcher),
            focusedWindowStatusProvider.overrideWith((ref) => focus.stream),
            globalMenuStatusProvider.overrideWith(
              (ref) => Stream.value(_twoHeadings.copyWith(window: () => '0x1')),
            ),
          ],
          child: const SizedBox(width: 500, child: GlobalMenuBar()),
        ),
      );
      await tester.pump();
      void focused(String address, String title) => focus.add(
        FocusedWindowStatus(
          address: address,
          appName: 'editor',
          title: title,
          hostname: 'host',
          monitors: const [],
        ),
      );
      int requests() => dispatcher.intents
          .where((intent) => intent.debugLabel == 'global_menu_refresh')
          .length;
      focused('0x1', 'Document A');
      await tester.pump();
      await tester.pump();
      final before = requests();
      focused('0x1', 'Document A *');
      await tester.pump();
      expect(requests(), before);
      focused('0x2', 'Document B');
      await tester.pump();
      await tester.pump();
      expect(requests(), before + 1);
      expect(find.text('File'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('long menu scrolls to and activates its last command', (
    tester,
  ) async {
    final dispatcher = _RecordingDispatcher();
    await tester.pumpWidget(
      _surface(
        overrides: [
          rustCommandDispatcherProvider.overrideWith((ref) => dispatcher),
          _section(
            _file,
            List.generate(
              50,
              (index) => _item(
                label: 'Bookmark $index',
                activation: GlobalMenuItemIdDbusMenu(id: index + 100),
              ),
            ),
          ),
        ],
        child: GlobalMenuSectionPanel(
          session: _session,
          section: _file,
          onActivated: () {},
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.vertical,
      ),
      const Offset(0, -1800),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookmark 49'));
    expect(dispatcher.intents.last.debugLabel, 'global_menu_activate');
    expect(tester.takeException(), isNull);
  });

  test('closing a section evicts its rows and stream state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final provider = globalMenuSectionProvider(_address(_file));
    final subscription = container.listen(provider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    assignRustSignal['GlobalMenuSectionStatus']!(
      GlobalMenuSectionStatus(
        session: _session,
        section: _file,
        items: [_item(label: 'Old row')],
      ).bincodeSerialize(),
      Uint8List(0),
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(provider).value?.items.single.label, 'Old row');
    subscription.close();
    container
        .read(globalMenuSectionCacheProvider.notifier)
        .forget(_address(_file));
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(container.exists(provider), isFalse);
    expect(container.read(provider).asData?.value, isNull);
  });

  testWidgets('late rows from another session never replace an open section', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final provider = globalMenuSectionProvider(_address(_file));
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await tester.pump();
    final current = GlobalMenuSectionStatus(
      session: _session,
      section: _file,
      items: [_item(label: 'Current row')],
    );
    assignRustSignal['GlobalMenuSectionStatus']!(
      current.bincodeSerialize(),
      Uint8List(0),
    );
    await tester.pump();
    final foreign = current.copyWith(
      session: GlobalMenuSession(generation: Uint64(BigInt.two), window: '0x2'),
      items: [_item(label: 'Foreign row')],
    );
    assignRustSignal['GlobalMenuSectionStatus']!(
      foreign.bincodeSerialize(),
      Uint8List(0),
    );
    await tester.pump();
    expect(container.read(provider).value?.items.single.label, 'Current row');
  });

  testWidgets('a section shows its rows, accelerators and marks', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _surface(
        overrides: [
          _section(_file, <GlobalMenuItem>[
            _item(
              label: 'New File',
              activation: const GlobalMenuItemIdDbusMenu(id: 2),
              shortcut: 'Ctrl+N',
            ),
            _item(
              label: 'Word Wrap',
              activation: const GlobalMenuItemIdDbusMenu(id: 3),
              kind: const GlobalMenuItemKindCheckmark(checked: true),
            ),
          ]),
        ],
        child: GlobalMenuSectionPanel(
          session: _session,
          section: _file,
          onActivated: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('New File'), findsOneWidget);
    expect(find.text('Ctrl N'), findsOneWidget);
    expect(find.text('✓'), findsOneWidget);
  });

  testWidgets('a divider only sits between two rows', (
    WidgetTester tester,
  ) async {
    const Key divider = Key('global-menu-separator');
    await tester.pumpWidget(
      _surface(
        overrides: [
          _section(_file, <GlobalMenuItem>[
            _item(kind: const GlobalMenuItemKindSeparator()),
            _item(
              label: 'Sidebar',
              submenu: const GlobalMenuSectionIdDbusMenu(id: 30),
            ),
            _item(kind: const GlobalMenuItemKindSeparator()),
            _item(kind: const GlobalMenuItemKindSeparator()),
            _item(
              label: 'Full Screen',
              activation: const GlobalMenuItemIdDbusMenu(id: 2),
              shortcut: 'F11',
            ),
            _item(kind: const GlobalMenuItemKindSeparator()),
          ]),
        ],
        child: GlobalMenuSectionPanel(
          session: _session,
          section: _file,
          onActivated: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sidebar'), findsOneWidget);
    expect(find.text('Full Screen'), findsOneWidget);
    expect(find.byKey(divider), findsOneWidget);
  });

  testWidgets('a menu of only dividers is empty', (WidgetTester tester) async {
    await tester.pumpWidget(
      _surface(
        overrides: [
          _section(_file, <GlobalMenuItem>[
            _item(kind: const GlobalMenuItemKindSeparator()),
            _item(kind: const GlobalMenuItemKindSeparator()),
          ]),
        ],
        child: GlobalMenuSectionPanel(
          session: _session,
          section: _file,
          onActivated: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No entries'), findsOneWidget);
    expect(find.byKey(const Key('global-menu-separator')), findsNothing);
  });

  testWidgets('a long page title ellipsizes instead of overflowing the panel', (
    WidgetTester tester,
  ) async {
    const String title =
        'Hyprbaric documentation — a very long Firefox history entry that must not overflow the menu panel';

    await tester.pumpWidget(
      _surface(
        overrides: [
          _section(_file, <GlobalMenuItem>[
            _item(
              label: title,
              activation: const GlobalMenuItemIdDbusMenu(id: 2),
            ),
          ]),
        ],
        child: GlobalMenuSectionPanel(
          session: _session,
          section: _file,
          onActivated: () {},
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final Text label = tester.widget<Text>(find.text(title));
    expect(label.overflow, TextOverflow.ellipsis);
  });

  testWidgets(
    'accelerators sit on the right of the panel, not against the label',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _surface(
          overrides: [
            _section(_file, <GlobalMenuItem>[
              _item(
                label: 'New File',
                activation: const GlobalMenuItemIdDbusMenu(id: 2),
                shortcut: 'Ctrl+N',
              ),
            ]),
          ],
          child: GlobalMenuSectionPanel(
            session: _session,
            section: _file,
            onActivated: () {},
          ),
        ),
      );
      await tester.pump();

      final double labelRight = tester.getTopRight(find.text('New File')).dx;
      final double keyLeft = tester.getTopLeft(find.text('Ctrl N')).dx;
      expect(keyLeft, greaterThan(labelRight + 16));
    },
  );

  testWidgets('a menu uses the popover chassis without a drop shadow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _surface(
        overrides: [
          _section(_file, <GlobalMenuItem>[
            _item(
              label: 'New File',
              activation: const GlobalMenuItemIdDbusMenu(id: 2),
            ),
          ]),
        ],
        child: GlobalMenuSectionPanel(
          session: _session,
          section: _file,
          onActivated: () {},
        ),
      ),
    );
    await tester.pump();

    final HyprPopoverSurface surface = tester.widget<HyprPopoverSurface>(
      find.byType(HyprPopoverSurface),
    );
    expect(
      surface.color,
      HyprColors.surfaceStrong.withValues(
        alpha: HyprColors.surfaceStrong.a * 0.84,
      ),
    );
    expect(surface.overlayOpacity, 0.84);
    expect(surface.shadow, isFalse);

    final Iterable<BoxDecoration> shadowed = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((DecoratedBox box) => box.decoration)
        .whereType<BoxDecoration>()
        .where(
          (BoxDecoration decoration) =>
              decoration.boxShadow != null && decoration.boxShadow!.isNotEmpty,
        );
    expect(shadowed, isEmpty);
  });

  testWidgets('activating a row sends its identifier and closes the menu', (
    WidgetTester tester,
  ) async {
    final _RecordingDispatcher dispatcher = _RecordingDispatcher();
    bool closed = false;

    await tester.pumpWidget(
      _surface(
        overrides: [
          rustCommandDispatcherProvider.overrideWith((ref) => dispatcher),
          _section(_file, <GlobalMenuItem>[
            _item(
              label: 'New File',
              activation: const GlobalMenuItemIdDbusMenu(id: 7),
            ),
          ]),
        ],
        child: GlobalMenuSectionPanel(
          session: _session,
          section: _file,
          onActivated: () => closed = true,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('New File'));
    await tester.pump();

    expect(closed, isTrue);
    expect(dispatcher.intents, hasLength(1));
    expect(dispatcher.intents.single.debugLabel, 'global_menu_activate');
  });

  testWidgets('toggling a checkmark leaves the menu open', (
    WidgetTester tester,
  ) async {
    final _RecordingDispatcher dispatcher = _RecordingDispatcher();
    bool closed = false;

    await tester.pumpWidget(
      _surface(
        overrides: [
          rustCommandDispatcherProvider.overrideWith((ref) => dispatcher),
          _section(_file, <GlobalMenuItem>[
            _item(
              label: 'Bookmarks Toolbar',
              activation: const GlobalMenuItemIdDbusMenu(id: 12),
              kind: const GlobalMenuItemKindCheckmark(checked: false),
            ),
          ]),
        ],
        child: GlobalMenuSectionPanel(
          session: _session,
          section: _file,
          onActivated: () => closed = true,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Bookmarks Toolbar'));
    await tester.pump();

    expect(closed, isFalse);
    expect(dispatcher.intents.single.debugLabel, 'global_menu_activate');
  });

  testWidgets('a checkmark redraws when the application updates it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _surface(
        overrides: [
          globalMenuSectionProvider(_address(_file)).overrideWith((ref) async* {
            yield GlobalMenuSectionStatus(
              session: _session,
              section: _file,
              items: <GlobalMenuItem>[
                _item(
                  label: 'Bookmarks Toolbar',
                  activation: const GlobalMenuItemIdDbusMenu(id: 12),
                  kind: const GlobalMenuItemKindCheckmark(checked: false),
                ),
              ],
              message: null,
            );
            await Future<void>.delayed(const Duration(milliseconds: 1));
            yield GlobalMenuSectionStatus(
              session: _session,
              section: _file,
              items: <GlobalMenuItem>[
                _item(
                  label: 'Bookmarks Toolbar',
                  activation: const GlobalMenuItemIdDbusMenu(id: 12),
                  kind: const GlobalMenuItemKindCheckmark(checked: true),
                ),
              ],
              message: null,
            );
          }),
        ],
        child: GlobalMenuSectionPanel(
          session: _session,
          section: _file,
          onActivated: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Bookmarks Toolbar'), findsOneWidget);
    expect(find.text('✓'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('✓'), findsOneWidget);
  });

  testWidgets('a disabled row neither activates nor closes the menu', (
    WidgetTester tester,
  ) async {
    final _RecordingDispatcher dispatcher = _RecordingDispatcher();
    bool closed = false;

    await tester.pumpWidget(
      _surface(
        overrides: [
          rustCommandDispatcherProvider.overrideWith((ref) => dispatcher),
          _section(_file, <GlobalMenuItem>[
            _item(
              label: 'Undo',
              enabled: false,
              activation: const GlobalMenuItemIdDbusMenu(id: 9),
            ),
          ]),
        ],
        child: GlobalMenuSectionPanel(
          session: _session,
          section: _file,
          onActivated: () => closed = true,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Undo'));
    await tester.pump();

    expect(closed, isFalse);
    expect(dispatcher.intents, isEmpty);
  });

  testWidgets('hovering a submenu row opens its panel beside the menu', (
    WidgetTester tester,
  ) async {
    final _RecordingDispatcher dispatcher = _RecordingDispatcher();

    await tester.pumpWidget(
      _surface(
        overrides: [
          rustCommandDispatcherProvider.overrideWith((ref) => dispatcher),
          _section(_file, <GlobalMenuItem>[
            _item(label: 'Open Recent', submenu: _recent),
          ]),
          _section(_recent, <GlobalMenuItem>[
            _item(
              label: 'bar.tsx',
              activation: const GlobalMenuItemIdDbusMenu(id: 21),
            ),
          ]),
        ],
        child: GlobalMenuSectionPanel(
          session: _session,
          section: _file,
          onActivated: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('bar.tsx'), findsNothing);

    final TestGesture pointer = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await pointer.addPointer(location: Offset.zero);
    addTearDown(pointer.removePointer);
    await pointer.moveTo(tester.getCenter(find.text('Open Recent')));
    await tester.pumpAndSettle();

    expect(find.text('bar.tsx'), findsOneWidget);
    expect(
      dispatcher.intents.map((intent) => intent.debugLabel),
      contains('global_menu_open_section'),
    );
  });

  testWidgets('closing a heading tells the application the menu is gone', (
    WidgetTester tester,
  ) async {
    _answerRegionChannel();
    final _RecordingDispatcher dispatcher = _RecordingDispatcher();

    await tester.pumpWidget(
      _surface(
        overrides: [
          rustCommandDispatcherProvider.overrideWith((ref) => dispatcher),
          globalMenuStatusProvider.overrideWith(
            (ref) => Stream<GlobalMenuStatus>.value(_twoHeadings),
          ),
          _section(_file, <GlobalMenuItem>[
            _item(
              label: 'New File',
              activation: const GlobalMenuItemIdDbusMenu(id: 7),
            ),
          ]),
        ],
        child: const SizedBox(width: 600, child: GlobalMenuBar()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();

    expect(
      dispatcher.intents.map((intent) => intent.debugLabel),
      containsAllInOrder(<String>[
        'global_menu_open_section',
        'global_menu_dismiss',
      ]),
    );
  });

  testWidgets('activating a row clicks then closes the heading', (
    WidgetTester tester,
  ) async {
    _answerRegionChannel();
    final _RecordingDispatcher dispatcher = _RecordingDispatcher();

    await tester.pumpWidget(
      _surface(
        overrides: [
          rustCommandDispatcherProvider.overrideWith((ref) => dispatcher),
          globalMenuStatusProvider.overrideWith(
            (ref) => Stream<GlobalMenuStatus>.value(_twoHeadings),
          ),
          _section(_file, <GlobalMenuItem>[
            _item(
              label: 'New File',
              activation: const GlobalMenuItemIdDbusMenu(id: 7),
            ),
          ]),
        ],
        child: const SizedBox(width: 600, child: GlobalMenuBar()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New File'));
    await tester.pumpAndSettle();

    expect(
      dispatcher.intents.map((intent) => intent.debugLabel),
      containsAllInOrder(<String>[
        'global_menu_open_section',
        'global_menu_activate',
        'global_menu_dismiss',
      ]),
    );
  });

  testWidgets('toggling a checkmark does not dismiss the heading', (
    WidgetTester tester,
  ) async {
    _answerRegionChannel();
    final _RecordingDispatcher dispatcher = _RecordingDispatcher();

    await tester.pumpWidget(
      _surface(
        overrides: [
          rustCommandDispatcherProvider.overrideWith((ref) => dispatcher),
          globalMenuStatusProvider.overrideWith(
            (ref) => Stream<GlobalMenuStatus>.value(_twoHeadings),
          ),
          _section(_file, <GlobalMenuItem>[
            _item(
              label: 'Bookmarks Toolbar',
              activation: const GlobalMenuItemIdDbusMenu(id: 12),
              kind: const GlobalMenuItemKindCheckmark(checked: false),
            ),
          ]),
        ],
        child: const SizedBox(width: 600, child: GlobalMenuBar()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookmarks Toolbar'));
    await tester.pumpAndSettle();

    expect(
      dispatcher.intents.map((intent) => intent.debugLabel),
      containsAllInOrder(<String>[
        'global_menu_open_section',
        'global_menu_activate',
      ]),
    );
    expect(
      dispatcher.intents.map((intent) => intent.debugLabel),
      isNot(contains('global_menu_dismiss')),
    );
  });

  testWidgets('leaving a submenu tells the application that flyout closed', (
    WidgetTester tester,
  ) async {
    final _RecordingDispatcher dispatcher = _RecordingDispatcher();

    await tester.pumpWidget(
      _surface(
        overrides: [
          rustCommandDispatcherProvider.overrideWith((ref) => dispatcher),
          _section(_file, <GlobalMenuItem>[
            _item(label: 'Open Recent', submenu: _recent),
          ]),
          _section(_recent, <GlobalMenuItem>[
            _item(
              label: 'bar.tsx',
              activation: const GlobalMenuItemIdDbusMenu(id: 21),
            ),
          ]),
        ],
        child: GlobalMenuSectionPanel(
          session: _session,
          section: _file,
          onActivated: () {},
        ),
      ),
    );
    await tester.pump();

    final TestGesture pointer = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await pointer.addPointer(location: Offset.zero);
    addTearDown(pointer.removePointer);
    await pointer.moveTo(tester.getCenter(find.text('Open Recent')));
    await tester.pumpAndSettle();
    expect(find.text('bar.tsx'), findsOneWidget);

    await pointer.moveTo(const Offset(0, 600));
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();

    expect(
      dispatcher.intents.map((intent) => intent.debugLabel),
      containsAllInOrder(<String>[
        'global_menu_open_section',
        'global_menu_dismiss',
      ]),
    );
  });

  testWidgets('opening a submenu leaves the menu it came from where it was', (
    WidgetTester tester,
  ) async {
    _answerRegionChannel();
    await tester.pumpWidget(
      _surface(
        overrides: [
          rustCommandDispatcherProvider.overrideWith(
            (ref) => _RecordingDispatcher(),
          ),
          globalMenuStatusProvider.overrideWith(
            (ref) => Stream<GlobalMenuStatus>.value(_twoHeadings),
          ),
          _section(_file, <GlobalMenuItem>[
            _item(label: 'Open Recent', submenu: _recent),
          ]),
          _section(_recent, <GlobalMenuItem>[
            _item(
              label: 'bar.tsx',
              activation: const GlobalMenuItemIdDbusMenu(id: 21),
            ),
          ]),
        ],
        child: const SizedBox(width: 600, child: GlobalMenuBar()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();

    final Offset before = tester.getTopLeft(find.text('Open Recent'));

    final TestGesture pointer = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await pointer.addPointer(location: Offset.zero);
    addTearDown(pointer.removePointer);
    await pointer.moveTo(tester.getCenter(find.text('Open Recent')));
    await tester.pumpAndSettle();

    // The row under the pointer must still be the row the pointer chose. A
    // menu that shifts as it grows hands the click to whatever slid into its
    // place while the hand was still moving.
    expect(find.text('bar.tsx'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Open Recent')), before);
  });

  testWidgets('a named group is a caption, not a row', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _surface(
        overrides: [
          _section(_file, <GlobalMenuItem>[
            _item(label: 'Panels', kind: const GlobalMenuItemKindGroup()),
            _item(
              label: 'Project Panel',
              activation: const GlobalMenuItemIdDbusMenu(id: 2),
              kind: const GlobalMenuItemKindCheckmark(checked: true),
            ),
          ]),
        ],
        child: GlobalMenuSectionPanel(
          session: _session,
          section: _file,
          onActivated: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('PANELS'), findsOneWidget);
    expect(find.text('Project Panel'), findsOneWidget);
  });

  testWidgets('a selected radio is drawn as a checkmark', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _surface(
        overrides: [
          _section(_file, <GlobalMenuItem>[
            _item(
              label: 'One Dark',
              activation: const GlobalMenuItemIdDbusMenu(id: 2),
              kind: const GlobalMenuItemKindRadio(selected: true),
            ),
          ]),
        ],
        child: GlobalMenuSectionPanel(
          session: _session,
          section: _file,
          onActivated: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('✓'), findsOneWidget);
    expect(find.text('•'), findsNothing);
  });

  test('accelerators are spelled the way the v6 mock spells them', () {
    expect(formatGlobalMenuAccelerator('Ctrl+N'), 'Ctrl N');
    expect(formatGlobalMenuAccelerator('Ctrl+Shift+N'), 'Ctrl ⇧ N');
    expect(formatGlobalMenuAccelerator('Ctrl+Alt+Up'), 'Ctrl ⌥ ↑');
    expect(formatGlobalMenuAccelerator('Super+Shift+Space'), 'Mod ⇧ Space');
    expect(formatGlobalMenuAccelerator('Ctrl++'), 'Ctrl +');
    expect(formatGlobalMenuAccelerator('F11'), 'F11');
  });

  testWidgets('the bar renders a heading for every exported section', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _surface(
        overrides: [
          rustCommandDispatcherProvider.overrideWith(
            (ref) => _RecordingDispatcher(),
          ),
          globalMenuStatusProvider.overrideWith(
            (ref) => Stream<GlobalMenuStatus>.value(_twoHeadings),
          ),
        ],
        child: const SizedBox(width: 400, child: GlobalMenuBar()),
      ),
    );
    await tester.pump();

    expect(find.text('File'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);

    final AnimatedDefaultTextStyle heading = tester
        .widget<AnimatedDefaultTextStyle>(
          find
              .ancestor(
                of: find.text('File'),
                matching: find.byType(AnimatedDefaultTextStyle),
              )
              .first,
        );
    expect(heading.style.fontFamily, HyprTypography.barStrong.fontFamily);
    expect(heading.style.fontWeight, HyprTypography.barStrong.fontWeight);
    expect(heading.style.fontSize, HyprTypography.barStrong.fontSize);
    expect(heading.style.height, 1.3);
    expect(
      heading.style.fontVariations,
      contains(const FontVariation('opsz', 14)),
    );
  });

  testWidgets('an empty read does not clear the menu of the focused window', (
    WidgetTester tester,
  ) async {
    final StreamController<GlobalMenuStatus> statuses =
        StreamController<GlobalMenuStatus>();
    addTearDown(statuses.close);

    await tester.pumpWidget(
      _surface(
        overrides: [
          rustCommandDispatcherProvider.overrideWith(
            (ref) => _RecordingDispatcher(),
          ),
          globalMenuStatusProvider.overrideWith((ref) => statuses.stream),
        ],
        child: const SizedBox(width: 400, child: GlobalMenuBar()),
      ),
    );

    statuses.add(_twoHeadings);
    await tester.pump();
    expect(find.text('File'), findsOneWidget);

    // A read that fails while the same application stays focused, which is
    // what made the centre of the bar flick between menu and window title.
    statuses.add(
      const GlobalMenuStatus(
        sections: <GlobalMenuSection>[],
        message: 'the focused window does not expose an AppMenu',
      ),
    );
    await tester.pump();

    expect(find.text('File'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('an open menu hangs from the heading that opened it', (
    WidgetTester tester,
  ) async {
    _answerRegionChannel();
    await tester.pumpWidget(
      _surface(
        overrides: [
          rustCommandDispatcherProvider.overrideWith(
            (ref) => _RecordingDispatcher(),
          ),
          globalMenuStatusProvider.overrideWith(
            (ref) => Stream<GlobalMenuStatus>.value(_twoHeadings),
          ),
          _section(_edit, <GlobalMenuItem>[
            _item(
              label: 'Undo',
              activation: const GlobalMenuItemIdDbusMenu(id: 2),
            ),
          ]),
        ],
        child: const SizedBox(width: 600, child: GlobalMenuBar()),
      ),
    );
    await tester.pump();

    final Offset heading = tester.getTopLeft(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // A menu bar's menus hang from their own heading. Centring them on the
    // bar, or leaving them where a previous anchor put them, is the difference
    // between a menu bar and a row of unrelated popovers.
    final Offset panel = tester.getTopLeft(find.byType(GlobalMenuSectionPanel));
    expect(panel.dx, closeTo(heading.dx, 24));
    expect(panel.dy, greaterThan(heading.dy));
  });

  testWidgets('the bar shows nothing when the window exports no menu', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _surface(
        overrides: [
          rustCommandDispatcherProvider.overrideWith(
            (ref) => _RecordingDispatcher(),
          ),
          globalMenuStatusProvider.overrideWith(
            (ref) => Stream<GlobalMenuStatus>.value(
              const GlobalMenuStatus(
                sections: <GlobalMenuSection>[],
                message: 'the focused window does not expose an AppMenu',
              ),
            ),
          ),
        ],
        child: const SizedBox(width: 400, child: GlobalMenuBar()),
      ),
    );
    await tester.pump();

    expect(find.byType(GlobalMenuBar), findsOneWidget);
    expect(find.text('File'), findsNothing);
  });

  testWidgets('a menu that arrives after an empty first read still appears', (
    WidgetTester tester,
  ) async {
    final StreamController<GlobalMenuStatus> statuses =
        StreamController<GlobalMenuStatus>();
    addTearDown(statuses.close);

    await tester.pumpWidget(
      _surface(
        overrides: [
          rustCommandDispatcherProvider.overrideWith(
            (ref) => _RecordingDispatcher(),
          ),
          globalMenuStatusProvider.overrideWith((ref) => statuses.stream),
        ],
        child: const SizedBox(width: 400, child: GlobalMenuBar()),
      ),
    );
    await tester.pump();

    statuses.add(
      const GlobalMenuStatus(
        sections: <GlobalMenuSection>[],
        message: 'the focused window does not expose an AppMenu',
      ),
    );
    await tester.pump();
    expect(find.text('File'), findsNothing);

    statuses.add(_twoHeadings);
    await tester.pump();

    expect(find.text('File'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('the bar keeps asking while the focused window has no menu yet', (
    WidgetTester tester,
  ) async {
    final _RecordingDispatcher dispatcher = _RecordingDispatcher();

    await tester.pumpWidget(
      _surface(
        overrides: [
          rustCommandDispatcherProvider.overrideWith((ref) => dispatcher),
          focusedWindowStatusProvider.overrideWith(
            (ref) => Stream<FocusedWindowStatus>.value(
              const FocusedWindowStatus(
                address: '0x1',
                appName: 'firefox',
                title: 'Mozilla Firefox',
                hostname: 'workstation',
                monitors: <MonitorFocusedWindowStatus>[],
              ),
            ),
          ),
          globalMenuStatusProvider.overrideWith(
            (ref) => Stream<GlobalMenuStatus>.value(
              const GlobalMenuStatus(
                window: '0x1',
                sections: <GlobalMenuSection>[],
                message: 'the focused window does not expose an AppMenu',
              ),
            ),
          ),
        ],
        child: const SizedBox(width: 400, child: GlobalMenuBar()),
      ),
    );
    await tester.pump();

    final int firstAsks = dispatcher.intents
        .where((intent) => intent.debugLabel == 'global_menu_refresh')
        .length;
    expect(firstAsks, greaterThanOrEqualTo(1));
    expect(find.text('File'), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    expect(
      dispatcher.intents
          .where((intent) => intent.debugLabel == 'global_menu_refresh')
          .length,
      greaterThan(firstAsks),
    );
  });

  testWidgets('the bar stops asking once headings have arrived', (
    WidgetTester tester,
  ) async {
    final _RecordingDispatcher dispatcher = _RecordingDispatcher();

    await tester.pumpWidget(
      _surface(
        overrides: [
          rustCommandDispatcherProvider.overrideWith((ref) => dispatcher),
          focusedWindowStatusProvider.overrideWith(
            (ref) => Stream<FocusedWindowStatus>.value(
              const FocusedWindowStatus(
                address: '0x1',
                appName: 'firefox',
                title: 'Mozilla Firefox',
                hostname: 'workstation',
                monitors: <MonitorFocusedWindowStatus>[],
              ),
            ),
          ),
          globalMenuStatusProvider.overrideWith(
            (ref) => Stream<GlobalMenuStatus>.value(
              _twoHeadings.copyWith(window: () => '0x1'),
            ),
          ),
        ],
        child: const SizedBox(width: 400, child: GlobalMenuBar()),
      ),
    );
    await tester.pump();

    expect(find.text('File'), findsOneWidget);
    final int asks = dispatcher.intents
        .where((intent) => intent.debugLabel == 'global_menu_refresh')
        .length;
    expect(asks, 1);

    await tester.pump(const Duration(seconds: 1));
    expect(
      dispatcher.intents
          .where((intent) => intent.debugLabel == 'global_menu_refresh')
          .length,
      asks,
    );
  });
}
