import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hyprbaric/audio_embed.dart';

import 'audio_fixtures.dart';

/// Interactive mixer preview shared by the landing embed and Widgetbook.
class AudioMixerPreview extends StatefulWidget {
  const AudioMixerPreview({super.key, this.animateMeters = true});

  final bool animateMeters;

  @override
  State<AudioMixerPreview> createState() => _AudioMixerPreviewState();
}

class _AudioMixerPreviewState extends State<AudioMixerPreview>
    with SingleTickerProviderStateMixin {
  late AudioStatusAvailable _audio;
  late BrightnessStatusAvailable _brightness;
  late final AnimationController _meterClock;

  @override
  void initState() {
    super.initState();
    _audio = AudioFixtures.ready;
    _brightness = AudioFixtures.brightness;
    _meterClock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4320),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMeterClock();
  }

  @override
  void didUpdateWidget(covariant AudioMixerPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animateMeters != widget.animateMeters) {
      _syncMeterClock();
    }
  }

  void _syncMeterClock() {
    final bool motionEnabled =
        widget.animateMeters && !MediaQuery.disableAnimationsOf(context);
    if (motionEnabled && !_meterClock.isAnimating) {
      _meterClock.repeat();
    } else if (!motionEnabled && _meterClock.isAnimating) {
      _meterClock.stop();
    }
  }

  @override
  void dispose() {
    _meterClock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _meterClock,
      builder: (BuildContext context, Widget? child) {
        final AudioMeterDance dance = AudioMeterDance.sample(_meterClock.value);
        final AudioEndpoint? output = _audio.output;
        final AudioEndpoint? input = _audio.input;
        final AudioMeterLevels levels = AudioMeterLevels(
          output: dance.output * (output?.volume ?? 0) / 100,
          input: dance.input * (input?.volume ?? 0) / 100,
        );

        return AudioPanel(
          borderRadius: HyprRadii.popoverRadius,
          status: AudioFixtures.status(_audio),
          brightnessStatus: AudioFixtures.brightnessStatus(_brightness),
          meterLevels: levels,
          onSetVolume: _setVolume,
          onSetMuted: _setMuted,
          onSetBrightness: _setBrightness,
          onOpenMixer: _noop,
        );
      },
    );
  }

  void _setVolume(AudioEndpointKind kind, int volume) {
    setState(() => _audio = _withEndpoint(_audio, kind, volume: volume));
  }

  void _setMuted(AudioEndpointKind kind, {required bool muted}) {
    setState(() => _audio = _withEndpoint(_audio, kind, muted: muted));
  }

  void _setBrightness(int value) {
    setState(() {
      _brightness = BrightnessStatusAvailable(
        device: _brightness.device,
        value: value,
      );
    });
  }
}

/// A deterministic, smoothly interpolated pair of preview signal envelopes.
@immutable
class AudioMeterDance {
  const AudioMeterDance({required this.output, required this.input});

  final double output;
  final double input;

  static const List<double> _outputPattern = <double>[
    .42,
    .78,
    .56,
    .91,
    .63,
    .84,
    .48,
    .72,
    .58,
    .88,
    .51,
    .69,
    .44,
    .81,
    .61,
    .94,
    .67,
    .76,
    .46,
    .86,
    .54,
    .73,
    .49,
    .64,
  ];

  static const List<double> _inputPattern = <double>[
    .18,
    .41,
    .29,
    .53,
    .22,
    .46,
    .31,
    .57,
    .25,
    .38,
    .17,
    .49,
    .27,
    .44,
    .20,
    .55,
    .33,
    .42,
    .24,
    .51,
    .28,
    .39,
    .19,
    .35,
  ];

  static AudioMeterDance sample(double progress) {
    final double position =
        progress.clamp(0.0, 1.0).toDouble() * _outputPattern.length;
    final int current = position.floor() % _outputPattern.length;
    final int next = (current + 1) % _outputPattern.length;
    final double fraction = position - position.floor();
    final double eased = 1 - math.pow(1 - fraction, 3).toDouble();

    return AudioMeterDance(
      output: _mix(_outputPattern[current], _outputPattern[next], eased),
      input: _mix(_inputPattern[current], _inputPattern[next], eased),
    );
  }

  static double _mix(double from, double to, double amount) =>
      from + (to - from) * amount;
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
