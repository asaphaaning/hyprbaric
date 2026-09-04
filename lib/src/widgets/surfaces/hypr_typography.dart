import 'package:flutter/material.dart';

import 'hypr_colors.dart';
import 'hypr_console_colors.dart';

abstract final class HyprTypography {
  static const String uiFamily = 'Inter';
  static const String monoFamily = 'JetBrains Mono';
  static const List<FontFeature> tabularNumbers = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static TextTheme textTheme(TextTheme base) => base.apply(
    fontFamily: uiFamily,
    bodyColor: HyprColors.text,
    displayColor: HyprColors.text,
  );

  /// Returns a logical font size.
  ///
  /// Flutter projects logical sizes through each owning [FlutterView], so
  /// applying another view's device-pixel ratio here would make multi-monitor
  /// typography inconsistent.
  static double size(double reference) => reference;

  static double sizeForScale(double reference, double scale) {
    if (!scale.isFinite || scale <= 0) {
      return reference;
    }
    final double snapped = (reference * scale).roundToDouble() / scale;
    return double.parse(snapped.toStringAsFixed(3));
  }

  static TextStyle get bar => TextStyle(
    fontFamily: uiFamily,
    color: HyprColors.textMuted,
    fontSize: size(12.5),
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  static TextStyle get barStrong => TextStyle(
    fontFamily: uiFamily,
    color: HyprColors.text,
    fontSize: size(12.5),
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static TextStyle get barMono => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: <String>['monospace'],
    color: HyprColors.textMuted,
    fontSize: size(11.5),
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    fontFeatures: tabularNumbers,
  );

  static TextStyle get workspace => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: <String>['monospace'],
    color: HyprColors.textFaint,
    fontSize: size(10.5),
    fontWeight: FontWeight.w600,
    height: 1,
    letterSpacing: 0,
    fontFeatures: tabularNumbers,
  );

