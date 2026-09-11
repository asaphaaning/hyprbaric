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
  static const Color text = Color(0xFFF7F6FF);
  static const Color secondary = Color(0xFFB8C4FF);
  static const Color border = Color(0xFF7B86B0);
  static const Color divider = Color(0x333A3E49);

  /// A cool charcoal wash that distinguishes the deck without hiding the blur.
  static const Color deckTop = Color(0x1C43464F);
  static const Color deckMiddle = Color(0x24444854);
  static const Color deckBottom = Color(0x1C393E49);
  static const Color deckBorder = Color(0x30373D49);
  static const Color console = Color(0x44101730);
  static const Color rail = Color(0xFF080914);
  static const Color railBorder = Color(0x333D3D54);
  static const Color handle = Color(0xFF34364F);
  static const Color handleBorder = Color(0xFF080A14);
  static const Color accentBorder = Color(0xFFB8C4FF);
  static const Color amber = Color(0xFFFFD24D);

  /// Output channel identity, shared by its fader and meter.
  static const Color output = Color(0xFFC153FA);

  /// Microphone channel identity.
  static const Color input = Color(0xFFF55DF3);

  /// Translucent charcoal with a restrained blue undertone over desktop blur.
  static const LinearGradient glass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xC914171E), Color(0xBC101218), Color(0xD00B0E13)],
    stops: <double>[0, 0.55, 1],
  );
}

/// Typography shared by the display and audio instruments.
abstract final class AudioMixerText {
  /// Compact uppercase instrument headings.
  static const TextStyle label = TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.1,
    color: AudioMixerColors.text,
    height: 1.25,
  );

  /// Device names, units, and scale legends.
  static const TextStyle meta = TextStyle(
    fontFamily: 'Roboto Condensed',
    fontSize: 10.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
    color: AudioMixerColors.secondary,
    height: 1.3,
  );

  /// Numeric values with the reference's condensed proportions.
  static const TextStyle value = TextStyle(
    fontFamily: 'Roboto Condensed',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: AudioMixerColors.text,
    height: 1.3,
  );
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
