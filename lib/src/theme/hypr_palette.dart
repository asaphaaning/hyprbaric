import 'package:flutter/material.dart';

import '../bindings/bindings.dart';
import '../widgets/surfaces/hypr_colors.dart';

@immutable
class HyprPalette extends ThemeExtension<HyprPalette> {
  const HyprPalette({
    required this.surfaceStrong,
    required this.accent,
    required this.accentSoft,
    required this.fill,
    required this.fillStrong,
    required this.borderSoft,
  });

  factory HyprPalette.fromAppearance(AppearanceStatus appearance) {
    final double hue = appearance.accentHue.toDouble();
    final Color accent = appearance.accentHue == HyprColors.accentHue
        ? HyprColors.accent
        : HSLColor.fromAHSL(1, hue, 0.91, 0.52).toColor();
    final Color accentSoft = appearance.accentHue == HyprColors.accentHue
        ? HyprColors.accentSoft
        : HSLColor.fromAHSL(1, hue, 1, 0.67).toColor();
    final double surfaceAlpha = appearance.opacity.clamp(20, 100) / 100;

    return HyprPalette(
      surfaceStrong: HyprColors.surfaceStrong.withValues(alpha: surfaceAlpha),
      accent: accent,
      accentSoft: accentSoft,
      fill: accent.withValues(alpha: 0.063),
      fillStrong: accent.withValues(alpha: 0.16),
      borderSoft: accentSoft.withValues(alpha: 0.20),
    );
  }

  static const HyprPalette fallback = HyprPalette(
    surfaceStrong: HyprColors.surfaceStrong,
    accent: HyprColors.accent,
    accentSoft: HyprColors.accentSoft,
    fill: HyprColors.fill,
    fillStrong: HyprColors.fillStrong,
    borderSoft: HyprColors.borderSoft,
  );

  final Color surfaceStrong;
  final Color accent;
  final Color accentSoft;
  final Color fill;
  final Color fillStrong;
  final Color borderSoft;

  @override
  HyprPalette copyWith({
    Color? surfaceStrong,
    Color? accent,
    Color? accentSoft,
    Color? fill,
    Color? fillStrong,
    Color? borderSoft,
  }) {
    return HyprPalette(
      surfaceStrong: surfaceStrong ?? this.surfaceStrong,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      fill: fill ?? this.fill,
      fillStrong: fillStrong ?? this.fillStrong,
      borderSoft: borderSoft ?? this.borderSoft,
    );
  }

  @override
  HyprPalette lerp(ThemeExtension<HyprPalette>? other, double t) {
    if (other is! HyprPalette) {
      return this;
    }

    return HyprPalette(
      surfaceStrong: Color.lerp(surfaceStrong, other.surfaceStrong, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      fill: Color.lerp(fill, other.fill, t)!,
      fillStrong: Color.lerp(fillStrong, other.fillStrong, t)!,
      borderSoft: Color.lerp(borderSoft, other.borderSoft, t)!,
    );
  }
}

extension HyprPaletteLookup on BuildContext {
  HyprPalette get hyprPalette {
    return Theme.of(this).extension<HyprPalette>() ?? HyprPalette.fallback;
  }
}
