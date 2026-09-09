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
    this.overlayOpacity = 1,
  });

  final BorderRadius borderRadius;
  final BoxConstraints constraints;
  final EdgeInsetsGeometry padding;
  final Widget child;
  final Color color;

  /// Material painted instead of [color], for surfaces that are not flat.
  /// Doubled as a chassis wash over [color] and under [child].
  final Gradient? gradient;

  final Color borderColor;

  /// Multiplier on the dark top-to-bottom wash. `1` is the shared popover
  /// floor; a little under that lets more of the blur through.
  final double overlayOpacity;

  @override
  Widget build(BuildContext context) {
    return HyprPopoverSurface(
      borderRadius: borderRadius,
      color: color,
      gradient: gradient,
      borderColor: borderColor,
      overlayOpacity: overlayOpacity,
      child: _chassis(
        ConstrainedBox(
          constraints: constraints,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }

  Widget _chassis(Widget child) {
    final Gradient? wash = gradient;
    if (wash == null) {
      return child;
    }
    return DecoratedBox(
      decoration: BoxDecoration(gradient: wash),
      child: child,
    );
  }
}
