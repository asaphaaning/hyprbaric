import 'package:flutter/material.dart';

import '../hypr_surface.dart';

/// A recessed housing for a readout or a status chip.
///
/// Wells read as milled into the surface rather than sitting on it, so they
/// keep a circular radius and an inner shadow where raised controls use the
/// system's superellipse. One spec, so every readout recesses identically.
class HyprWell extends StatelessWidget {
  const HyprWell({
    super.key,
    required this.child,
    this.padding = HyprSpacing.well,
    this.borderRadius = HyprRadii.controlRadius,
    this.color = HyprColors.well,
    this.borderColor = HyprColors.wellBorder,
    this.shadowColor = HyprColors.wellShadow,
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color color;

  /// Rim of the recess. Omitted when transparent.
  final Color borderColor;

  final Color shadowColor;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      alignment: height == null ? null : Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: borderColor == Colors.transparent
            ? null
            : Border.all(color: borderColor),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: shadowColor,
            blurRadius: HyprSpacing.xs,
            offset: const Offset(0, 1),
            blurStyle: BlurStyle.inner,
          ),
        ],
      ),
      child: child,
    );
  }
}
