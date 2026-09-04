import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'control_capture_pads.dart';
import 'control_inspect_button.dart';
import 'control_rocker.dart';
import 'control_settings_row.dart';
import 'controls_chrome.dart';

const ControlAvailability _magnifierUnavailable =
    ControlAvailability.unavailable('Magnifier support is not available yet');
const ControlAvailability _keyboardLockUnavailable =
    ControlAvailability.unavailable(
      'Keyboard lock support is not available yet',
    );

class ControlsPanel extends StatelessWidget {
  const ControlsPanel({
    super.key,
    required this.borderRadius,
    required this.onCaptureScreenshot,
    required this.onPickColor,
    required this.onToggleRecording,
    required this.onOpenSettings,
    required this.onToast,
    required this.dndEnabled,
    required this.onSetDoNotDisturb,
    required this.nightLightStatus,
    required this.onSetNightLight,
    required this.caffeineStatus,
    required this.onSetCaffeine,
    this.recordingStatus,
    this.shortcutLabels = const <ShortcutSettingId, String>{},
  });

  final BorderRadius borderRadius;
  final ValueChanged<ScreenshotMode> onCaptureScreenshot;
  final VoidCallback onPickColor;
  final VoidCallback onToggleRecording;
  final VoidCallback onOpenSettings;
  final ValueChanged<String> onToast;
  final bool dndEnabled;
  final ValueChanged<bool> onSetDoNotDisturb;
  final NightLightStatus? nightLightStatus;
  final ValueChanged<bool> onSetNightLight;
  final CaffeineStatus? caffeineStatus;
  final ValueChanged<bool> onSetCaffeine;
  final RecordingStatus? recordingStatus;

  /// The user's effective chords, keyed by shortcut. A missing entry renders
  /// no hint at all rather than a guessed default.
  final Map<ShortcutSettingId, String> shortcutLabels;

  /// Runs [action] when available, otherwise surfaces the reason.
  VoidCallback _guard(ControlAvailability availability, VoidCallback action) {
    final String? reason = availability.reason;
    return reason == null ? action : () => onToast(reason);
  }

