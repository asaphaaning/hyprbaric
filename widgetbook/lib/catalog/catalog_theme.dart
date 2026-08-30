import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';

final ThemeData catalogTheme = _catalogTheme();

ThemeData _catalogTheme() {
  final ThemeData base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFF05090E),
    textTheme: HyprTypography.textTheme(base.textTheme),
    primaryTextTheme: HyprTypography.textTheme(base.primaryTextTheme),
    extensions: const <ThemeExtension<dynamic>>[HyprPalette.fallback],
  );
}
