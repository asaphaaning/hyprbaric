import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bindings/bindings.dart';
import 'rust_signal_dispatcher.dart';

final rustCommandDispatcherProvider = Provider<RustCommandDispatcher>(
  (ref) => const RustCommandDispatcher(),
);

/// Sends typed Flutter-side intents across the RINF boundary.
///
/// Feature controllers should construct domain intents such as
/// [NetworkIntent.connect] or [AudioIntent.setVolume] and let this dispatcher
/// own signal delivery, failure tolerance, and development logging labels.
class RustCommandDispatcher {
  const RustCommandDispatcher();

  void dispatch(RustIntent intent) {
    sendRustSignal(intent.send, debugLabel: intent.debugLabel);
  }
}

sealed class RustIntent {
  const RustIntent();

  String get debugLabel;

  void send();
}

sealed class GlobalMenuIntent extends RustIntent {
  const GlobalMenuIntent();

  const factory GlobalMenuIntent.refresh() = _GlobalMenuRefreshIntent;
}

class _GlobalMenuRefreshIntent extends GlobalMenuIntent {
  const _GlobalMenuRefreshIntent();

  @override
  String get debugLabel => 'global_menu_refresh';

  @override
  void send() => const GlobalMenuRequest().sendSignalToRust();
}

sealed class SetupIntent extends RustIntent {
  const SetupIntent();

  const factory SetupIntent.complete(SetupOutcome outcome) =
      _SetupCompleteIntent;
}

class _SetupCompleteIntent extends SetupIntent {
  const _SetupCompleteIntent(this.outcome);

  final SetupOutcome outcome;

  @override
  String get debugLabel => 'setup_complete:${outcome.name}';

  @override
  void send() {
    SetupCommandComplete(outcome: outcome).sendSignalToRust();
  }
}

sealed class NetworkIntent extends RustIntent {
  const NetworkIntent();

  const factory NetworkIntent.scan() = _NetworkScanIntent;

  const factory NetworkIntent.setWifiEnabled({required bool enabled}) =
      _NetworkSetWifiEnabledIntent;

  const factory NetworkIntent.connect({
    required String ssid,
    required String? bssid,
    required String? password,
  }) = _NetworkConnectIntent;

  const factory NetworkIntent.openSettings() = _NetworkOpenSettingsIntent;
}

class _NetworkScanIntent extends NetworkIntent {
  const _NetworkScanIntent();

  @override
  String get debugLabel => 'network_scan';

  @override
  void send() => const NetworkScanRequest().sendSignalToRust();
}

class _NetworkSetWifiEnabledIntent extends NetworkIntent {
  const _NetworkSetWifiEnabledIntent({required this.enabled});

  final bool enabled;

  @override
  String get debugLabel => 'network_wifi:${enabled ? 'enabled' : 'disabled'}';

  @override
  void send() => NetworkSetWifiEnabled(enabled: enabled).sendSignalToRust();
}

class _NetworkConnectIntent extends NetworkIntent {
  const _NetworkConnectIntent({
    required this.ssid,
    required this.bssid,
    required this.password,
  });

  final String ssid;
  final String? bssid;
  final String? password;

  @override
  String get debugLabel => 'network_connect:$ssid';

  @override
  void send() {
    NetworkConnectRequest(
      ssid: ssid,
      bssid: bssid,
      password: password,
    ).sendSignalToRust();
  }
}

class _NetworkOpenSettingsIntent extends NetworkIntent {
  const _NetworkOpenSettingsIntent();

  @override
  String get debugLabel => 'network_settings';

  @override
  void send() => const NetworkSettingsRequest().sendSignalToRust();
}

sealed class AudioIntent extends RustIntent {
  const AudioIntent();

  const factory AudioIntent.setVolume({
    required AudioEndpointKind kind,
    required int volume,
  }) = _AudioSetVolumeIntent;

