import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';
import 'tray_fixtures.dart';

@UseCase(name: 'Populated', type: TrayStrip, path: '[Widgets]/Tray')
Widget buildPopulatedTrayStrip(BuildContext context) {
  return const _TrayStripStory(status: TrayFixtures.populated);
}

@UseCase(name: 'Empty', type: TrayStrip, path: '[Widgets]/Tray')
Widget buildEmptyTrayStrip(BuildContext context) {
  return const _TrayStripStory(status: TrayFixtures.empty);
}

@UseCase(name: 'Interactive', type: TrayStrip, path: '[Widgets]/Tray')
Widget buildInteractiveTrayStrip(BuildContext context) {
  return const _InteractiveTrayStripStory();
}

@UseCase(name: 'Populated', type: TrayMenuPanel, path: '[Widgets]/Tray')
Widget buildPopulatedTrayMenu(BuildContext context) {
  return const _TrayMenuStory(menu: TrayFixtures.menu);
}

@UseCase(name: 'Nested actions', type: TrayMenuPanel, path: '[Widgets]/Tray')
Widget buildNestedTrayMenu(BuildContext context) {
  return const _TrayMenuStory(menu: TrayFixtures.nestedMenu);
}

@UseCase(name: 'Empty', type: TrayMenuPanel, path: '[Widgets]/Tray')
Widget buildEmptyTrayMenu(BuildContext context) {
  return const _TrayMenuStory(menu: null);
}

class _TrayStripStory extends StatelessWidget {
  const _TrayStripStory({required this.status});

  final TrayStatus status;

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xB3081119)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: TrayStrip(
            status: status,
            onActivate: (_, _) {},
            onContextMenu: (_, _) {},
          ),
        ),
      ),
    );
  }
}

class _InteractiveTrayStripStory extends StatefulWidget {
  const _InteractiveTrayStripStory();

  @override
  State<_InteractiveTrayStripStory> createState() =>
      _InteractiveTrayStripStoryState();
}

class _InteractiveTrayStripStoryState
    extends State<_InteractiveTrayStripStory> {
  String message = 'Click or right-click a tray item';

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xB3081119)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TrayStrip(
                status: TrayFixtures.populated,
                onActivate: (String id, Offset position) {
                  setState(() => message = 'Activated $id');
                },
                onContextMenu: (String id, Offset position) {
                  setState(() => message = 'Context menu for $id');
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _TrayMenuStory extends StatelessWidget {
  const _TrayMenuStory({required this.menu});

  final TrayMenuStatus? menu;

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: TrayMenuPanel(
        menu: menu,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        onActivateItem: (_, _) {},
      ),
    );
  }
}
