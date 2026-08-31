import 'package:flutter/foundation.dart';

/// Normalized signal levels rendered by the mixer meters.
///
/// These values describe transient audio activity independently of the
/// endpoint volume represented by the fader position.
@immutable
class AudioMeterLevels {
  const AudioMeterLevels({required this.output, required this.input})
    : assert(output >= 0 && output <= 1, 'output must be normalized'),
      assert(input >= 0 && input <= 1, 'input must be normalized');

  const AudioMeterLevels.silent() : output = 0, input = 0;

  /// Current output signal, normalized from silence to peak.
  final double output;

  /// Current input signal, normalized from silence to peak.
  final double input;

  @override
  bool operator ==(Object other) =>
      other is AudioMeterLevels &&
      output == other.output &&
      input == other.input;

  @override
  int get hashCode => Object.hash(output, input);
}
