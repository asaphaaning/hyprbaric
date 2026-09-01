import 'package:hyprbaric/widget_catalog.dart';

/// Deterministic settings snapshots for the standalone settings stories.
abstract final class SettingsFixtures {
  static const AppearanceStatus appearanceDefault = AppearanceStatus(
    position: AppearancePosition.top,
    monitor: AppearanceMonitorTargetPrimary(),
    opacity: 77,
    cornerRadius: 12,
    accentHue: 197,
  );

  static const AppearanceStatus appearanceCustom = AppearanceStatus(
    position: AppearancePosition.bottom,
    monitor: AppearanceMonitorTargetAll(),
    opacity: 68,
    cornerRadius: 16,
    accentHue: 275,
  );

  static const ModulesStatus modulesAll = ModulesStatus(
    entries: <ModuleEntry>[
      ModuleEntry(module: ModuleId.activeWindowTitle, enabled: true),
      ModuleEntry(module: ModuleId.systemTray, enabled: true),
      ModuleEntry(module: ModuleId.notifications, enabled: true),
      ModuleEntry(module: ModuleId.audioDisplay, enabled: true),
    ],
  );

  static const ModulesStatus modulesFocused = ModulesStatus(
    entries: <ModuleEntry>[
      ModuleEntry(module: ModuleId.activeWindowTitle, enabled: true),
      ModuleEntry(module: ModuleId.systemTray, enabled: false),
      ModuleEntry(module: ModuleId.notifications, enabled: true),
      ModuleEntry(module: ModuleId.audioDisplay, enabled: false),
    ],
  );

  static const WorkspaceSettingsStatus workspacesRoman =
      WorkspaceSettingsStatus(
        indicatorStyle: WorkspaceIndicatorStyle.roman,
        clickable: true,
        visibleRange: WorkspaceVisibleRange.medium,
        visibleCount: 7,
      );

  static const WorkspaceSettingsStatus workspacesNumeric =
      WorkspaceSettingsStatus(
        indicatorStyle: WorkspaceIndicatorStyle.numeric,
        clickable: false,
        visibleRange: WorkspaceVisibleRange.large,
        visibleCount: 9,
      );

  static const NightLightStatus nightLightOn = NightLightStatusAvailable(
    enabled: true,
    temperature: 3400,
  );

  static const NightLightStatus nightLightUnavailable =
      NightLightStatusUnavailable(
        enabled: false,
        temperature: 4500,
        message: 'hyprsunset is not running.',
      );

  static const ScheduleStatus scheduleEnabled = ScheduleStatus(
    entries: <ScheduleEntry>[
      ScheduleEntry(
        action: ScheduleAction.nightLight,
        enabled: true,
        startHour: 21,
        stopHour: 7,
      ),
    ],
  );

  static const ScheduleStatus scheduleEmpty = ScheduleStatus(
    entries: <ScheduleEntry>[],
  );

  static const CapabilityStatus capabilities = CapabilityStatus(
    entries: <CapabilityEntry>[
      CapabilityEntry(
        capability: CapabilityId.hyprland,
        label: 'Hyprland',
        detail: 'Compositor integration and workspace state.',
        tier: CapabilityTier.core,
        availability: CapabilityAvailability.available,
        features: <String>['Workspace events', 'Focused window'],
        commands: <String>['hyprctl'],
        archPackages: <String>[],
        debianPackages: <String>[],
        rpmPackages: <String>[],
      ),
      CapabilityEntry(
        capability: CapabilityId.network,
        label: 'Network',
        detail: 'Wi-Fi and interface monitoring.',
        tier: CapabilityTier.service,
        availability: CapabilityAvailability.available,
        features: <String>['Traffic', 'StatusNotifier'],
        commands: <String>['nmcli'],
        archPackages: <String>['networkmanager'],
        debianPackages: <String>['network-manager'],
        rpmPackages: <String>['NetworkManager'],
      ),
      CapabilityEntry(
        capability: CapabilityId.nightLight,
        label: 'Night light',
        detail: 'Screen temperature control through hyprsunset.',
        tier: CapabilityTier.optional,
        availability: CapabilityAvailability.degraded,
        message: 'Install hyprsunset to enable this feature.',
        features: <String>['Temperature'],
        commands: <String>['hyprsunset'],
        archPackages: <String>['hyprsunset'],
        debianPackages: <String>[],
        rpmPackages: <String>[],
      ),
    ],
  );

  static const AppStatus app = AppStatus(version: '0.6.0');

  static const ShortcutBindingView appLauncherBinding = ShortcutBindingView(
    phase: ShortcutBindingPhase.press,
    modifiers: <ShortcutModifier>[ShortcutModifier.logo],
    key: 'SPACE',
    display: 'LOGO+SPACE',
  );

  static const ShortcutBindingView controlsBinding = ShortcutBindingView(
    phase: ShortcutBindingPhase.press,
    modifiers: <ShortcutModifier>[
      ShortcutModifier.logo,
      ShortcutModifier.shift,
    ],
    key: 'C',
    display: 'LOGO+SHIFT+C',
  );

  static const ShortcutBindingView sessionBinding = ShortcutBindingView(
    phase: ShortcutBindingPhase.press,
    modifiers: <ShortcutModifier>[ShortcutModifier.logo],
    key: 'L',
    display: 'LOGO+L',
  );