  const factory AudioIntent.setMuted({
    required AudioEndpointKind kind,
    required bool muted,
  }) = _AudioSetMutedIntent;
}

class _AudioSetVolumeIntent extends AudioIntent {
  const _AudioSetVolumeIntent({required this.kind, required this.volume});

  final AudioEndpointKind kind;
  final int volume;

  @override
  String get debugLabel => 'audio_volume:${kind.name}:$volume';

  @override
  void send() {
    AudioCommandSetVolume(kind: kind, volume: volume).sendSignalToRust();
  }
}

class _AudioSetMutedIntent extends AudioIntent {
  const _AudioSetMutedIntent({required this.kind, required this.muted});

  final AudioEndpointKind kind;
  final bool muted;

  @override
  String get debugLabel => 'audio_mute:${kind.name}:$muted';

  @override
  void send() =>
      AudioCommandSetMuted(kind: kind, muted: muted).sendSignalToRust();
}

sealed class BrightnessIntent extends RustIntent {
  const BrightnessIntent();

  const factory BrightnessIntent.setLevel({required int value}) =
      _BrightnessSetLevelIntent;
}

sealed class AppearanceIntent extends RustIntent {
  const AppearanceIntent();

  const factory AppearanceIntent.setPosition(AppearancePosition position) =
      _AppearanceSetPositionIntent;

  const factory AppearanceIntent.setMonitor(AppearanceMonitorTarget monitor) =
      _AppearanceSetMonitorIntent;

  const factory AppearanceIntent.setOpacity(int opacity) =
      _AppearanceSetOpacityIntent;

  const factory AppearanceIntent.setCornerRadius(int cornerRadius) =
      _AppearanceSetCornerRadiusIntent;

  const factory AppearanceIntent.setAccentHue(int accentHue) =
      _AppearanceSetAccentHueIntent;

  const factory AppearanceIntent.restoreDefaults() =
      _AppearanceRestoreDefaultsIntent;
}

class _AppearanceSetPositionIntent extends AppearanceIntent {
  const _AppearanceSetPositionIntent(this.position);

  final AppearancePosition position;

  @override
  String get debugLabel => 'appearance_position:${position.name}';

  @override
  void send() {
    AppearanceCommandSetPosition(position: position).sendSignalToRust();
  }
}

class _AppearanceSetMonitorIntent extends AppearanceIntent {
  const _AppearanceSetMonitorIntent(this.monitor);

  final AppearanceMonitorTarget monitor;

  @override
  String get debugLabel => 'appearance_monitor:$monitor';

  @override
  void send() {
    AppearanceCommandSetMonitor(monitor: monitor).sendSignalToRust();
  }
}

class _AppearanceSetOpacityIntent extends AppearanceIntent {
  const _AppearanceSetOpacityIntent(this.opacity);

  final int opacity;

  @override
  String get debugLabel => 'appearance_opacity:$opacity';

  @override
  void send() =>
      AppearanceCommandSetOpacity(opacity: opacity).sendSignalToRust();
}

class _AppearanceSetCornerRadiusIntent extends AppearanceIntent {
  const _AppearanceSetCornerRadiusIntent(this.cornerRadius);

  final int cornerRadius;

  @override
  String get debugLabel => 'appearance_corner_radius:$cornerRadius';

  @override
  void send() {
    AppearanceCommandSetCornerRadius(
      cornerRadius: cornerRadius,
    ).sendSignalToRust();
  }
}

class _AppearanceSetAccentHueIntent extends AppearanceIntent {
  const _AppearanceSetAccentHueIntent(this.accentHue);

  final int accentHue;

  @override
  String get debugLabel => 'appearance_accent_hue:$accentHue';

  @override
  void send() {
    AppearanceCommandSetAccentHue(accentHue: accentHue).sendSignalToRust();
  }
}

class _AppearanceRestoreDefaultsIntent extends AppearanceIntent {
  const _AppearanceRestoreDefaultsIntent();

