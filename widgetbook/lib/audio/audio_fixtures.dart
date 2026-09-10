import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/audio_embed.dart';

/// Typed endpoint and display snapshots for mixer previews and stories.
abstract final class AudioFixtures {
  static const AudioOutputsAvailable outputs = AudioOutputsAvailable(
    selected: AudioOutputId(name: 'evo4'),
    devices: <AudioOutput>[
      AudioOutput(
        id: AudioOutputId(name: 'evo4'),
        name: 'EVO4',
      ),
      AudioOutput(
        id: AudioOutputId(name: 'speakers'),
        name: 'Built-in Speakers',
      ),
      AudioOutput(
        id: AudioOutputId(name: 'hdmi'),
        name: 'DisplayPort / HDMI',
      ),
    ],
  );
  static const AudioEndpoint output = AudioEndpoint(
    kind: AudioEndpointKind.output,
    id: 'output-built-in',
    name: 'EVO4',
    volume: 19,
    muted: false,
  );

  static const AudioEndpoint input = AudioEndpoint(
    kind: AudioEndpointKind.input,
    id: 'input-built-in',
    name: 'Insta360 Link 2C Mono',
    volume: 82,
    muted: false,
  );

  static const BrightnessStatusAvailable brightness = BrightnessStatusAvailable(
    device: 'eDP-1',
    value: 80,
  );

  static const AudioStatusAvailable ready = AudioStatusAvailable(
    outputs: outputs,
    output: output,
    input: input,
  );

  static const AudioStatusAvailable muted = AudioStatusAvailable(
    outputs: outputs,
    output: AudioEndpoint(
      kind: AudioEndpointKind.output,
      id: 'output-built-in',
      name: 'EVO4',
      volume: 19,
      muted: true,
    ),
    input: input,
  );

  static const AudioStatusAvailable outputOnly = AudioStatusAvailable(
    outputs: outputs,
    output: output,
  );

  static const AudioStatusUnavailable unavailable = AudioStatusUnavailable(
    message: 'PipeWire is unavailable',
  );

  static AsyncValue<AudioStatus> get loadingAudio =>
      const AsyncValue<AudioStatus>.loading();

  static AsyncValue<BrightnessStatus> get loadingBrightness =>
      const AsyncValue<BrightnessStatus>.loading();

  static AsyncValue<AudioStatus> status(AudioStatus value) =>
      AsyncValue<AudioStatus>.data(value);

  static AsyncValue<BrightnessStatus> brightnessStatus(
    BrightnessStatus value,
  ) => AsyncValue<BrightnessStatus>.data(value);

  static AudioEndpoint updateEndpoint(
    AudioEndpoint endpoint, {
    int? volume,
    bool? muted,
  }) {
    return AudioEndpoint(
      kind: endpoint.kind,
      id: endpoint.id,
      name: endpoint.name,
      volume: volume ?? endpoint.volume,
      muted: muted ?? endpoint.muted,
    );
  }
}
