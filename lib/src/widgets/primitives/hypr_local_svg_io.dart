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
