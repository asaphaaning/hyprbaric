import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';

@UseCase(
  name: 'Interactive menu',
  type: SettingsOverlayContent,
  path: '[Widgets]/Settings',
)
Widget buildSettingsMenu(BuildContext context) {
  return const _SettingsMenuStory();
}

/// The full production settings content with a catalog-local tab selection.
///
/// The catalog owns the selected tab only; every panel, sidebar, and header is
/// the implementation used by the live settings overlay.
class _SettingsMenuStory extends StatefulWidget {
  const _SettingsMenuStory();

  @override
  State<_SettingsMenuStory> createState() => _SettingsMenuStoryState();
}

class _SettingsMenuStoryState extends State<_SettingsMenuStory> {
  SettingsTab tab = SettingsTab.appearance;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: CatalogCanvas(
        padding: const EdgeInsets.all(24),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: HyprColors.popoverSurface,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: HyprColors.popupStroke),
            ),
          ),
          child: SettingsOverlayContent(
            tab: tab,
            onTabChanged: (SettingsTab value) {
              setState(() => tab = value);
            },
            onClose: () {},
          ),
        ),
      ),
    );
  }
}
