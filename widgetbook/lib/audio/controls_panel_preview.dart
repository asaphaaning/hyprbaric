import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';

import '../use_cases/controls/controls_fixtures.dart';

/// Interactive quick-controls preview shared by Widgetbook and web embeds.
class ControlsPanelPreview extends StatefulWidget {
  const ControlsPanelPreview({
    super.key,
    this.initialScenario = ControlsFixtures.ready,
  });

  const ControlsPanelPreview.landing({super.key})
    : initialScenario = ControlsFixtures.landing;

  final ControlsScenario initialScenario;

  @override
  State<ControlsPanelPreview> createState() => _ControlsPanelPreviewState();
}

class _ControlsPanelPreviewState extends State<ControlsPanelPreview> {
  late ControlsScenario _scenario;

  @override
  void initState() {
    super.initState();
    _scenario = widget.initialScenario;
  }

  @override
  Widget build(BuildContext context) {
    return ControlsPanel(
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      onCaptureScreenshot: _ignoreScreenshot,
      onPickColor: _noop,
      onToggleRecording: _toggleRecording,
      onOpenSettings: _noop,
      onToast: _ignoreToast,
      dndEnabled: _scenario.dndEnabled,
      onSetDoNotDisturb: (bool enabled) {
        setState(() => _scenario = _scenario.copyWith(dndEnabled: enabled));
      },
      nightLightStatus: _scenario.nightLightStatus,
      onSetNightLight: (bool enabled) {
        setState(() {
          _scenario = _scenario.copyWith(
            nightLightStatus: NightLightStatusAvailable(
              enabled: enabled,
              temperature: 3500,
            ),
          );
        });
      },
      caffeineStatus: _scenario.caffeineStatus,
      onSetCaffeine: (bool enabled) {
        setState(() {
          _scenario = _scenario.copyWith(
            caffeineStatus: CaffeineStatusAvailable(enabled: enabled),
          );
        });
      },
      recordingStatus: _scenario.recordingStatus,
    );
  }

  void _toggleRecording() {
    final RecordingStatus next = switch (_scenario.recordingStatus) {
      RecordingStatusRecording() ||
      RecordingStatusStopping() => const RecordingStatusIdle(),
      _ => RecordingStatusRecording(
        mode: RecordingMode.region,
        path: '/tmp/hyprbaric-preview-recording.mp4',
        startedAtMs: Uint64.fromBigInt(
          BigInt.from(DateTime.now().millisecondsSinceEpoch),
        ),
      ),
    };

    setState(() => _scenario = _scenario.copyWith(recordingStatus: next));
  }
}

void _noop() {}

void _ignoreScreenshot(ScreenshotMode _) {}

void _ignoreToast(String _) {}
