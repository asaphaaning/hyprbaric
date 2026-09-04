import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';

extension AudioStatusView on AudioStatus {
  bool get isAvailable => this is AudioStatusAvailable;

  AudioEndpoint? get output => switch (this) {
    AudioStatusAvailable(:final output) => output,
    AudioStatusUnavailable() => null,
    _ => null,
  };

  AudioEndpoint? get input => switch (this) {
    AudioStatusAvailable(:final input) => input,
    AudioStatusUnavailable() => null,
    _ => null,
  };

  String? get message => switch (this) {
    AudioStatusAvailable() => null,
    AudioStatusUnavailable(:final message) => message,
    _ => null,
  };
}

/// Materials specific to the mixer console.
///
/// Only surfaces the console invents live here. Text, level bands and recessed
/// housings come from [HyprColors] so the mixer reads as the same instrument as
/// the rest of the bar.
abstract final class AudioMixerColors {
  static const Color deckTop = Color(0xFF242527);
  static const Color deckMiddle = Color(0xFF202123);
  static const Color deckBottom = Color(0xFF1C1D1F);
  static const Color console = Color(0xF5090A0C);
  static const Color rail = Color(0xFF0C0E11);
  static const Color railBorder = Color(0x1CFFFFFF);
  static const Color handle = Color(0xFF34363B);
  static const Color handleBorder = Color(0xFF16181C);
  static const Color accentBorder = HyprColors.accentSoft;

  /// Output channel identity. Doubles as the nominal band of its meter.
  static const Color output = HyprColors.levelNominal;

  /// Input channel identity, kept in the accent family so a glance separates
  /// the two channels.
  static const Color input = Color(0xFF00B8C9);
}

/// Decibels for a PipeWire or PulseAudio volume percentage.
///
/// Both express volume on a cubic curve, so a percentage `p` carries a linear
/// amplitude of `(p / 100)^3` and therefore `60 * log10(p / 100)` decibels.
/// 50% is −18.1 dB, the same figure `pavucontrol` reports for that slider
/// position.
double audioDecibels(int volume) =>
    60 * math.log(volume.clamp(1, 100) / 100) / math.ln10;

String audioDecibelReadout(int volume, {required bool muted}) {
  if (muted || volume <= 0) {
    return '−∞';
  }

  final double decibels = audioDecibels(volume);
  final String text = decibels <= -100
      ? decibels.toStringAsFixed(0)
      : decibels.toStringAsFixed(1);
  return text.replaceFirst('-', '−');
}

class AudioMessage extends StatelessWidget {
  const AudioMessage({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: HyprTypography.popRow.copyWith(color: HyprColors.textFaint),
    );
  }
}