  @override
  String get debugLabel => 'appearance_restore_defaults';

  @override
  void send() => const AppearanceCommandRestoreDefaults().sendSignalToRust();
}

sealed class ModuleIntent extends RustIntent {
  const ModuleIntent();

  const factory ModuleIntent.setEnabled({
    required ModuleId module,
    required bool enabled,
  }) = _ModuleSetEnabledIntent;
}

class _ModuleSetEnabledIntent extends ModuleIntent {
  const _ModuleSetEnabledIntent({required this.module, required this.enabled});

  final ModuleId module;
  final bool enabled;

  @override
  String get debugLabel => 'module_enabled:${module.name}:$enabled';

  @override
  void send() {
    ModuleCommandSetEnabled(
      module: module,
      enabled: enabled,
    ).sendSignalToRust();
  }
}

sealed class WorkspaceSettingsIntent extends RustIntent {
  const WorkspaceSettingsIntent();

  const factory WorkspaceSettingsIntent.setIndicatorStyle(
    WorkspaceIndicatorStyle indicatorStyle,
  ) = _WorkspaceSettingsSetIndicatorStyleIntent;

  const factory WorkspaceSettingsIntent.setClickable({
    required bool clickable,
  }) = _WorkspaceSettingsSetClickableIntent;

  const factory WorkspaceSettingsIntent.setVisibleRange(
    WorkspaceVisibleRange visibleRange,
  ) = _WorkspaceSettingsSetVisibleRangeIntent;
}

class _WorkspaceSettingsSetIndicatorStyleIntent
    extends WorkspaceSettingsIntent {
  const _WorkspaceSettingsSetIndicatorStyleIntent(this.indicatorStyle);

  final WorkspaceIndicatorStyle indicatorStyle;

  @override
  String get debugLabel => 'workspace_indicator_style:${indicatorStyle.name}';

  @override
  void send() {
    WorkspaceSettingsCommandSetIndicatorStyle(
      indicatorStyle: indicatorStyle,
    ).sendSignalToRust();
  }
}

class _WorkspaceSettingsSetClickableIntent extends WorkspaceSettingsIntent {
  const _WorkspaceSettingsSetClickableIntent({required this.clickable});

  final bool clickable;

  @override
  String get debugLabel => 'workspace_clickable:$clickable';

  @override
  void send() {
    WorkspaceSettingsCommandSetClickable(
      clickable: clickable,
    ).sendSignalToRust();
  }
}

class _WorkspaceSettingsSetVisibleRangeIntent extends WorkspaceSettingsIntent {
  const _WorkspaceSettingsSetVisibleRangeIntent(this.visibleRange);

  final WorkspaceVisibleRange visibleRange;

  @override
  String get debugLabel => 'workspace_visible_range:${visibleRange.name}';

  @override
  void send() {
    WorkspaceSettingsCommandSetVisibleRange(
      visibleRange: visibleRange,
    ).sendSignalToRust();
  }
}

class _BrightnessSetLevelIntent extends BrightnessIntent {
  const _BrightnessSetLevelIntent({required this.value});

  final int value;

  @override
  String get debugLabel => 'brightness_level:$value';

  @override
  void send() => BrightnessSetLevel(value: value).sendSignalToRust();
}

sealed class NightLightIntent extends RustIntent {
  const NightLightIntent();

  const factory NightLightIntent.setEnabled({required bool enabled}) =
      _NightLightSetEnabledIntent;

  const factory NightLightIntent.setTemperature({required int temperature}) =
      _NightLightSetTemperatureIntent;
}

class _NightLightSetEnabledIntent extends NightLightIntent {
  const _NightLightSetEnabledIntent({required this.enabled});

  final bool enabled;

  @override
  String get debugLabel => 'night_light_enabled:$enabled';

  @override
  void send() => NightLightSetEnabled(enabled: enabled).sendSignalToRust();
}

