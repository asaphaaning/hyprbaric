import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';
import 'settings_fixtures.dart';

@UseCase(
  name: 'Interactive',
  type: SettingsSidebar,
  path: '[Building blocks]/Settings',
)
Widget buildSettingsSidebar(BuildContext context) {
  return const _SettingsSidebarStory();
}

@UseCase(
  name: 'Active and idle',
  type: SettingsTabButton,
  path: '[Building blocks]/Settings',
)
Widget buildSettingsTabButtonStates(BuildContext context) {
  return _SettingsChromeCanvas(
    width: 190,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SettingsTabButton(
          tab: SettingsTab.appearance,
          active: true,
          onPressed: () {},
        ),
        SettingsTabButton(
          tab: SettingsTab.modules,
          active: false,
          onPressed: () {},
        ),
        SettingsTabButton(
          tab: SettingsTab.keybinds,
          active: false,
          onPressed: () {},
        ),
      ],
    ),
  );
}

@UseCase(
  name: 'Every tab',
  type: SettingsContentHeader,
  path: '[Building blocks]/Settings',
)
Widget buildSettingsContentHeaderStates(BuildContext context) {
  return _SettingsChromeCanvas(
    width: 420,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final SettingsTab tab in SettingsTab.values) ...<Widget>[
          SettingsContentHeader(tab: tab, onClose: () {}),
          const SizedBox(height: 16),
        ],
      ],
    ),
  );
}

@UseCase(
  name: 'Appearance',
  type: SettingsTabBody,
  path: '[Building blocks]/Settings',
)
Widget buildAppearanceSettingsTabBody(BuildContext context) {
  return ProviderScope(
    overrides: [
      appearanceStatusProvider.overrideWith(
        (Ref ref) =>
            Stream<AppearanceStatus>.value(SettingsFixtures.appearanceCustom),
      ),
    ],
    child: const _SettingsTabBodyFrame(tab: SettingsTab.appearance),
  );
}

@UseCase(
  name: 'Modules',
  type: SettingsTabBody,
  path: '[Building blocks]/Settings',
)
Widget buildModulesSettingsTabBody(BuildContext context) {
  return ProviderScope(
    overrides: [
      modulesStatusProvider.overrideWith(
        (Ref ref) => Stream<ModulesStatus>.value(SettingsFixtures.modulesAll),
      ),
    ],
    child: const _SettingsTabBodyFrame(tab: SettingsTab.modules),
  );
}

@UseCase(
  name: 'Workspaces',
  type: SettingsTabBody,
  path: '[Building blocks]/Settings',
)
Widget buildWorkspacesSettingsTabBody(BuildContext context) {
  return ProviderScope(
    overrides: [
      workspaceSettingsStatusProvider.overrideWith(
        (Ref ref) => Stream<WorkspaceSettingsStatus>.value(
          SettingsFixtures.workspacesRoman,
        ),
      ),
    ],
    child: const _SettingsTabBodyFrame(tab: SettingsTab.workspaces),
  );
}

@UseCase(
  name: 'Display',
  type: SettingsTabBody,
  path: '[Building blocks]/Settings',
)
Widget buildDisplaySettingsTabBody(BuildContext context) {
  return ProviderScope(
    overrides: [
      nightLightStatusProvider.overrideWith(
        (Ref ref) =>
            Stream<NightLightStatus>.value(SettingsFixtures.nightLightOn),
      ),
      scheduleStatusProvider.overrideWith(
        (Ref ref) =>
            Stream<ScheduleStatus>.value(SettingsFixtures.scheduleEnabled),
      ),
    ],
    child: const _SettingsTabBodyFrame(tab: SettingsTab.display),
  );
}

