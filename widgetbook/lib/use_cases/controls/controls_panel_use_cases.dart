import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';
import '../../stories/controls_panel_preview.dart';
import 'controls_fixtures.dart';

@UseCase(name: 'Ready', type: ControlsPanel, path: '[Widgets]/Controls')
Widget buildReadyControlsPanel(BuildContext context) {
  return const _ControlsPanelStory(scenario: ControlsFixtures.ready);
}

@UseCase(
  name: 'Active toggles',
  type: ControlsPanel,
  path: '[Widgets]/Controls',
)
Widget buildActiveControlsPanel(BuildContext context) {
  return const _ControlsPanelStory(scenario: ControlsFixtures.active);
}

@UseCase(
  name: 'Selecting recording region',
  type: ControlsPanel,
  path: '[Widgets]/Controls',
)
Widget buildSelectingRecordingControlsPanel(BuildContext context) {
  return const _ControlsPanelStory(
    scenario: ControlsFixtures.selectingRecording,
  );
}

@UseCase(
  name: 'Services unavailable',
  type: ControlsPanel,
  path: '[Widgets]/Controls',
)
Widget buildUnavailableControlsPanel(BuildContext context) {
  return const _ControlsPanelStory(scenario: ControlsFixtures.unavailable);
}

@UseCase(
  name: 'Interactive toggles',
  type: ControlsPanel,
  path: '[Widgets]/Controls',
)
Widget buildInteractiveControlsPanel(BuildContext context) {
  return const CatalogCanvas(child: ControlsPanelPreview());
}

class _ControlsPanelStory extends StatelessWidget {
  const _ControlsPanelStory({required this.scenario});

  final ControlsScenario scenario;

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: ControlsPanel(
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        onCaptureScreenshot: _ignoreScreenshot,
        onPickColor: _noop,
        onToggleRecording: _noop,
        onOpenSettings: _noop,
        onToast: _ignoreToast,
        dndEnabled: scenario.dndEnabled,
        onSetDoNotDisturb: _ignoreToggle,
        nightLightStatus: scenario.nightLightStatus,
        onSetNightLight: _ignoreToggle,
        caffeineStatus: scenario.caffeineStatus,
        onSetCaffeine: _ignoreToggle,
        recordingStatus: scenario.recordingStatus,
      ),
    );
  }
}

void _noop() {}

void _ignoreScreenshot(ScreenshotMode _) {}

void _ignoreToggle(bool _) {}

void _ignoreToast(String _) {}
