import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';
import 'global_menu_fixtures.dart';

@UseCase(name: 'Menu bar', type: GlobalMenuBar, path: '[Widgets]/Global menu')
Widget buildGlobalMenuBar(BuildContext context) {
  return ProviderScope(
    overrides: GlobalMenuFixtures.providers(),
    child: CatalogCanvas(
      child: _BarChrome(
        child: const SizedBox(width: 420, child: GlobalMenuBar()),
      ),
    ),
  );
}

@UseCase(name: 'Empty', type: GlobalMenuBar, path: '[Widgets]/Global menu')
Widget buildEmptyGlobalMenuBar(BuildContext context) {
  return ProviderScope(
    overrides: GlobalMenuFixtures.providers(status: GlobalMenuFixtures.empty),
    child: CatalogCanvas(
      child: _BarChrome(
        child: const SizedBox(width: 420, child: GlobalMenuBar()),
      ),
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
    overrides: GlobalMenuFixtures.providers(),
    child: CatalogCanvas(
      child: GlobalMenuSectionPanel(
        section: GlobalMenuFixtures.view,
        onActivated: () {},
      ),
    ),
  );
}

/// The production headings over the same chrome the left cluster uses.
class _BarChrome extends StatelessWidget {
  const _BarChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xB3081119)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: child,
      ),
    );
  }
}
