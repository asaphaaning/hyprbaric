import 'package:flutter/material.dart';

import '../hypr_surface.dart';

/// The system's indeterminate progress mark.
///
/// Uses the shared appearance accent unless a semantic color is supplied.
class HyprSpinner extends StatelessWidget {
  const HyprSpinner({
    super.key,
    this.size = HyprIconSizes.tiny,
    this.color,
    this.strokeWidth = 1.5,
  });

  /// The compact mark used inline beside a label.
  const HyprSpinner.inline({Key? key, Color? color})
    : this(key: key, size: HyprIconSizes.tiny, color: color);

  /// The standalone mark used to fill an empty panel body.
  const HyprSpinner.panel({Key? key, Color? color})
    : this(key: key, size: HyprIconSizes.large, color: color, strokeWidth: 2);

  final double size;

  /// Optional signal color; otherwise uses the current appearance accent.
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color ?? context.hyprPalette.accent,
      ),
    );
  }
}
