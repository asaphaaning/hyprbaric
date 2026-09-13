import 'package:flutter/material.dart';

import '../widgets/primitives/hypr_instrument_slider.dart';

/// Applies shared slider thumbs and removes Material ink and pressed halos.
///
/// Applied by both the bar and catalog; instrument controls own their custom
/// face, glow, and displacement feedback independently of Material.
ThemeData instrumentControlsTheme(ThemeData theme) {
  final pressedOverlay = WidgetStateProperty.resolveWith<Color?>(
    (states) =>
        states.contains(WidgetState.pressed) ? Colors.transparent : null,
  );
  final buttons = ButtonStyle(
    splashFactory: NoSplash.splashFactory,
    overlayColor: pressedOverlay,
  );

  return theme.copyWith(
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    sliderTheme: theme.sliderTheme.copyWith(
      thumbShape: const HyprInstrumentSliderThumb(),
      overlayShape: SliderComponentShape.noOverlay,
      overlayColor: Colors.transparent,
    ),
    textButtonTheme: TextButtonThemeData(
      style: (theme.textButtonTheme.style ?? const ButtonStyle()).merge(
        buttons,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: (theme.outlinedButtonTheme.style ?? const ButtonStyle()).merge(
        buttons,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: (theme.elevatedButtonTheme.style ?? const ButtonStyle()).merge(
        buttons,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: (theme.filledButtonTheme.style ?? const ButtonStyle()).merge(
        buttons,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: (theme.iconButtonTheme.style ?? const ButtonStyle()).merge(
        buttons,
      ),
    ),
    checkboxTheme: theme.checkboxTheme.copyWith(overlayColor: pressedOverlay),
    radioTheme: theme.radioTheme.copyWith(overlayColor: pressedOverlay),
    switchTheme: theme.switchTheme.copyWith(overlayColor: pressedOverlay),
    tabBarTheme: theme.tabBarTheme.copyWith(
      splashFactory: NoSplash.splashFactory,
      overlayColor: pressedOverlay,
    ),
    floatingActionButtonTheme: theme.floatingActionButtonTheme.copyWith(
      splashColor: Colors.transparent,
    ),
  );
}
