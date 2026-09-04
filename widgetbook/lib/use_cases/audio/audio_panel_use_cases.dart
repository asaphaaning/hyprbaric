import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';
import 'audio_fixtures.dart';

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
  return const _InteractiveAudioPanelStory();
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

class _InteractiveAudioPanelStory extends StatefulWidget {
  const _InteractiveAudioPanelStory();

  @override
  State<_InteractiveAudioPanelStory> createState() =>
      _InteractiveAudioPanelStoryState();
}

class _InteractiveAudioPanelStoryState
    extends State<_InteractiveAudioPanelStory> {
  late AudioStatusAvailable audio;
  late BrightnessStatusAvailable brightness;

  @override
  void initState() {
    super.initState();
    audio = AudioFixtures.ready;
    brightness = AudioFixtures.brightness;
  }

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: AudioPanel(
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        status: AudioFixtures.status(audio),
        brightnessStatus: AudioFixtures.brightnessStatus(brightness),
        onSetVolume: (AudioEndpointKind kind, int volume) {
          setState(() {
            audio = _withEndpoint(audio, kind, volume: volume);
          });
        },
        onSetMuted: (AudioEndpointKind kind, {required bool muted}) {
          setState(() {
            audio = _withEndpoint(audio, kind, muted: muted);
          });
        },
        onSetBrightness: (int value) {
          setState(() {
            brightness = BrightnessStatusAvailable(
              device: brightness.device,
              value: value,
            );
          });
        },
        onOpenMixer: _noop,
      ),
    );
  }
}

AudioStatusAvailable _withEndpoint(
  AudioStatusAvailable status,
  AudioEndpointKind kind, {
  int? volume,
  bool? muted,
}) {
  return switch (kind) {
    AudioEndpointKind.output => AudioStatusAvailable(
      output: status.output == null
          ? null
          : AudioFixtures.updateEndpoint(
              status.output!,
              volume: volume,
              muted: muted,
            ),
      input: status.input,
    ),
    AudioEndpointKind.input => AudioStatusAvailable(
      output: status.output,
      input: status.input == null
          ? null
          : AudioFixtures.updateEndpoint(
              status.input!,
              volume: volume,
              muted: muted,
            ),
    ),
  };
}

void _noop() {}

void _ignoreInt(int _) {}

void _ignoreVolume(AudioEndpointKind _, int _) {}

void _ignoreMuted(AudioEndpointKind _, {required bool muted}) {}
