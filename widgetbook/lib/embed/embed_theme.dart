import 'package:flutter/material.dart';
import 'package:hyprbaric/audio_embed.dart';

/// Theme shared by the standalone, embedded mixer views.
final ThemeData embedTheme = _embedTheme();

ThemeData _embedTheme() {
  final ThemeData base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: HyprTypography.textTheme(base.textTheme),
    primaryTextTheme: HyprTypography.textTheme(base.primaryTextTheme),
    extensions: const <ThemeExtension<dynamic>>[HyprPalette.fallback],
  );
}