class _NightLightSetTemperatureIntent extends NightLightIntent {
  const _NightLightSetTemperatureIntent({required this.temperature});

  final int temperature;

  @override
  String get debugLabel => 'night_light_temperature:$temperature';

  @override
  void send() =>
      NightLightSetTemperature(temperature: temperature).sendSignalToRust();
}

sealed class CaffeineIntent extends RustIntent {
  const CaffeineIntent();

  const factory CaffeineIntent.setEnabled({required bool enabled}) =
      _CaffeineSetEnabledIntent;
}

class _CaffeineSetEnabledIntent extends CaffeineIntent {
  const _CaffeineSetEnabledIntent({required this.enabled});

  final bool enabled;

  @override
  String get debugLabel => 'caffeine_enabled:$enabled';

  @override
  void send() => CaffeineSetEnabled(enabled: enabled).sendSignalToRust();
}

sealed class ScheduleIntent extends RustIntent {
  const ScheduleIntent();

  const factory ScheduleIntent.setDailyWindow({
    required ScheduleAction action,
    required bool enabled,
    required int startHour,
    required int stopHour,
  }) = _ScheduleSetDailyWindowIntent;
}

class _ScheduleSetDailyWindowIntent extends ScheduleIntent {
  const _ScheduleSetDailyWindowIntent({
    required this.action,
    required this.enabled,
    required this.startHour,
    required this.stopHour,
  });

  final ScheduleAction action;
  final bool enabled;
  final int startHour;
  final int stopHour;

  @override
  String get debugLabel =>
      'schedule_daily_window:${action.name}:$enabled:$startHour:$stopHour';

  @override
  void send() {
    ScheduleCommandSetDailyWindow(
      action: action,
      enabled: enabled,
      startHour: startHour,
      stopHour: stopHour,
    ).sendSignalToRust();
  }
}

sealed class PowerIntent extends RustIntent {
  const PowerIntent();

  const factory PowerIntent.setProfile(PowerProfile profile) =
      _PowerSetProfileIntent;
}

class _PowerSetProfileIntent extends PowerIntent {
  const _PowerSetProfileIntent(this.profile);

  final PowerProfile profile;

  @override
  String get debugLabel => 'power_profile:${profile.name}';

  @override
  void send() => PowerSetProfile(profile: profile).sendSignalToRust();
}

sealed class ClockIntent extends RustIntent {
  const ClockIntent();

  const factory ClockIntent.calendar(CalendarCommand command) =
      _ClockCalendarIntent;
}

class _ClockCalendarIntent extends ClockIntent {
  const _ClockCalendarIntent(this.command);

  final CalendarCommand command;

  @override
  String get debugLabel => 'clock_calendar:${command.name}';

  @override
  void send() => ClockCalendarRequest(command: command).sendSignalToRust();
}

sealed class ScreenshotIntent extends RustIntent {
  const ScreenshotIntent();

  const factory ScreenshotIntent.capture(ScreenshotMode mode) =
      _ScreenshotCaptureIntent;
}

class _ScreenshotCaptureIntent extends ScreenshotIntent {
  const _ScreenshotCaptureIntent(this.mode);

  final ScreenshotMode mode;

  @override
  String get debugLabel => 'screenshot_capture:${mode.name}';

  @override
  void send() => ScreenshotCaptureRequest(mode: mode).sendSignalToRust();
}

sealed class ColorPickerIntent extends RustIntent {
  const ColorPickerIntent();

  const factory ColorPickerIntent.pick() = _ColorPickIntent;
}

class _ColorPickIntent extends ColorPickerIntent {
  const _ColorPickIntent();

  @override
  String get debugLabel => 'color_pick';

  @override
  void send() => const ColorPickRequest().sendSignalToRust();
}

sealed class RecordingIntent extends RustIntent {
  const RecordingIntent();

  const factory RecordingIntent.toggle(RecordingMode mode) =
      _RecordingToggleIntent;
}

