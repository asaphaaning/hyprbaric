import 'package:flutter/widgets.dart';

/// Shared radius vocabulary for Hyprbaric's superellipse-heavy surfaces.
///
/// Keep shape choices here when the value represents visual language rather
/// than a measurement intrinsic to a specific custom painter.
abstract final class HyprRadii {
  static const double none = 0;
  static const double hairline = 1;
  static const double stripe = 2;
  static const double tag = 3;
  static const double badge = 4;
  static const double card = 5;
  static const double control = 6;
  static const double compact = 7;
  static const double row = 8;
  static const double panel = 9;
  static const double field = 10;
  static const double bar = 12;
  static const double tile = 14;
  static const double chassis = 16;
  static const double clockCard = 17;
  static const double popover = 18;
  static const double launcher = 20;
  static const double pill = 999;

  static const BorderRadius zero = BorderRadius.zero;
  static const BorderRadius badgeRadius = BorderRadius.all(
    Radius.circular(badge),
  );
  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius tagRadius = BorderRadius.all(Radius.circular(tag));
  static const BorderRadius controlRadius = BorderRadius.all(
    Radius.circular(control),
  );
  static const BorderRadius compactRadius = BorderRadius.all(
    Radius.circular(compact),
  );
  static const BorderRadius rowRadius = BorderRadius.all(Radius.circular(row));
  static const BorderRadius chassisRadius = BorderRadius.all(
    Radius.circular(chassis),
  );
  static const BorderRadius panelRadius = BorderRadius.all(
    Radius.circular(panel),
  );
  static const BorderRadius fieldRadius = BorderRadius.all(
    Radius.circular(field),
  );
  static const BorderRadius clockCardRadius = BorderRadius.all(
    Radius.circular(clockCard),
  );
  static const BorderRadius popoverRadius = BorderRadius.all(
    Radius.circular(popover),
  );
  static const BorderRadius launcherRadius = BorderRadius.all(
    Radius.circular(launcher),
  );
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(pill),
  );
}