@UseCase(
  name: 'About',
  type: SettingsTabBody,
  path: '[Building blocks]/Settings',
)
Widget buildAboutSettingsTabBody(BuildContext context) {
  return ProviderScope(
    overrides: [
      capabilityStatusProvider.overrideWith(
        (Ref ref) =>
            Stream<CapabilityStatus>.value(SettingsFixtures.capabilities),
      ),
      appStatusProvider.overrideWith(
        (Ref ref) => Stream<AppStatus>.value(SettingsFixtures.app),
      ),
    ],
    child: const _SettingsTabBodyFrame(tab: SettingsTab.about),
  );
}

@UseCase(
  name: 'Keybinds',
  type: SettingsTabBody,
  path: '[Building blocks]/Settings',
)
Widget buildKeybindsSettingsTabBody(BuildContext context) {
  return ProviderScope(
    overrides: [
      shortcutSettingsSnapshotProvider.overrideWith(
        (Ref ref) =>
            Stream<ShortcutSettingsSnapshot>.value(SettingsFixtures.shortcuts),
      ),
      shortcutSettingsCommandResultProvider.overrideWith(
        (Ref ref) => const Stream<ShortcutSettingsCommandResult>.empty(),
      ),
    ],
    child: const _SettingsTabBodyFrame(tab: SettingsTab.keybinds),
  );
}

@UseCase(
  name: 'Binding states',
  type: KeybindingRow,
  path: '[Building blocks]/Settings',
)
Widget buildKeybindingRowStates(BuildContext context) {
  return _SettingsChromeCanvas(
    width: 460,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (String label, ShortcutSettingsRow row, bool recording)
            in <(String, ShortcutSettingsRow, bool)>[
              ('Built-in', SettingsFixtures.appLauncher, false),
              ('User override', SettingsFixtures.controls, false),
              ('Conflicting', SettingsFixtures.conflict, false),
              ('Disabled', SettingsFixtures.disabled, false),
              ('Recording', SettingsFixtures.volume, true),
            ]) ...<Widget>[
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 6),
          KeybindingRow(
            row: row,
            recording: recording,
            recordingDisplay: 'Press a shortcut…',
            onRecord: () {},
            onDisable: () {},
            onReset: () {},
          ),
          const SizedBox(height: 14),
        ],
      ],
    ),
  );
}

/// The production sidebar with a catalog-local tab selection.
class _SettingsSidebarStory extends StatefulWidget {
  const _SettingsSidebarStory();

  @override
  State<_SettingsSidebarStory> createState() => _SettingsSidebarStoryState();
}

class _SettingsSidebarStoryState extends State<_SettingsSidebarStory> {
  SettingsTab tab = SettingsTab.appearance;

  @override
  Widget build(BuildContext context) {
    // The sidebar footer reads the app version straight from the signal layer.
    return ProviderScope(
      overrides: [
        appStatusProvider.overrideWith(
          (Ref ref) => Stream<AppStatus>.value(SettingsFixtures.app),
        ),
      ],
      child: _SettingsChromeCanvas(
        width: 190,
        // The overlay hands the sidebar a bounded height; its footer sits at
        // the bottom of that column.
        height: 560,
        child: SettingsSidebar(
          activeTab: tab,
          onTabChanged: (SettingsTab value) => setState(() => tab = value),
        ),
      ),
    );
  }
}

/// [SettingsTabBody] routes a tab to its production panel, so each story feeds
/// the signals that panel reads.
class _SettingsTabBodyFrame extends StatelessWidget {
  const _SettingsTabBodyFrame({required this.tab});

  final SettingsTab tab;

  @override
  Widget build(BuildContext context) {
    return _SettingsChromeCanvas(
      width: 520,
      height: 560,
      child: SettingsTabBody(tab: tab),
    );
  }
}

class _SettingsChromeCanvas extends StatelessWidget {
  const _SettingsChromeCanvas({
    required this.child,
    required this.width,
    this.height,
  });

  final Widget child;
  final double width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      padding: const EdgeInsets.all(24),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: HyprColors.popoverSurface,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: HyprColors.popupStroke),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );
  }
}
