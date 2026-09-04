import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';
import 'settings_fixtures.dart';

@UseCase(
  name: 'Defaults',
  type: AppearanceSettingsPanel,
  path: '[Widgets]/Settings',
)
Widget buildAppearanceSettingsPanel(BuildContext context) {
  return ProviderScope(
    overrides: [
      appearanceStatusProvider.overrideWith(
        (Ref ref) =>
            Stream<AppearanceStatus>.value(SettingsFixtures.appearanceDefault),
      ),
    ],
    child: const _SettingsPanelFrame(child: AppearanceSettingsPanel()),
  );
}

@UseCase(
  name: 'Customized',
  type: AppearanceSettingsPanel,
  path: '[Widgets]/Settings',
)
Widget buildCustomizedAppearanceSettingsPanel(BuildContext context) {
  return ProviderScope(
    overrides: [
      appearanceStatusProvider.overrideWith(
        (Ref ref) =>
            Stream<AppearanceStatus>.value(SettingsFixtures.appearanceCustom),
      ),
    ],
    child: const _SettingsPanelFrame(child: AppearanceSettingsPanel()),
  );
}

@UseCase(
  name: 'All modules enabled',
  type: ModulesSettingsPanel,
  path: '[Widgets]/Settings',
)
Widget buildAllModulesSettingsPanel(BuildContext context) {
  return ProviderScope(
    overrides: [
      modulesStatusProvider.overrideWith(
        (Ref ref) => Stream<ModulesStatus>.value(SettingsFixtures.modulesAll),
      ),
    ],
    child: const _SettingsPanelFrame(child: ModulesSettingsPanel()),
  );
}

@UseCase(
  name: 'Focused modules',
  type: ModulesSettingsPanel,
  path: '[Widgets]/Settings',
)
Widget buildFocusedModulesSettingsPanel(BuildContext context) {
  return ProviderScope(
    overrides: [
      modulesStatusProvider.overrideWith(
        (Ref ref) =>
            Stream<ModulesStatus>.value(SettingsFixtures.modulesFocused),
      ),
    ],
    child: const _SettingsPanelFrame(child: ModulesSettingsPanel()),
  );
}

@UseCase(
  name: 'Roman indicators',
  type: WorkspacesSettingsPanel,
  path: '[Widgets]/Settings',
)
Widget buildRomanWorkspacesSettingsPanel(BuildContext context) {
  return ProviderScope(
    overrides: [
      workspaceSettingsStatusProvider.overrideWith(
        (Ref ref) => Stream<WorkspaceSettingsStatus>.value(
          SettingsFixtures.workspacesRoman,
        ),
      ),
    ],
    child: const _SettingsPanelFrame(child: WorkspacesSettingsPanel()),
  );
}

@UseCase(
  name: 'Numeric indicators',
  type: WorkspacesSettingsPanel,
  path: '[Widgets]/Settings',
)
Widget buildNumericWorkspacesSettingsPanel(BuildContext context) {
  return ProviderScope(
    overrides: [
      workspaceSettingsStatusProvider.overrideWith(
        (Ref ref) => Stream<WorkspaceSettingsStatus>.value(
          SettingsFixtures.workspacesNumeric,
        ),
      ),
    ],
    child: const _SettingsPanelFrame(child: WorkspacesSettingsPanel()),
  );
}

@UseCase(
  name: 'Enabled with schedule',
  type: NightLightSettingsPanel,
  path: '[Widgets]/Settings',
)
Widget buildEnabledNightLightSettingsPanel(BuildContext context) {
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
    child: const _SettingsPanelFrame(child: NightLightSettingsPanel()),
  );
}

@UseCase(
  name: 'Unavailable',
  type: NightLightSettingsPanel,
  path: '[Widgets]/Settings',
)
Widget buildUnavailableNightLightSettingsPanel(BuildContext context) {
  return ProviderScope(
    overrides: [
      nightLightStatusProvider.overrideWith(
        (Ref ref) => Stream<NightLightStatus>.value(
          SettingsFixtures.nightLightUnavailable,
        ),
      ),
      scheduleStatusProvider.overrideWith(
        (Ref ref) =>
            Stream<ScheduleStatus>.value(SettingsFixtures.scheduleEmpty),
      ),
    ],
    child: const _SettingsPanelFrame(child: NightLightSettingsPanel()),
  );
}

@UseCase(
  name: 'Capabilities',
  type: AboutSettingsPanel,
  path: '[Widgets]/Settings',
)
Widget buildAboutSettingsPanel(BuildContext context) {
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
    child: const _SettingsPanelFrame(child: AboutSettingsPanel()),
  );
}

@UseCase(name: 'Populated', type: KeybindingsPanel, path: '[Widgets]/Settings')
Widget buildKeybindingsPanel(BuildContext context) {
  return _keybindingsStory(
    Stream<ShortcutSettingsSnapshot>.value(SettingsFixtures.shortcuts),
  );
}

@UseCase(name: 'Loading', type: KeybindingsPanel, path: '[Widgets]/Settings')
Widget buildLoadingKeybindingsPanel(BuildContext context) {
  return _keybindingsStory(const Stream<ShortcutSettingsSnapshot>.empty());
}

@UseCase(
  name: 'Unavailable',
  type: KeybindingsPanel,
  path: '[Widgets]/Settings',
)
Widget buildUnavailableKeybindingsPanel(BuildContext context) {
  return _keybindingsStory(
    Stream<ShortcutSettingsSnapshot>.error(
      'shortcuts service is unavailable',
      StackTrace.current,
    ),
  );
}

Widget _keybindingsStory(Stream<ShortcutSettingsSnapshot> snapshot) {
  return ProviderScope(
    overrides: [
      shortcutSettingsSnapshotProvider.overrideWith((Ref ref) => snapshot),
      shortcutSettingsCommandResultProvider.overrideWith(
        (Ref ref) => const Stream<ShortcutSettingsCommandResult>.empty(),
      ),
      keybindingControllerProvider.overrideWith(
        (Ref ref) => _CatalogKeybindingController(ref),
      ),
    ],
    child: const _SettingsPanelFrame(child: KeybindingsPanel()),
  );
}

class _CatalogKeybindingController extends KeybindingController {
  _CatalogKeybindingController(super.ref);

  @override
  void load() {}

  @override
  void setBinding({
    required ShortcutSettingId shortcut,
    required ShortcutBindingInput binding,
  }) {}

  @override
  void disable(ShortcutSettingId shortcut) {}

  @override
  void reset(ShortcutSettingId shortcut) {}
}

class _SettingsPanelFrame extends StatelessWidget {
  const _SettingsPanelFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      padding: const EdgeInsets.all(24),
      child: SizedBox(width: 520, height: 560, child: child),
    );
  }
}