  @override
  Widget build(BuildContext context) {
    final ControlAvailability recording = recordingStatus.availability;
    final ControlAvailability nightLight = nightLightStatus.availability;
    final ControlAvailability caffeine = caffeineStatus.availability;

    return HyprPopoverPanel(
      borderRadius: borderRadius,
      constraints: const BoxConstraints(minWidth: 432, maxWidth: 432),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          HyprConsoleTray(
            label: 'Capture',
            child: SizedBox(
              height: 92,
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: 10,
                    child: ControlCapturePad(
                      label: 'Region',
                      shortcut: shortcutLabels[ShortcutSettingId.captureRegion],
                      icon: Iconsax.maximize_3_copy,
                      onPressed: () =>
                          onCaptureScreenshot(ScreenshotMode.region),
                    ),
                  ),
                  const SizedBox(width: HyprSpacing.lg + HyprSpacing.hairline),
                  Expanded(
                    flex: 10,
                    child: ControlCapturePad(
                      label: 'Window',
                      shortcut: shortcutLabels[ShortcutSettingId.captureWindow],
                      icon: Iconsax.monitor_copy,
                      onPressed: () =>
                          onCaptureScreenshot(ScreenshotMode.window),
                    ),
                  ),
                  const SizedBox(width: HyprSpacing.lg + HyprSpacing.hairline),
                  Expanded(
                    flex: 10,
                    child: ControlCapturePad(
                      label: 'Full',
                      shortcut:
                          shortcutLabels[ShortcutSettingId.captureFullScreen],
                      icon: Iconsax.maximize_2_copy,
                      onPressed: () =>
                          onCaptureScreenshot(ScreenshotMode.fullScreen),
                    ),
                  ),
                  const SizedBox(width: HyprSpacing.lg + HyprSpacing.hairline),
                  Expanded(
                    flex: 14,
                    child: ControlRecordPad(
                      active: recordingStatus.active,
                      availability: recording,
                      phase: recordingStatus.phase,
                      startedAtMs: recordingStatus.startedAtMs,
                      shortcut:
                          shortcutLabels[ShortcutSettingId.toggleRecording],
                      onPressed: _guard(recording, onToggleRecording),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: HyprSpacing.xxl),
          HyprConsoleTray(
            label: 'Inspect',
            child: Row(
              children: <Widget>[
                Expanded(
                  child: ControlInspectButton(
                    label: 'Color Pick',
                    shortcut: shortcutLabels[ShortcutSettingId.colorPick],
                    icon: Iconsax.colorfilter_copy,
                    onPressed: onPickColor,
                  ),
                ),
                const SizedBox(width: HyprSpacing.lg + HyprSpacing.hairline),
                Expanded(
                  child: ControlInspectButton(
                    label: 'Magnify',
                    icon: Iconsax.search_zoom_in_1_copy,
                    availability: _magnifierUnavailable,
                    onPressed: _guard(_magnifierUnavailable, () {}),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: HyprSpacing.xxl),
          HyprConsoleTray(
            label: 'Toggles',
            child: SizedBox(
              height: 90,
              child: DecoratedBox(
                decoration: controlWellDecoration(),
                child: Padding(
                  padding: const EdgeInsets.all(HyprSpacing.md),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: ControlRocker(
                          key: const ValueKey<String>('controls-dnd-rocker'),
                          label: 'DND',
                          icon: Iconsax.minus_cirlce_copy,
                          value: dndEnabled,
                          onChanged: onSetDoNotDisturb,
                        ),
                      ),
                      const SizedBox(width: HyprSpacing.md),
                      Expanded(
                        child: ControlRocker(
                          key: const ValueKey<String>(
                            'controls-night-light-rocker',
                          ),
                          label: 'Night',
                          icon: Iconsax.moon_copy,
                          value: nightLightStatus.enabled,
                          availability: nightLight,
                          onChanged: _guarded(nightLight, onSetNightLight),
                        ),
                      ),
                      const SizedBox(width: HyprSpacing.md),
                      Expanded(
                        child: ControlRocker(
                          key: const ValueKey<String>('controls-kbd-rocker'),
                          label: 'Kbd',
                          icon: Iconsax.keyboard_copy,
                          value: false,
                          availability: _keyboardLockUnavailable,
                          onChanged: _guarded(_keyboardLockUnavailable, (_) {}),
                        ),
                      ),
                      const SizedBox(width: HyprSpacing.md),
                      Expanded(
                        child: ControlRocker(
                          key: const ValueKey<String>(
                            'controls-caffeine-rocker',
                          ),
                          label: 'Caffeine',
                          icon: Iconsax.coffee_copy,
                          value: caffeineStatus.enabled,
                          availability: caffeine,
                          onChanged: _guarded(caffeine, onSetCaffeine),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: HyprSpacing.section),
          ControlSettingsRow(
            onPressed: onOpenSettings,
            shortcut: shortcutLabels[ShortcutSettingId.barSettings],
          ),
        ],
      ),
    );
  }

  /// [_guard] for the value-carrying callbacks the rockers take.
  ValueChanged<bool> _guarded(
    ControlAvailability availability,
    ValueChanged<bool> action,
  ) {
    final String? reason = availability.reason;
    return reason == null ? action : (_) => onToast(reason);
  }
}

extension on NightLightStatus? {
  bool get enabled => switch (this) {
    NightLightStatusAvailable(:final enabled) => enabled,
    NightLightStatusUnavailable(:final enabled) => enabled,
    _ => false,
  };

  ControlAvailability get availability => switch (this) {
    NightLightStatusAvailable() => const ControlAvailability.available(),
    NightLightStatusUnavailable(:final message) =>
      ControlAvailability.unavailable(message),
    _ => const ControlAvailability.unavailable('Night light is unavailable'),
  };
}

extension on CaffeineStatus? {
  bool get enabled => switch (this) {
    CaffeineStatusAvailable(:final enabled) => enabled,
    _ => false,
  };

  ControlAvailability get availability => switch (this) {
    CaffeineStatusAvailable() => const ControlAvailability.available(),
    CaffeineStatusUnavailable(:final message) =>
      ControlAvailability.unavailable(message),
    _ => const ControlAvailability.unavailable('Caffeine is unavailable'),
  };
}

extension on RecordingStatus? {
  ControlAvailability get availability => switch (this) {
    RecordingStatusIdle() ||
    RecordingStatusSelecting() ||
    RecordingStatusRecording() ||
    RecordingStatusStopping() => const ControlAvailability.available(),
    RecordingStatusUnavailable(:final message) =>
      ControlAvailability.unavailable(message),
    _ => const ControlAvailability.unavailable(
      'Screen recording is unavailable',
    ),
  };

  bool get active =>
      this is RecordingStatusSelecting ||
      this is RecordingStatusRecording ||
      this is RecordingStatusStopping;

  String get phase => switch (this) {
    RecordingStatusIdle() => 'STBY',
    RecordingStatusSelecting() => 'SEL',
    RecordingStatusRecording() => 'REC',
    RecordingStatusStopping() => 'STOP',
    RecordingStatusUnavailable() => 'N/A',
    _ => 'N/A',
  };

  /// Non-null only while a capture is actually running, which is what drives
  /// the record pad's ticker.
  int? get startedAtMs => switch (this) {
    RecordingStatusRecording(:final startedAtMs) => startedAtMs.toInt(),
    RecordingStatusStopping(:final startedAtMs) => startedAtMs.toInt(),
    _ => null,
  };
}
