import 'package:flutter/material.dart';

Widget hyprLocalSvg({
  required String path,
  required double width,
  required double height,
  required Widget fallback,
  BoxFit fit = BoxFit.contain,
  ColorFilter? colorFilter,
}) => fallback;

/// Web previews do not have access to the desktop's local icon paths.
Widget hyprLocalImage({
  required String path,
  required double width,
  required double height,
  required Widget fallback,
  BoxFit fit = BoxFit.contain,
  int? cacheWidth,
  int? cacheHeight,
  FilterQuality filterQuality = FilterQuality.medium,
  Color? color,
  BlendMode? colorBlendMode,
  bool gaplessPlayback = false,
}) => fallback;
