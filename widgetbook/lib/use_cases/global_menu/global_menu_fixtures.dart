import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:riverpod/misc.dart' show Override;

/// Zed-shaped AppMenu snapshots for the catalog, including flyouts.
abstract final class GlobalMenuFixtures {
  static const GlobalMenuSectionId file = GlobalMenuSectionIdDbusMenu(id: 1);
  static const GlobalMenuSectionId edit = GlobalMenuSectionIdDbusMenu(id: 2);
  static const GlobalMenuSectionId selection = GlobalMenuSectionIdDbusMenu(
    id: 3,
  );
  static const GlobalMenuSectionId view = GlobalMenuSectionIdDbusMenu(id: 4);
  static const GlobalMenuSectionId help = GlobalMenuSectionIdDbusMenu(id: 5);
  static const GlobalMenuSectionId recent = GlobalMenuSectionIdDbusMenu(id: 20);
  static const GlobalMenuSectionId appearance = GlobalMenuSectionIdDbusMenu(
    id: 21,
  );

  static const GlobalMenuStatus headings = GlobalMenuStatus(
    sections: <GlobalMenuSection>[
      GlobalMenuSection(id: file, label: 'File', enabled: true),
      GlobalMenuSection(id: edit, label: 'Edit', enabled: true),
      GlobalMenuSection(id: selection, label: 'Selection', enabled: true),
      GlobalMenuSection(id: view, label: 'View', enabled: true),
      GlobalMenuSection(id: help, label: 'Help', enabled: true),
    ],
    message: null,
  );

  static const GlobalMenuStatus empty = GlobalMenuStatus(
    sections: <GlobalMenuSection>[],
    message: null,
  );

  static const GlobalMenuItem separator = GlobalMenuItem(
    label: '',
    enabled: false,
    kind: GlobalMenuItemKindSeparator(),
    shortcut: null,
    activation: null,
    submenu: null,
  );

  static GlobalMenuItem row({
    required String label,
    String? shortcut,
    bool enabled = true,
    GlobalMenuItemKind kind = const GlobalMenuItemKindStandard(),
    GlobalMenuSectionId? submenu,
  }) {
    return GlobalMenuItem(
      label: label,
      enabled: enabled,
      kind: kind,
      shortcut: shortcut,
      activation: submenu == null
          ? const GlobalMenuItemIdDbusMenu(id: 1)
          : null,
      submenu: submenu,
    );
  }

  static GlobalMenuItem group(String label) {
    return GlobalMenuItem(
      label: label,
      enabled: false,
      kind: const GlobalMenuItemKindGroup(),
      shortcut: null,
      activation: null,
      submenu: null,
    );
  }

  /// Zed's File menu from the v6 mock, so the catalog hangs the same rows.
  static final List<GlobalMenuItem> fileItems = <GlobalMenuItem>[
    row(label: 'New File', shortcut: 'Ctrl+N'),
    row(label: 'New Window', shortcut: 'Ctrl+Shift+N'),
    separator,
    row(label: 'Open…', shortcut: 'Ctrl+O'),
    row(label: 'Open Recent', submenu: recent),
    separator,
    row(label: 'Save', shortcut: 'Ctrl+S'),
    row(label: 'Save As…', shortcut: 'Ctrl+Shift+S'),
    row(label: 'Save All', shortcut: 'Ctrl+Alt+S'),
    separator,
    row(label: 'Close Editor', shortcut: 'Ctrl+W'),
  ];

  /// Zed's View menu, which is where the mock puts captions, checks and a flyout.
  static final List<GlobalMenuItem> viewItems = <GlobalMenuItem>[
    group('Panels'),
    row(
      label: 'Project Panel',
      shortcut: 'Ctrl+B',
      kind: const GlobalMenuItemKindCheckmark(checked: true),
    ),
    row(
      label: 'Terminal',
      shortcut: 'Ctrl+`',
      kind: const GlobalMenuItemKindCheckmark(checked: true),
    ),
    row(label: 'Outline Panel', shortcut: 'Ctrl+Shift+O'),
    separator,
    row(label: 'Zoom In', shortcut: 'Ctrl++'),
    row(label: 'Zoom Out', shortcut: 'Ctrl+-'),
    row(label: 'Reset Zoom', shortcut: 'Ctrl+0'),
    separator,
    row(label: 'Appearance', submenu: appearance),
    row(label: 'Toggle Full Screen', shortcut: 'F11'),
  ];

  static final List<GlobalMenuItem> recentItems = <GlobalMenuItem>[
    row(label: 'hyprland-dots'),
    row(label: 'bar.tsx'),
    row(label: 'waybar.jsonc'),
    separator,
    row(label: 'Clear Menu'),
  ];

  static final List<GlobalMenuItem> appearanceItems = <GlobalMenuItem>[
    row(label: 'One Dark', kind: const GlobalMenuItemKindRadio(selected: true)),
    row(
      label: 'Gruvbox Dark',
      kind: const GlobalMenuItemKindRadio(selected: false),
    ),
    row(
      label: 'Rosé Pine',
      kind: const GlobalMenuItemKindRadio(selected: false),
    ),
    row(
      label: 'Catppuccin Mocha',
      kind: const GlobalMenuItemKindRadio(selected: false),
    ),
  ];

  static GlobalMenuSectionStatus section(
    GlobalMenuSectionId id,
    List<GlobalMenuItem> items,
  ) {
    return GlobalMenuSectionStatus(section: id, items: items, message: null);
  }

  /// Pins headings and the open panels the catalog can actually hang.
  static List<Override> providers({GlobalMenuStatus status = headings}) {
    return <Override>[
      globalMenuStatusProvider.overrideWith(
        (Ref ref) => Stream<GlobalMenuStatus>.value(status),
      ),
      globalMenuSectionProvider(file).overrideWith(
        (Ref ref) =>
            Stream<GlobalMenuSectionStatus>.value(section(file, fileItems)),
      ),
      globalMenuSectionProvider(view).overrideWith(
        (Ref ref) =>
            Stream<GlobalMenuSectionStatus>.value(section(view, viewItems)),
      ),
      globalMenuSectionProvider(recent).overrideWith(
        (Ref ref) =>
            Stream<GlobalMenuSectionStatus>.value(section(recent, recentItems)),
      ),
      globalMenuSectionProvider(appearance).overrideWith(
        (Ref ref) => Stream<GlobalMenuSectionStatus>.value(
          section(appearance, appearanceItems),
        ),
      ),
    ];
  }
}
