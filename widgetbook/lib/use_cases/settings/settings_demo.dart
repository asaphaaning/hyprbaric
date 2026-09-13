import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';

import 'settings_fixtures.dart';

/// Local snapshots keep settings demonstrations isolated from the user's bar.
final demoAppearanceProvider =
    NotifierProvider<DemoAppearance, AppearanceStatus>(DemoAppearance.new);
final demoModulesProvider = NotifierProvider<DemoModules, ModulesStatus>(
  DemoModules.new,
);

class DemoAppearance extends Notifier<AppearanceStatus> {
  @override
  AppearanceStatus build() => SettingsFixtures.appearanceDefault;

  void update(AppearanceStatus Function(AppearanceStatus) transform) =>
      state = transform(state);
}

class DemoModules extends Notifier<ModulesStatus> {
  @override
  ModulesStatus build() => SettingsFixtures.modulesAll;

  void setEnabled(ModuleId module, bool enabled) {
    state = ModulesStatus(
      entries: [
        for (final entry in state.entries)
          entry.module == module
              ? ModuleEntry(module: module, enabled: enabled)
              : entry,
      ],
    );
  }
}

/// Implements the production command boundary against a catalog-local draft.
class DemoAppearanceController extends AppearanceController {
  void _update(AppearanceStatus Function(AppearanceStatus) transform) =>
      ref.read(demoAppearanceProvider.notifier).update(transform);

  @override
  void setPosition(AppearancePosition position) =>
      _update((status) => status.copyWith(position: position));
  @override
  void setMonitor(AppearanceMonitorTarget monitor) =>
      _update((status) => status.copyWith(monitor: monitor));
  @override
  void setOpacity(int opacity) =>
      _update((status) => status.copyWith(opacity: opacity));
  @override
  void setCornerRadius(int cornerRadius) =>
      _update((status) => status.copyWith(cornerRadius: cornerRadius));
  @override
  void setAccentHue(int accentHue) =>
      _update((status) => status.copyWith(accentHue: accentHue));
  @override
  void restoreDefaults() => _update((_) => defaultAppearanceStatus);
}

class DemoModulesController extends ModulesController {
  @override
  void setEnabled(ModuleId module, {required bool enabled}) =>
      ref.read(demoModulesProvider.notifier).setEnabled(module, enabled);
}
