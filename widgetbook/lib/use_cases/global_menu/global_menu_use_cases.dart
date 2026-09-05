import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';

const GlobalMenuSectionId _file = GlobalMenuSectionIdDbusMenu(id: 1);
const GlobalMenuSectionId _recent = GlobalMenuSectionIdDbusMenu(id: 20);

const GlobalMenuStatus _headings = GlobalMenuStatus(
  sections: <GlobalMenuSection>[
    GlobalMenuSection(id: _file, label: 'File', enabled: true),
    GlobalMenuSection(
      id: GlobalMenuSectionIdDbusMenu(id: 2),
      label: 'Edit',
      enabled: true,
    ),
    GlobalMenuSection(
      id: GlobalMenuSectionIdDbusMenu(id: 3),
      label: 'Selection',
      enabled: true,
    ),
    GlobalMenuSection(
      id: GlobalMenuSectionIdDbusMenu(id: 4),
      label: 'View',
      enabled: true,
    ),
    GlobalMenuSection(
      id: GlobalMenuSectionIdDbusMenu(id: 5),
      label: 'Help',
      enabled: true,
    ),
  ],
  message: null,
);

GlobalMenuItem _row({
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

const GlobalMenuItem _separator = GlobalMenuItem(
  label: '',
  enabled: false,
  kind: GlobalMenuItemKindSeparator(),
  shortcut: null,
  activation: null,
  submenu: null,
);

final List<GlobalMenuItem> _fileRows = <GlobalMenuItem>[
  _row(label: 'New File', shortcut: 'Ctrl+N'),
  _row(label: 'New Window', shortcut: 'Ctrl+Shift+N'),
  _separator,
  _row(label: 'Open…', shortcut: 'Ctrl+O'),
  _row(label: 'Open Recent', submenu: _recent),
  _separator,
  _row(label: 'Save', shortcut: 'Ctrl+S'),
  _row(label: 'Save As…', enabled: false, shortcut: 'Ctrl+Shift+S'),
  _separator,
  _row(label: 'Word Wrap', kind: const GlobalMenuItemKindCheckmark(checked: true)),
  _row(label: 'Show Line Numbers', kind: const GlobalMenuItemKindCheckmark(checked: false)),
  _separator,
  _row(label: 'Quit', shortcut: 'Ctrl+Q'),
];

final List<GlobalMenuItem> _recentRows = <GlobalMenuItem>[
  _row(label: 'hyprland-dots'),
  _row(label: 'bar.tsx'),
  _row(label: 'waybar.jsonc'),
  _separator,
  _row(label: 'Clear Menu'),
];

List<dynamic> _overrides() => <dynamic>[
  globalMenuStatusProvider.overrideWith(
    (ref) => Stream<GlobalMenuStatus>.value(_headings),
  ),
  globalMenuSectionProvider(_file).overrideWith(
    (ref) => Stream<GlobalMenuSectionStatus>.value(
      GlobalMenuSectionStatus(section: _file, items: _fileRows, message: null),
    ),
  ),
  globalMenuSectionProvider(_recent).overrideWith(
    (ref) => Stream<GlobalMenuSectionStatus>.value(
      GlobalMenuSectionStatus(
        section: _recent,
        items: _recentRows,
        message: null,
      ),
    ),
  ),
];

@UseCase(name: 'Menu bar', type: GlobalMenuBar, path: '[Widgets]/Global menu')
Widget buildGlobalMenuBar(BuildContext context) {
  return ProviderScope(
    overrides: _overrides().cast(),
    child: const CatalogCanvas(
      child: SizedBox(width: 420, child: GlobalMenuBar()),
    ),
  );
}

@UseCase(
  name: 'Open menu',
  type: GlobalMenuSectionPanel,
  path: '[Widgets]/Global menu',
)
Widget buildGlobalMenuPanel(BuildContext context) {
  return ProviderScope(
    overrides: _overrides().cast(),
    child: CatalogCanvas(
      child: GlobalMenuSectionPanel(section: _file, onActivated: () {}),
    ),
  );
}
