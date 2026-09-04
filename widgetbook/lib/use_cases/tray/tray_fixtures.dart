import 'package:hyprbaric/widget_catalog.dart';

/// Stable StatusNotifier snapshots for the tray catalog stories.
abstract final class TrayFixtures {
  static const TrayIcon icon = TrayIcon(
    kind: TrayIconKind.none,
    symbolic: true,
  );

  static const List<TrayItem> items = <TrayItem>[
    TrayItem(
      id: 'bluetooth',
      title: 'Bluetooth',
      description: 'Connected',
      status: TrayItemStatus.active,
      icon: icon,
    ),
    TrayItem(
      id: 'battery',
      title: 'Battery monitor',
      description: 'Charging',
      status: TrayItemStatus.passive,
      icon: icon,
    ),
    TrayItem(
      id: 'updates',
      title: 'System updates',
      description: 'Updates available',
      status: TrayItemStatus.needsAttention,
      icon: icon,
    ),
    TrayItem(
      id: 'clipboard',
      title: 'Clipboard manager',
      status: TrayItemStatus.unknown,
      icon: icon,
    ),
  ];

  static const TrayStatus populated = TrayStatus(items: items);
  static const TrayStatus empty = TrayStatus(items: <TrayItem>[]);

  static const TrayMenuStatus menu = TrayMenuStatus(
    itemId: 'updates',
    x: 880,
    y: 40,
    items: <TrayMenuItem>[
      TrayMenuItem(
        id: 1,
        label: 'Open update manager',
        enabled: true,
        kind: TrayMenuItemKind.standard,
        depth: 0,
      ),
      TrayMenuItem(
        id: 2,
        label: 'Check for updates',
        enabled: true,
        kind: TrayMenuItemKind.standard,
        depth: 1,
      ),
      TrayMenuItem(
        id: 3,
        label: '',
        enabled: false,
        kind: TrayMenuItemKind.separator,
        depth: 0,
      ),
      TrayMenuItem(
        id: 4,
        label: 'Pause notifications',
        enabled: false,
        kind: TrayMenuItemKind.standard,
        depth: 0,
      ),
      TrayMenuItem(
        id: 5,
        label: 'Quit',
        enabled: true,
        kind: TrayMenuItemKind.standard,
        depth: 0,
      ),
    ],
  );

  static const TrayMenuStatus nestedMenu = TrayMenuStatus(
    itemId: 'clipboard',
    x: 880,
    y: 40,
    items: <TrayMenuItem>[
      TrayMenuItem(
        id: 11,
        label: 'Clipboard history',
        enabled: true,
        kind: TrayMenuItemKind.standard,
        depth: 0,
      ),
      TrayMenuItem(
        id: 12,
        label: 'Recent items',
        enabled: true,
        kind: TrayMenuItemKind.standard,
        depth: 1,
      ),
      TrayMenuItem(
        id: 13,
        label: 'Pinned items',
        enabled: true,
        kind: TrayMenuItemKind.standard,
        depth: 1,
      ),
    ],
  );
}
