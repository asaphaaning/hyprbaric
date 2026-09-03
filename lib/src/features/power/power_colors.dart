import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';

/// Charge-state colours shared by the battery chip, meter and profile pads.
///
/// These three tones were repeated literally across four power widgets. Keeping
/// them here means a change to the charge ramp lands everywhere at once.
abstract final class PowerColors {
  /// Charge at or below the critical threshold.
  static const Color critical = Color(0xFFE05F55);

  /// Charge between the critical and healthy thresholds.
  static const Color low = Color(0xFFE7C34A);

  /// Charge above the low threshold.
  static const Color healthy = Color(0xFF55D982);

  /// An unlit meter segment.
  static const Color unlit = Color(0xFF202A33);

  /// Highlight along the top edge of a lit meter segment.
  static const Color segmentHighlight = HyprColors.hoverStrong;

  /// Highlight along the top edge of an unlit meter segment.
  static const Color segmentHighlightDim = HyprColors.popupInset;

  static const double criticalThreshold = 30;
  static const double lowThreshold = 60;

  /// The charge tone for a percentage on the 0..100 ramp.
  static Color forCharge(double percentage) {
    if (percentage < criticalThreshold) {
      return critical;
    }
    if (percentage < lowThreshold) {
      return low;
    }
    return healthy;
  }
}
