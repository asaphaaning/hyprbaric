import 'package:flutter/material.dart';

import 'hypr_colors.dart';
import 'hypr_inset_border.dart';
import 'hypr_surface_frame.dart';

class HyprGlassSurface extends StatelessWidget {
  const HyprGlassSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.color = HyprColors.surface,
    this.gradient,
    this.borderColor = HyprColors.border,
    this.blur = 18,
    this.shadow = false,
    this.inset = true,
    this.frame = HyprSurfaceFrame.panel,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Color color;

  /// Material painted instead of [color], for surfaces that are not flat.
  final Gradient? gradient;

  final Color borderColor;
  final double blur;
  final bool shadow;
  final bool inset;
  final HyprSurfaceFrame frame;

  @override
  Widget build(BuildContext context) {
    final List<BoxShadow>? frameShadows = _frameShadows(shadow);
    final BorderSide side = frame == HyprSurfaceFrame.popover
        ? BorderSide.none
        : BorderSide(color: borderColor);

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(borderRadius: borderRadius),
        shadows: frameShadows,
      ),
      child: ClipRSuperellipse(
        borderRadius: borderRadius,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: gradient == null ? color : null,
            gradient: gradient,
            shape: RoundedSuperellipseBorder(
              borderRadius: borderRadius,
              side: side,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: Stack(
              fit: StackFit.passthrough,
              children: <Widget>[
                child,
                if (inset)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: HyprInsetBorder(
                        borderRadius: borderRadius,
                        borderColor: borderColor,
                        frame: frame,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<BoxShadow>? _frameShadows(bool shadow) {
  final List<BoxShadow> shadows = <BoxShadow>[
    if (shadow) ...const <BoxShadow>[
      BoxShadow(
        color: HyprColors.shadow,
        blurRadius: 30,
        offset: Offset(0, 16),
      ),
      BoxShadow(color: Color(0x33000000), blurRadius: 2, offset: Offset(0, 1)),
    ],
  ];

  return shadows.isEmpty ? null : shadows;
}
