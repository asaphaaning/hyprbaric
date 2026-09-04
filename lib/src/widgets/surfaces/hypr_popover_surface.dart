import 'package:flutter/material.dart';

import 'hypr_colors.dart';
import 'hypr_glass_surface.dart';
import 'hypr_surface_frame.dart';

class HyprPopoverSurface extends StatelessWidget {
  /// A shared translucent chassis for panels that float above the bar.
  ///
  /// The neutral top-to-bottom tint keeps every popover grounded in the same
  /// material while allowing their internal controls to retain their own
  /// visual hierarchy.
  const HyprPopoverSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.color = HyprColors.popoverSurface,
    this.gradient,
    this.borderColor = HyprColors.popupStroke,
    this.blur = 16,
    this.shadow = false,
    this.inset = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Color color;
  final Gradient? gradient;
  final Color borderColor;
  final double blur;
  final bool shadow;
  final bool inset;

  @override
  Widget build(BuildContext context) {
    return HyprGlassSurface(
      borderRadius: borderRadius,
      color: color,
      gradient: gradient,
      borderColor: borderColor,
      blur: blur,
      shadow: shadow,
      inset: inset,
      frame: HyprSurfaceFrame.popover,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[HyprColors.popoverTop, HyprColors.popoverBottom],
          ),
        ),
        child: child,
      ),
    );
  }
}
