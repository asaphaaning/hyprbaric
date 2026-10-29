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
  static const Duration handoff = HyprDurations.handoff;
  static const Duration plate = HyprDurations.plate;
  static const Duration flip = HyprDurations.flip;

  /// A dismissed row sliding away and closing its gap.
  static const Duration leave = Duration(milliseconds: 460);

  /// Delay between rows leaving together, as in clearing a list.
  static const Duration leaveStagger = Duration(milliseconds: 55);

  /// A switch's knob springing to its new side.
  static const Duration knob = Duration(milliseconds: 380);
  static const Curve knobCurve = Cubic(0.34, 1.45, 0.64, 1);

  /// A power profile's consumption bars rising as it is selected.
  static const Duration profileBars = Duration(milliseconds: 820);
  static const Duration entrance = HyprDurations.entrance;

  /// When each bar cluster follows the bar surface into place.
  static const Duration entranceLeft = Duration(milliseconds: 90);
  static const Duration entranceCenter = Duration(milliseconds: 180);
  static const Duration entranceRight = Duration(milliseconds: 270);
  static const Duration roll = HyprDurations.roll;
  static const Duration plateHover = HyprDurations.plateHover;

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

  /// The shared shell gliding between two popovers' frames and anchors.
  static const Curve handoffShellCurve = Cubic(0.32, 0.72, 0, 1);

  /// Sections of the arriving popover settling into place.
  static const Curve handoffEnterCurve = Cubic(0.22, 1.00, 0.36, 1.00);

  /// Sections of the departing popover sliding out of the shell.
  static const Curve handoffExitCurve = Curves.easeInCubic;

  /// Departing sections fade quickly, so they never compete with arrivals.
  static const Curve handoffExitFadeCurve = Curves.easeOutQuad;

  /// Fraction of the handoff by which every departing section has left.
  static const double handoffExitSpan = 0.26;

  /// Delay between consecutive departing sections, as a handoff fraction.
  static const double handoffExitStagger = 0.03;

  /// When the first arriving section starts, as a handoff fraction.
  static const double handoffEnterStart = 0.17;

  /// How long each arriving section takes, as a handoff fraction.
  static const double handoffEnterSpan = 0.5;

  /// Delay between consecutive arriving sections, as a handoff fraction.
  static const double handoffEnterStagger = 0.05;

  /// Sideways travel of a section, in the direction the anchor moved.
  static const double handoffTravel = 22;

  /// Vertical drift of an arriving section.
  static const double handoffRise = 10;

  /// A plate gliding between controls.
  static const Curve plateCurve = Cubic(0.32, 0.72, 0, 1);

  /// The plate's leading edge, reaching its destination first.
  static const Curve plateLeadCurve = Interval(0, 0.66, curve: plateCurve);

  /// The plate's trailing edge, catching up as it lands.
  static const Curve plateTrailCurve = Interval(0.14, 1, curve: plateCurve);

  /// How far flipping content travels vertically.
  static const double flipDistance = 11;

  /// Fraction of a flip by which the outgoing face has left.
  static const double flipOutSpan = 0.45;
  static const Curve flipOutCurve = Curves.easeInCubic;

  /// Fraction of a flip before the incoming face starts to rise.
  static const double flipInDelay = 0.12;
  static const Curve flipInCurve = Cubic(0.22, 1.00, 0.36, 1.00);

  /// Settling into place with a slight overshoot.
  static const Curve entranceCurve = Cubic(0.34, 1.3, 0.64, 1);
}
