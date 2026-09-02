import 'package:flutter/material.dart';

import '../hypr_surface.dart';

class HyprPopoverPanel extends StatelessWidget {
  const HyprPopoverPanel({
    super.key,
    required this.borderRadius,
    required this.constraints,
    required this.padding,
    required this.child,
    this.color = HyprColors.popoverSurface,
    this.gradient,
    this.borderColor = HyprColors.popupStroke,
  });

  final BorderRadius borderRadius;
  final BoxConstraints constraints;
  final EdgeInsetsGeometry padding;
  final Widget child;
  final Color color;

  /// Material painted instead of [color], for surfaces that are not flat.
  final Gradient? gradient;

  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return HyprPopoverSurface(
      borderRadius: borderRadius,
      color: color,
      gradient: gradient,
      borderColor: borderColor,
      child: ConstrainedBox(
        constraints: constraints,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
