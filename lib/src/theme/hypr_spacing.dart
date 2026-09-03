import 'package:flutter/widgets.dart';

/// Shared spacing vocabulary for Hyprbaric UI chrome.
///
/// Prefer these named values in shared widgets and new components so padding
/// and gaps stay visually related instead of becoming unrelated raw numbers.
abstract final class HyprSpacing {
  static const double hairline = 1;
  static const double xxs = 2;
  static const double xs = 3;
  static const double sm = 4;
  static const double md = 5;
  static const double lg = 6;
  static const double xl = 8;
  static const double xxl = 10;
  static const double section = 12;
  static const double panel = 14;
  static const double roomy = 16;
  static const double spacious = 18;
  static const double expanded = 20;
  static const double loose = 24;
  static const double emptyStateBlock = 32;

  static const EdgeInsets none = EdgeInsets.zero;
  static const EdgeInsets hairlineInset = EdgeInsets.all(hairline);
  static const EdgeInsets panelAll = EdgeInsets.all(panel);

  static const EdgeInsets badge = EdgeInsets.symmetric(
    horizontal: xl - hairline,
    vertical: xs,
  );
  static const EdgeInsets inlineTag = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: xxs,
  );
  static const EdgeInsets actionRow = EdgeInsets.symmetric(
    horizontal: xxl,
    vertical: xl,
  );
  static const EdgeInsets commandButton = EdgeInsets.symmetric(
    horizontal: xxl,
    vertical: panel - md,
  );
  static const EdgeInsets well = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: xs,
  );
  static const EdgeInsets textField = EdgeInsets.symmetric(
    horizontal: section,
    vertical: xxs,
  );
  static const EdgeInsets metricCard = EdgeInsets.symmetric(
    horizontal: panel - md,
    vertical: md,
  );
  static const EdgeInsets emptyState = EdgeInsets.symmetric(
    horizontal: expanded,
    vertical: emptyStateBlock,
  );
}
