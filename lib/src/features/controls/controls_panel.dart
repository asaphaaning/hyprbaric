import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../bindings/bindings.dart';
import 'control_capture_pads.dart';
import 'control_inspect_button.dart';
import 'control_rocker.dart';
import 'control_settings_row.dart';
import 'controls_chrome.dart';

class ControlsPanel extends StatefulWidget {
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

  @override
  State<ControlsPanel> createState() => ControlsPanelState();
}

class ControlsPanelState extends State<ControlsPanel> {
  Timer? _recordingTicker;

  @override
  void initState() {
    super.initState();
    _syncRecordingTicker();
  }

  @override
  void didUpdateWidget(covariant ControlsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRecordingTicker();
  }

  @override
  void dispose() {
    _recordingTicker?.cancel();
    super.dispose();
  }

  void _syncRecordingTicker() {
    if (widget.recordingStatus.ticks && _recordingTicker == null) {
      _recordingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {});
        }
      });
      return;
    }
    if (!widget.recordingStatus.ticks && _recordingTicker != null) {
      _recordingTicker?.cancel();
      _recordingTicker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ControlChassis(
      borderRadius: widget.borderRadius,
      constraints: const BoxConstraints(minWidth: 432, maxWidth: 432),
      padding: const EdgeInsets.all(17),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ControlSectionTray(
            label: 'Capture',
            child: SizedBox(
              height: 92,
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: 10,
                    child: ControlCapturePad(
                      label: 'Region',
                      shortcut: '⇧ Mod 4',
                      icon: Iconsax.maximize_3_copy,
                      onPressed: () =>
                          widget.onCaptureScreenshot(ScreenshotMode.region),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    flex: 10,
                    child: ControlCapturePad(
                      label: 'Window',
                      shortcut: 'Mod W',
                      icon: Iconsax.monitor_copy,
                      onPressed: () =>
                          widget.onCaptureScreenshot(ScreenshotMode.window),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    flex: 10,
                    child: ControlCapturePad(
                      label: 'Full',
                      shortcut: 'PrtSc',
                      icon: Iconsax.maximize_2_copy,
                      onPressed: () =>
                          widget.onCaptureScreenshot(ScreenshotMode.fullScreen),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    flex: 14,
                    child: ControlRecordPad(
                      active: widget.recordingStatus.active,
                      enabled: widget.recordingStatus.isAvailable,
                      phase: widget.recordingStatus.phase,
                      elapsed: widget.recordingStatus.elapsed,
                      shortcut: 'Mod R',
                      onPressed: widget.recordingStatus.isAvailable
                          ? widget.onToggleRecording
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          ControlSectionTray(
            label: 'Inspect',
            child: Row(
              children: <Widget>[
                Expanded(
                  child: ControlInspectButton(
                    label: 'Color Pick',
                    shortcut: 'Mod P',
                    icon: Iconsax.colorfilter_copy,
                    onPressed: widget.onPickColor,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: ControlInspectButton(
                    label: 'Magnify',
                    shortcut: 'Mod M',
                    icon: Iconsax.search_zoom_in_1_copy,
                    onPressed: () => widget.onToast(
                      'Magnifier support is not available yet',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ControlSectionTray(
            label: 'Toggles',
            child: SizedBox(
              height: 90,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      ControlColors.well,
                      ControlColors.wellBottom,
                    ],
                  ),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: ControlRocker(
                          key: const ValueKey<String>('controls-dnd-rocker'),
                          label: 'DND',
                          icon: Iconsax.minus_cirlce_copy,
                          value: widget.dndEnabled,
                          onChanged: widget.onSetDoNotDisturb,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: ControlRocker(
                          key: const ValueKey<String>(
                            'controls-night-light-rocker',
                          ),
                          label: 'Night',
                          icon: Iconsax.moon_copy,
                          value: widget.nightLightStatus.enabled,
                          enabled: widget.nightLightStatus.isAvailable,
                          onChanged: widget.onSetNightLight,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: ControlRocker(
                          key: const ValueKey<String>('controls-kbd-rocker'),
                          label: 'Kbd',
                          icon: Iconsax.keyboard_copy,
                          value: false,
                          onChanged: (_) => widget.onToast(
                            'Keyboard lock support is not available yet',
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: ControlRocker(
                          key: const ValueKey<String>(
                            'controls-caffeine-rocker',
                          ),
                          label: 'Caffeine',
                          icon: Iconsax.coffee_copy,
                          value: widget.caffeineStatus.enabled,
                          enabled: widget.caffeineStatus.isAvailable,
                          onChanged: widget.onSetCaffeine,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ControlSettingsRow(onPressed: widget.onOpenSettings),
        ],
      ),
    );
  }
}

extension on NightLightStatus? {
  bool get enabled => switch (this) {
    NightLightStatusAvailable(:final enabled) => enabled,
    NightLightStatusUnavailable(:final enabled) => enabled,
    _ => false,
  };

  bool get isAvailable => this is NightLightStatusAvailable;
}

extension on CaffeineStatus? {
  bool get enabled => switch (this) {
    CaffeineStatusAvailable(:final enabled) => enabled,
    _ => false,
  };

  bool get isAvailable => this is CaffeineStatusAvailable;
}

extension on RecordingStatus? {
  bool get isAvailable =>
      this is RecordingStatusIdle ||
      this is RecordingStatusSelecting ||
      this is RecordingStatusRecording ||
      this is RecordingStatusStopping;

  bool get active =>
      this is RecordingStatusSelecting ||
      this is RecordingStatusRecording ||
      this is RecordingStatusStopping;

  bool get ticks =>
      this is RecordingStatusRecording || this is RecordingStatusStopping;

  String get phase => switch (this) {
    RecordingStatusIdle() => 'STBY',
    RecordingStatusSelecting() => 'SEL',
    RecordingStatusRecording() => 'REC',
    RecordingStatusStopping() => 'STOP',
    RecordingStatusUnavailable() => 'N/A',
    _ => 'N/A',
  };

  String get elapsed {
    final int? startedAtMs = switch (this) {
      RecordingStatusRecording(:final startedAtMs) => startedAtMs.toInt(),
      RecordingStatusStopping(:final startedAtMs) => startedAtMs.toInt(),
      _ => null,
    };
    if (startedAtMs == null) {
      return '00:00';
    }
    final DateTime startedAt = DateTime.fromMillisecondsSinceEpoch(startedAtMs);
    final Duration elapsed = DateTime.now().difference(startedAt);
    final int minutes = elapsed.inMinutes.clamp(0, 99);
    final int seconds = elapsed.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
