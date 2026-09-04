import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';

/// The catalog's default look, matching a bar on its stock accent.
final ThemeData catalogTheme = catalogThemeFor(HyprPalette.fallback);

/// Accent-derived palettes the bar actually ships under.
///
/// [HyprPalette.fromAppearance] recomputes every accent, fill and border from
/// the configured hue and opacity, so a component that only ever renders
/// against [HyprPalette.fallback] has never been checked against the palettes
/// most users see.
abstract final class CatalogPalettes {
  static const AppearanceStatus _cyan = AppearanceStatus(
    position: AppearancePosition.top,
    monitor: AppearanceMonitorTargetPrimary(),
    opacity: 90,
    cornerRadius: 12,
    accentHue: 197,
  );

  static const AppearanceStatus _magenta = AppearanceStatus(
    position: AppearancePosition.top,
    monitor: AppearanceMonitorTargetPrimary(),
    opacity: 46,
    cornerRadius: 18,
    accentHue: 310,
  );

  static const AppearanceStatus _amber = AppearanceStatus(
    position: AppearancePosition.top,
    monitor: AppearanceMonitorTargetPrimary(),
    opacity: 77,
    cornerRadius: 12,
    accentHue: 40,
  );

  /// Named palettes offered by the catalog's theme addon.
  static final Map<String, HyprPalette> all = <String, HyprPalette>{
    'Stock': HyprPalette.fallback,
    'Cyan, opaque': HyprPalette.fromAppearance(_cyan),
    'Magenta, translucent': HyprPalette.fromAppearance(_magenta),
    'Amber': HyprPalette.fromAppearance(_amber),
  };
}

/// Builds the catalog theme for one palette.
///
/// Everything except the palette comes from the app's own tokens, so the
/// catalog cannot drift from production typography or colour.
ThemeData catalogThemeFor(HyprPalette palette) {
  final ThemeData base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFF05090E),
    textTheme: HyprTypography.textTheme(base.textTheme),
    primaryTextTheme: HyprTypography.textTheme(base.primaryTextTheme),
    extensions: <ThemeExtension<dynamic>>[palette],
  );
}