  static const ShortcutBindingView screenshotBinding = ShortcutBindingView(
    phase: ShortcutBindingPhase.press,
    modifiers: <ShortcutModifier>[
      ShortcutModifier.logo,
      ShortcutModifier.shift,
    ],
    key: '4',
    display: 'LOGO+SHIFT+4',
  );

  static const ShortcutBindingView volumeBinding = ShortcutBindingView(
    phase: ShortcutBindingPhase.press,
    modifiers: <ShortcutModifier>[ShortcutModifier.logo],
    key: 'UP',
    display: 'LOGO+UP',
  );

  static const ShortcutBindingView brightnessBinding = ShortcutBindingView(
    phase: ShortcutBindingPhase.press,
    modifiers: <ShortcutModifier>[ShortcutModifier.logo],
    key: 'F7',
    display: 'LOGO+F7',
  );

  static const ShortcutSettingsRow appLauncher = ShortcutSettingsRow(
    shortcut: ShortcutSettingId.appLauncher,
    label: 'App launcher',
    description: 'Open the application launcher.',
    category: ShortcutSettingCategory.bar,
    defaultMapping: ShortcutMappingViewBound(binding: appLauncherBinding),
    effectiveMapping: ShortcutMappingViewBound(binding: appLauncherBinding),
    source: ShortcutMappingSource.builtin,
  );

  static const ShortcutSettingsRow controls = ShortcutSettingsRow(
    shortcut: ShortcutSettingId.controls,
    label: 'Controls',
    description: 'Open the quick controls panel.',
    category: ShortcutSettingCategory.bar,
    defaultMapping: ShortcutMappingViewBound(binding: controlsBinding),
    effectiveMapping: ShortcutMappingViewBound(binding: controlsBinding),
    source: ShortcutMappingSource.userOverride,
  );

  static const ShortcutSettingsRow sessionLauncher = ShortcutSettingsRow(
    shortcut: ShortcutSettingId.sessionLauncher,
    label: 'Session launcher',
    description: 'Open lock, logout, reboot, and shutdown actions.',
    category: ShortcutSettingCategory.session,
    defaultMapping: ShortcutMappingViewBound(binding: sessionBinding),
    effectiveMapping: ShortcutMappingViewBound(binding: sessionBinding),
    source: ShortcutMappingSource.builtin,
  );

  static const ShortcutSettingsRow screenshot = ShortcutSettingsRow(
    shortcut: ShortcutSettingId.captureRegion,
    label: 'Screenshot region',
    description: 'Capture a selected region of the screen.',
    category: ShortcutSettingCategory.capture,
    defaultMapping: ShortcutMappingViewBound(binding: screenshotBinding),
    effectiveMapping: ShortcutMappingViewBound(binding: screenshotBinding),
    source: ShortcutMappingSource.builtin,
  );

  static const ShortcutSettingsRow volume = ShortcutSettingsRow(
    shortcut: ShortcutSettingId.volumeUp,
    label: 'Volume up',
    description: 'Raise the default audio endpoint volume.',
    category: ShortcutSettingCategory.audio,
    defaultMapping: ShortcutMappingViewBound(binding: volumeBinding),
    effectiveMapping: ShortcutMappingViewBound(binding: volumeBinding),
    source: ShortcutMappingSource.builtin,
  );

  static const ShortcutSettingsRow brightness = ShortcutSettingsRow(
    shortcut: ShortcutSettingId.brightnessUp,
    label: 'Brightness up',
    description: 'Raise the active display brightness.',
    category: ShortcutSettingCategory.display,
    defaultMapping: ShortcutMappingViewBound(binding: brightnessBinding),
    effectiveMapping: ShortcutMappingViewBound(binding: brightnessBinding),
    source: ShortcutMappingSource.builtin,
  );

  static const ShortcutSettingsRow disabled = ShortcutSettingsRow(
    shortcut: ShortcutSettingId.toggleNightLight,
    label: 'Toggle Night light',
    description: 'Toggle the screen temperature schedule.',
    category: ShortcutSettingCategory.display,
    defaultMapping: ShortcutMappingViewBound(binding: brightnessBinding),
    effectiveMapping: ShortcutMappingViewDisabled(),
    source: ShortcutMappingSource.disabled,
  );

  static const ShortcutSettingsRow conflict = ShortcutSettingsRow(
    shortcut: ShortcutSettingId.volumeDown,
    label: 'Volume down',
    description: 'Lower the default audio endpoint volume.',
    category: ShortcutSettingCategory.audio,
    defaultMapping: ShortcutMappingViewBound(binding: volumeBinding),
    effectiveMapping: ShortcutMappingViewBound(binding: volumeBinding),
    source: ShortcutMappingSource.userOverride,
    conflict: ShortcutSettingId.volumeUp,
  );

  static const ShortcutSettingsSnapshot shortcuts = ShortcutSettingsSnapshot(
    rows: <ShortcutSettingsRow>[
      appLauncher,
      controls,
      sessionLauncher,
      screenshot,
      volume,
      conflict,
      brightness,
      disabled,
    ],
    writablePath: '~/.config/hyprbaric/config.toml',
    message: 'One binding is shared with another action.',
  );
}
