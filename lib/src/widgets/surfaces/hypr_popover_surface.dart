import 'package:flutter/material.dart';

import 'hypr_colors.dart';
import 'hypr_glass_surface.dart';
import 'hypr_instrument_surface.dart';
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
    this.color = Colors.white,
    this.gradient = HyprInstrumentColors.glass,
    this.borderColor = HyprInstrumentColors.border,
    this.blur = 16,
    this.shadow = false,
    this.inset = false,
    this.overlayOpacity = 0,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Color color;
  final Gradient? gradient;
  final Color borderColor;
  final double blur;
  final bool shadow;
  final bool inset;
  final double overlayOpacity;

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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              HyprColors.popoverTop.withValues(
                alpha: HyprColors.popoverTop.a * overlayOpacity,
              ),
              HyprColors.popoverBottom.withValues(
                alpha: HyprColors.popoverBottom.a * overlayOpacity,
              ),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}