  static TextStyle get appBadge => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: <String>['monospace'],
    color: Colors.white,
    fontSize: size(9),
    fontWeight: FontWeight.w700,
    height: 1,
    letterSpacing: 0,
  );

  static TextStyle get clockTime => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: <String>['monospace'],
    color: HyprColors.text,
    fontSize: size(13),
    fontWeight: FontWeight.w600,
    height: 1,
    letterSpacing: 0.13,
    fontFeatures: tabularNumbers,
  );

  static TextStyle get clockDate => TextStyle(
    fontFamily: uiFamily,
    color: const Color(0xB8AAB4BD),
    fontSize: size(12),
    fontWeight: FontWeight.w500,
    height: 1,
    letterSpacing: 0,
  );

  static TextStyle get popTitle => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: <String>['monospace'],
    color: HyprColors.textFaint,
    fontSize: size(10.5),
    fontWeight: FontWeight.w600,
    letterSpacing: 0.96,
  );

  static TextStyle get popRow => TextStyle(
    fontFamily: uiFamily,
    color: HyprColors.textMuted,
    fontSize: size(12.5),
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  static TextStyle get popRowStrong => TextStyle(
    fontFamily: uiFamily,
    color: HyprColors.text,
    fontSize: size(12.5),
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  static TextStyle get popMeta => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: <String>['monospace'],
    color: HyprColors.textFaint,
    fontSize: size(11),
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static TextStyle get metricLabel => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: <String>['monospace'],
    color: HyprColors.textFaint,
    fontSize: size(9.5),
    fontWeight: FontWeight.w500,
    letterSpacing: 0.76,
  );

  static TextStyle get metricValue => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: <String>['monospace'],
    color: HyprColors.text,
    fontSize: size(14),
    fontWeight: FontWeight.w600,
    letterSpacing: -0.14,
    fontFeatures: tabularNumbers,
  );

  static TextStyle get metricUnit => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: <String>['monospace'],
    color: HyprColors.textMuted,
    fontSize: size(10),
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static TextStyle get metricSub => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: <String>['monospace'],
    color: HyprColors.textFaint,
    fontSize: size(9.5),
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static TextStyle get compactMono => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: <String>['monospace'],
    color: HyprColors.textMuted,
    fontSize: size(10.5),
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  static TextStyle get compactMonoStrong => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: <String>['monospace'],
    color: HyprColors.text,
    fontSize: size(11.5),
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    fontFeatures: tabularNumbers,
  );

  // Mixer console. Four roles replace the ad hoc size and tracking pairs the
  // console used to spell out at every call site.

  /// Widest-tracked chrome legend: MIXER, DISPLAY.
  static TextStyle get mixerLegend => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: <String>['monospace'],
    color: HyprColors.textFaint,
    fontSize: size(10),
    fontWeight: FontWeight.w600,
    letterSpacing: 2.2,
    fontFeatures: tabularNumbers,
  );

  /// Channel and section labels: OUT, MIC, MASTER, BRIGHTNESS.
  static TextStyle get mixerLabel => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: <String>['monospace'],
    color: HyprColors.textFaint,
    fontSize: size(9),
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
    fontFeatures: tabularNumbers,
  );

  /// Numeric readouts inside a well.
  static TextStyle get mixerValue => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: <String>['monospace'],
    color: HyprColors.text,
    fontSize: size(10.5),
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    fontFeatures: tabularNumbers,
  );

  /// Device names and other supporting console text.
  static TextStyle get mixerMeta => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: <String>['monospace'],
    color: HyprColors.textMuted,
    fontSize: size(9),
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
    fontFeatures: tabularNumbers,
  );

  // Console chassis. Roles for the engraved chrome shared by the quick
  // controls console and anything else mounted in the same shell.

  /// Engraved tray heading inside a console chassis.
  static TextStyle get consoleSection => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: <String>['monospace'],
    color: HyprConsoleColors.label,
    fontSize: size(10.5),
    fontWeight: FontWeight.w600,
    height: 1,
    letterSpacing: 1.05,
    shadows: const <Shadow>[
      Shadow(color: Color(0xBF000000), offset: Offset(0, 1), blurRadius: 2),
    ],
  );

  /// Silkscreened caption under a console control.
  static TextStyle get consoleCaption => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: <String>['monospace'],
    color: HyprConsoleColors.textMuted,
    fontSize: size(10),
    fontWeight: FontWeight.w700,
    height: 1,
    letterSpacing: 1.45,
  );

  /// [consoleCaption] for the narrow faces of a capture pad or rocker.
  static TextStyle get consoleCaptionTight => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: <String>['monospace'],
    color: HyprConsoleColors.textFaint,
    fontSize: size(9),
    fontWeight: FontWeight.w700,
    height: 1,
    letterSpacing: 1.5,
  );

  /// Chord hint stamped onto a console face.
  static TextStyle get consoleShortcut => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: <String>['monospace'],
    color: HyprConsoleColors.textFaint,
    fontSize: size(8),
    fontWeight: FontWeight.w600,
    height: 1,
    letterSpacing: 0.3,
  );

  /// Numeric readout behind a console well.
  static TextStyle get consoleReadout => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: <String>['monospace'],
    color: HyprConsoleColors.textMuted,
    fontSize: size(16),
    fontWeight: FontWeight.w600,
    height: 1,
    letterSpacing: 0.65,
    fontFeatures: tabularNumbers,
  );

  static TextStyle get notificationText => TextStyle(
    fontFamily: uiFamily,
    color: HyprColors.textMuted,
    fontSize: size(12),
    fontWeight: FontWeight.w500,
    height: 1.45,
    letterSpacing: 0,
  );

  static TextStyle get settingHeading => TextStyle(
    fontFamily: uiFamily,
    color: HyprColors.text,
    fontSize: size(16),
    fontWeight: FontWeight.w600,
    letterSpacing: -0.16,
  );

  static TextStyle get osdValue => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: <String>['monospace'],
    color: HyprColors.text,
    fontSize: size(18),
    fontWeight: FontWeight.w600,
    letterSpacing: -0.18,
    fontFeatures: tabularNumbers,
  );

  static TextStyle mono(TextStyle? base, {bool tabularFigures = false}) {
    final TextStyle style = (base ?? const TextStyle()).copyWith(
      fontFamily: monoFamily,
      fontFamilyFallback: const <String>['monospace'],
    );
    return style.copyWith(
      fontFeatures: tabularFigures
          ? <FontFeature>[
              ...?style.fontFeatures,
              const FontFeature.tabularFigures(),
            ]
          : style.fontFeatures,
    );
  }
}
