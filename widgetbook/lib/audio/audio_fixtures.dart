import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/audio_embed.dart';

/// Typed endpoint and display snapshots for mixer previews and stories.
abstract final class AudioFixtures {
  static const AudioEndpoint output = AudioEndpoint(
    kind: AudioEndpointKind.output,
    id: 'output-built-in',
    name: 'Built-in · Analog Stereo',
    volume: 75,
    muted: false,
  );

  static const AudioEndpoint input = AudioEndpoint(
    kind: AudioEndpointKind.input,
    id: 'input-built-in',
    name: 'Built-in Microphone',
    volume: 42,
    muted: false,
  );

  static const BrightnessStatusAvailable brightness = BrightnessStatusAvailable(
    device: 'eDP-1',
    value: 75,
  );

  static const AudioStatusAvailable ready = AudioStatusAvailable(
    output: output,
    input: input,
  );

  static const AudioStatusAvailable muted = AudioStatusAvailable(
    output: AudioEndpoint(
      kind: AudioEndpointKind.output,
      id: 'output-built-in',
      name: 'Built-in · Analog Stereo',
      volume: 75,
      muted: true,
    ),
    input: input,
  );

  static const AudioStatusAvailable outputOnly = AudioStatusAvailable(
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