class _RecordingToggleIntent extends RecordingIntent {
  const _RecordingToggleIntent(this.mode);

  final RecordingMode mode;

  @override
  String get debugLabel => 'recording_toggle:${mode.name}';

  @override
  void send() => RecordingRequest(
    action: RecordingAction.toggle,
    mode: mode,
  ).sendSignalToRust();
}

sealed class LauncherIntent extends RustIntent {
  const LauncherIntent();

  const factory LauncherIntent.query(String query) = _LauncherQueryIntent;

  const factory LauncherIntent.launch(String id) = _LauncherLaunchIntent;
}

class _LauncherQueryIntent extends LauncherIntent {
  const _LauncherQueryIntent(this.query);

  final String query;

  @override
  String get debugLabel => 'app_launcher_query';

  @override
  void send() => AppLauncherQuery(query: query).sendSignalToRust();
}

class _LauncherLaunchIntent extends LauncherIntent {
  const _LauncherLaunchIntent(this.id);

  final String id;

  @override
  String get debugLabel => 'app_launch:$id';

  @override
  void send() => AppLaunchRequest(id: id).sendSignalToRust();
}

sealed class NotificationIntent extends RustIntent {
  const NotificationIntent();

  const factory NotificationIntent.dismiss(int id) = _NotificationDismissIntent;

  const factory NotificationIntent.clearAll() = _NotificationClearAllIntent;

  const factory NotificationIntent.setDoNotDisturb({required bool enabled}) =
      _NotificationSetDoNotDisturbIntent;
}

class _NotificationDismissIntent extends NotificationIntent {
  const _NotificationDismissIntent(this.id);

  final int id;

  @override
  String get debugLabel => 'notification_dismiss:$id';

  @override
  void send() => NotificationDismissRequest(id: id).sendSignalToRust();
}

class _NotificationClearAllIntent extends NotificationIntent {
  const _NotificationClearAllIntent();

  @override
  String get debugLabel => 'notification_clear';

  @override
  void send() => const NotificationClearRequest().sendSignalToRust();
}

class _NotificationSetDoNotDisturbIntent extends NotificationIntent {
  const _NotificationSetDoNotDisturbIntent({required this.enabled});

  final bool enabled;

  @override
  String get debugLabel => 'notification_dnd:$enabled';

  @override
  void send() =>
      NotificationSetDoNotDisturb(enabled: enabled).sendSignalToRust();
}

sealed class SessionIntent extends RustIntent {
  const SessionIntent();

  const factory SessionIntent.execute(SessionAction action) =
      _SessionExecuteIntent;
}

class _SessionExecuteIntent extends SessionIntent {
  const _SessionExecuteIntent(this.action);

  final SessionAction action;

  @override
  String get debugLabel => 'session_command:${action.name}';

  @override
  void send() => SessionCommand(action: action).sendSignalToRust();
}

sealed class ShortcutSettingsIntent extends RustIntent {
  const ShortcutSettingsIntent();

  const factory ShortcutSettingsIntent.load() = _ShortcutSettingsLoadIntent;

  const factory ShortcutSettingsIntent.setBinding({
    required ShortcutSettingId shortcut,
    required ShortcutBindingInput binding,
  }) = _ShortcutSettingsSetBindingIntent;

  const factory ShortcutSettingsIntent.disable(ShortcutSettingId shortcut) =
      _ShortcutSettingsDisableIntent;

  const factory ShortcutSettingsIntent.reset(ShortcutSettingId shortcut) =
      _ShortcutSettingsResetIntent;
}

class _ShortcutSettingsLoadIntent extends ShortcutSettingsIntent {
  const _ShortcutSettingsLoadIntent();

  @override
  String get debugLabel => 'shortcut_settings_load';

  @override
  void send() => const ShortcutSettingsRequestLoad().sendSignalToRust();
}

