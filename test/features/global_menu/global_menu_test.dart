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

const GlobalMenuStatus _twoHeadings = GlobalMenuStatus(
  sections: <GlobalMenuSection>[
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
  return globalMenuSectionProvider(id).overrideWith(
    (ref) => Stream<GlobalMenuSectionStatus>.value(
      GlobalMenuSectionStatus(section: id, items: items, message: null),
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
        child: GlobalMenuSectionPanel(section: _file, onActivated: () {}),
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
        child: GlobalMenuSectionPanel(section: _file, onActivated: () {}),
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
        child: GlobalMenuSectionPanel(section: _file, onActivated: () {}),
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
        child: GlobalMenuSectionPanel(section: _file, onActivated: () {}),
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
          child: GlobalMenuSectionPanel(section: _file, onActivated: () {}),
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
        child: GlobalMenuSectionPanel(section: _file, onActivated: () {}),
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
        child: GlobalMenuSectionPanel(section: _file, onActivated: () {}),
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
        child: GlobalMenuSectionPanel(section: _file, onActivated: () {}),
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
        child: GlobalMenuSectionPanel(section: _file, onActivated: () {}),
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
                appName: 'firefox',
                title: 'Mozilla Firefox',
                hostname: 'workstation',
                monitors: <MonitorFocusedWindowStatus>[],
              ),
            ),
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
