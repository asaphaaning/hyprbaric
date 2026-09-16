import 'package:flutter/material.dart';

import '../hypr_surface.dart';

ButtonStyle hyprCompactIconButtonStyle({
  bool active = false,
  bool danger = false,
  Size size = HyprIconSizes.barButton,
  double radius = HyprRadii.panel,
  Color foregroundColor = HyprColors.textMuted,
  Color hoverForegroundColor = HyprColors.text,
  Color backgroundColor = Colors.transparent,
  Color hoverBackgroundColor = HyprColors.hover,
  Color activeBackgroundColor = HyprColors.hoverStrong,
  Color activeBorderColor = HyprColors.border,
  double activeBorderWidth = 1.2,
}) {
  final Color idleForeground = danger
      ? const Color(0xFFFF7B70)
      : foregroundColor;
  final Color resolvedHoverForeground = danger
      ? const Color(0xFFFF8D82)
      : hoverForegroundColor;
  final Color resolvedBackground = danger
      ? const Color(0x1EE16658)
      : backgroundColor;
  final Color resolvedHoverBackground = danger
      ? const Color(0x33E16658)
      : hoverBackgroundColor;
  final Color resolvedActiveBackground = danger
      ? const Color(0x29E16658)
      : activeBackgroundColor;
  final Color resolvedActiveBorder = danger
      ? const Color(0x99E16658)
      : activeBorderColor;

  return ButtonStyle(
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    splashFactory: NoSplash.splashFactory,
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(HyprSpacing.none),
    minimumSize: WidgetStatePropertyAll<Size>(size),
    fixedSize: WidgetStatePropertyAll<Size>(size),
    shape: WidgetStatePropertyAll<OutlinedBorder>(
      RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(radius)),
    ),
    foregroundColor: WidgetStateProperty.resolveWith<Color>((
      Set<WidgetState> states,
    ) {
      if (active ||
          states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.focused)) {
        return resolvedHoverForeground;
      }
      return idleForeground;
    }),
    side: WidgetStatePropertyAll<BorderSide>(
      active
          ? BorderSide(color: resolvedActiveBorder, width: activeBorderWidth)
          : BorderSide.none,
    ),
    backgroundColor: WidgetStateProperty.resolveWith<Color?>((
      Set<WidgetState> states,
    ) {
      if (active) {
        return resolvedActiveBackground;
      }
      if (states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return resolvedHoverBackground;
      }
      return resolvedBackground;
    }),
    overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
  );
}