class _ShortcutSettingsSetBindingIntent extends ShortcutSettingsIntent {
  const _ShortcutSettingsSetBindingIntent({
    required this.shortcut,
    required this.binding,
  });

  final ShortcutSettingId shortcut;
  final ShortcutBindingInput binding;

  @override
  String get debugLabel => 'shortcut_settings_set:${shortcut.name}';

  @override
  void send() {
    ShortcutSettingsRequestSetBinding(
      shortcut: shortcut,
      binding: binding,
    ).sendSignalToRust();
  }
}

class _ShortcutSettingsDisableIntent extends ShortcutSettingsIntent {
  const _ShortcutSettingsDisableIntent(this.shortcut);

  final ShortcutSettingId shortcut;

  @override
  String get debugLabel => 'shortcut_settings_disable:${shortcut.name}';

  @override
  void send() {
    ShortcutSettingsRequestDisable(shortcut: shortcut).sendSignalToRust();
  }
}

class _ShortcutSettingsResetIntent extends ShortcutSettingsIntent {
  const _ShortcutSettingsResetIntent(this.shortcut);

  final ShortcutSettingId shortcut;

  @override
  String get debugLabel => 'shortcut_settings_reset:${shortcut.name}';

  @override
  void send() {
    ShortcutSettingsRequestReset(shortcut: shortcut).sendSignalToRust();
  }
}

sealed class TrayIntent extends RustIntent {
  const TrayIntent();

  const factory TrayIntent.activate({
    required String id,
    required int x,
    required int y,
    required TrayActivationKind kind,
  }) = _TrayActivateIntent;

  const factory TrayIntent.activateMenuItem({
    required String itemId,
    required int menuItemId,
  }) = _TrayMenuItemActivateIntent;
}

class _TrayActivateIntent extends TrayIntent {
  const _TrayActivateIntent({
    required this.id,
    required this.x,
    required this.y,
    required this.kind,
  });

  final String id;
  final int x;
  final int y;
  final TrayActivationKind kind;

  @override
  String get debugLabel => 'tray_activate:${kind.name}:$id';

  @override
  void send() =>
      TrayActivateRequest(id: id, x: x, y: y, kind: kind).sendSignalToRust();
}

class _TrayMenuItemActivateIntent extends TrayIntent {
  const _TrayMenuItemActivateIntent({
    required this.itemId,
    required this.menuItemId,
  });

  final String itemId;
  final int menuItemId;

  @override
  String get debugLabel => 'tray_menu_item:$itemId:$menuItemId';

  @override
  void send() {
    TrayMenuItemActivateRequest(
      itemId: itemId,
      menuItemId: menuItemId,
    ).sendSignalToRust();
  }
}

sealed class WorkspaceIntent extends RustIntent {
  const WorkspaceIntent();

  const factory WorkspaceIntent.relative(int delta, String? monitorName) =
      _WorkspaceRelativeIntent;

  const factory WorkspaceIntent.absolute(int target, String? monitorName) =
      _WorkspaceAbsoluteIntent;
}

class _WorkspaceRelativeIntent extends WorkspaceIntent {
  const _WorkspaceRelativeIntent(this.delta, this.monitorName);

  final int delta;
  final String? monitorName;

  @override
  String get debugLabel => 'workspace_delta:$delta';

  @override
  void send() {
    WorkspaceSwitch(
      kind: WorkspaceSwitchKind.relative,
      value: delta,
      monitorName: monitorName,
    ).sendSignalToRust();
  }
}

class _WorkspaceAbsoluteIntent extends WorkspaceIntent {
  const _WorkspaceAbsoluteIntent(this.target, this.monitorName);

  final int target;
  final String? monitorName;

  @override
  String get debugLabel => 'workspace_target:$target';

  @override
  void send() {
    WorkspaceSwitch(
      kind: WorkspaceSwitchKind.absolute,
      value: target,
      monitorName: monitorName,
    ).sendSignalToRust();
  }
}
