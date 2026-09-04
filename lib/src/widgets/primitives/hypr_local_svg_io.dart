import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

Widget hyprLocalSvg({
  required String path,
  required double width,
  required double height,
  required Widget fallback,
  BoxFit fit = BoxFit.contain,
  ColorFilter? colorFilter,
}) {
  return SvgPicture.file(
    File(path),
    width: width,
    height: height,
    fit: fit,
    colorFilter: colorFilter,
    placeholderBuilder: (_) => fallback,
    errorBuilder: (_, _, _) => fallback,
  );
}

/// Renders a local bitmap on native platforms.
///
/// Desktop icon paths are discovered from the host and may disappear between
/// snapshots. [`Image.file`] keeps that failure in its image pipeline, where
/// the supplied [fallback] can handle it without interrupting the build.
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
}) {
  return Image.file(
    File(path),
    width: width,
    height: height,
    fit: fit,
    cacheWidth: cacheWidth,
    cacheHeight: cacheHeight,
    filterQuality: filterQuality,
    color: color,
    colorBlendMode: colorBlendMode,
    gaplessPlayback: gaplessPlayback,
    errorBuilder: (_, _, _) => fallback,
  );
}
