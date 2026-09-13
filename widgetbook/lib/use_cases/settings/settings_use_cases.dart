import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import 'settings_demo.dart';
import 'settings_fixtures.dart';

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
      overrides: [
        appearanceControllerProvider.overrideWith(DemoAppearanceController.new),
        modulesControllerProvider.overrideWith(DemoModulesController.new),
        appearanceStatusProvider.overrideWith(
          (ref) => Stream.value(ref.watch(demoAppearanceProvider)),
        ),
        modulesStatusProvider.overrideWith(
          (ref) => Stream.value(ref.watch(demoModulesProvider)),
        ),
        workspaceSettingsStatusProvider.overrideWith(
          (ref) => Stream.value(SettingsFixtures.workspacesRoman),
        ),
        nightLightStatusProvider.overrideWith(
          (ref) => Stream.value(SettingsFixtures.nightLightOn),
        ),
        scheduleStatusProvider.overrideWith(
          (ref) => Stream.value(SettingsFixtures.scheduleEnabled),
        ),
        capabilityStatusProvider.overrideWith(
          (ref) => Stream.value(SettingsFixtures.capabilities),
        ),
        appStatusProvider.overrideWith(
          (ref) => Stream.value(SettingsFixtures.app),
        ),
        shortcutSettingsSnapshotProvider.overrideWith(
          (ref) => Stream.value(SettingsFixtures.shortcuts),
        ),
        shortcutSettingsCommandResultProvider.overrideWith(
          (ref) => const Stream<ShortcutSettingsCommandResult>.empty(),
        ),
      ],
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: HyprPopoverSurface(
              borderRadius: BorderRadius.circular(18),
              child: SettingsOverlayContent(
                tab: tab,
                onTabChanged: (SettingsTab value) {
                  setState(() => tab = value);
                },
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }
}
