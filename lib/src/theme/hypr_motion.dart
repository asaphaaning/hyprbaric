import 'package:flutter/animation.dart';

import 'hypr_durations.dart';

/// Shared motion vocabulary for Hyprbaric's bar, popups, and transient UI.
///
/// Keep raw durations and curves here unless a value is truly local to a
/// one-off effect. Widgets should read as design intent: hover, popup, dismiss,
/// or switch, rather than as unrelated millisecond values.
abstract final class HyprMotion {
  static const Duration scrub = HyprDurations.scrub;
  static const Duration hover = HyprDurations.hover;
  static const Duration selection = HyprDurations.selection;
  static const Duration workspace = HyprDurations.workspace;
  static const Duration switcher = HyprDurations.switcher;
  static const Duration popup = HyprDurations.popup;
  static const Duration toast = HyprDurations.toast;
  static const Duration growPopup = HyprDurations.growPopup;

  static const double growPopupHiddenScale = 0.70;
  static const double growPopupHiddenOffsetY = -12;
  static const double growPopupHiddenBlur = 0;

  static const Curve scrubCurve = Curves.easeOutCubic;
  static const Curve hoverCurve = Curves.easeOutCubic;
  static const Curve selectionCurve = Curves.easeOutCubic;
  static const Curve workspaceCurve = Curves.easeOutCubic;
  static const Curve switchInCurve = Curves.easeOutCubic;
  static const Curve switchOutCurve = Curves.easeInCubic;
  static const Curve popupCurve = Curves.easeOutCubic;
  static const Curve popupReverseCurve = Curves.easeInCubic;
  static const Curve toastCurve = Curves.easeOutCubic;
  static const Curve growPopupTransformCurve = Cubic(0.22, 1.00, 0.36, 1.00);
  static const Curve growPopupOpacityCurve = Interval(
    0,
    0.45,
    curve: Curves.easeOutCubic,
  );
  static const Curve growPopupBlurCurve = Interval(
    0,
    0.45,
    curve: Curves.easeOutCubic,
  );
}
