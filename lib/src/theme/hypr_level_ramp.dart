import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../widgets/surfaces/hypr_colors.dart';

/// Colour ramp for a level readout: a nominal band, then two escalating bands.
///
/// Meters across the bar share this vocabulary so a given position on a fader,
/// a master meter and the OSD all mean the same thing. Instances differ only in
/// the colours and where the bands start.
@immutable
class HyprLevelRamp {
  const HyprLevelRamp({
    required this.nominal,
    required this.warning,
    required this.peak,
    required this.warningAt,
    required this.peakAt,
  });

  /// Audio level: green through amber into the shared danger red.
  static const HyprLevelRamp audio = HyprLevelRamp(
    nominal: HyprColors.levelNominal,
    warning: HyprColors.levelWarning,
    peak: HyprColors.levelPeak,
    warningAt: 0.72,
    peakAt: 0.88,
  );

  /// Display brightness: cool through warm, escalating into lamp white.
  ///
  /// Brighter is warmer rather than worse, so the bands sit lower than audio's.
  static const HyprLevelRamp brightness = HyprLevelRamp(
    nominal: HyprColors.lampCool,
    warning: HyprColors.lampWarm,
    peak: HyprColors.lampHot,
    warningAt: 0.62,
    peakAt: 0.86,
  );

  final Color nominal;
  final Color warning;
  final Color peak;

  /// Fraction of the scale at which the warning band begins.
  final double warningAt;

  /// Fraction of the scale at which the peak band begins.
  final double peakAt;

  /// The band colour for a position expressed as a fraction of the scale.
  Color colorAt(double position) {
    if (position >= peakAt) {
      return peak;
    }
    if (position >= warningAt) {
      return warning;
    }
    return nominal;
  }

  /// The same ramp with a different nominal band, for per-channel tinting.
  HyprLevelRamp withNominal(Color nominal) => HyprLevelRamp(
    nominal: nominal,
    warning: warning,
    peak: peak,
    warningAt: warningAt,
    peakAt: peakAt,
  );

  @override
  bool operator ==(Object other) =>
      other is HyprLevelRamp &&
      other.nominal == nominal &&
      other.warning == warning &&
      other.peak == peak &&
      other.warningAt == warningAt &&
      other.peakAt == peakAt;

  @override
  int get hashCode => Object.hash(nominal, warning, peak, warningAt, peakAt);
}
