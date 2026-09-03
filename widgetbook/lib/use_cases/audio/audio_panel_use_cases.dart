import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../audio/audio_fixtures.dart';
import '../../audio/audio_mixer_preview.dart';
import '../../catalog/catalog_frame.dart';

@UseCase(name: 'Ready', type: AudioPanel, path: '[Widgets]/Audio')
Widget buildReadyAudioPanel(BuildContext context) {
  return _AudioPanelStory(
    audio: AudioFixtures.status(AudioFixtures.ready),
    brightness: AudioFixtures.brightnessStatus(AudioFixtures.brightness),
  );
}

@UseCase(name: 'Muted output', type: AudioPanel, path: '[Widgets]/Audio')
Widget buildMutedAudioPanel(BuildContext context) {
  return _AudioPanelStory(
    audio: AudioFixtures.status(AudioFixtures.muted),
    brightness: AudioFixtures.brightnessStatus(AudioFixtures.brightness),
  );
}

@UseCase(name: 'Output only', type: AudioPanel, path: '[Widgets]/Audio')
Widget buildOutputOnlyAudioPanel(BuildContext context) {
  return _AudioPanelStory(
    audio: AudioFixtures.status(AudioFixtures.outputOnly),
    brightness: AudioFixtures.brightnessStatus(AudioFixtures.brightness),
  );
}

@UseCase(name: 'Loading', type: AudioPanel, path: '[Widgets]/Audio')
Widget buildLoadingAudioPanel(BuildContext context) {
  return _AudioPanelStory(
    audio: AudioFixtures.loadingAudio,
    brightness: AudioFixtures.loadingBrightness,
  );
}

@UseCase(name: 'Unavailable', type: AudioPanel, path: '[Widgets]/Audio')
Widget buildUnavailableAudioPanel(BuildContext context) {
  return _AudioPanelStory(
    audio: AudioFixtures.status(AudioFixtures.unavailable),
    brightness: AudioFixtures.brightnessStatus(
      const BrightnessStatusUnavailable(message: 'No display backlight'),
    ),
  );
}

@UseCase(name: 'Interactive', type: AudioPanel, path: '[Widgets]/Audio')
Widget buildInteractiveAudioPanel(BuildContext context) {
  return const CatalogCanvas(child: AudioMixerPreview());
}

class _AudioPanelStory extends StatelessWidget {
  const _AudioPanelStory({required this.audio, required this.brightness});

  final AsyncValue<AudioStatus> audio;
  final AsyncValue<BrightnessStatus> brightness;

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: AudioPanel(
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        status: audio,
        brightnessStatus: brightness,
        onSetVolume: _ignoreVolume,
        onSetMuted: _ignoreMuted,
        onSetBrightness: _ignoreInt,
        onOpenMixer: _noop,
      ),
    );
  }
}

void _noop() {}

void _ignoreInt(int _) {}

void _ignoreVolume(AudioEndpointKind _, int _) {}

void _ignoreMuted(AudioEndpointKind _, {required bool muted}) {}
