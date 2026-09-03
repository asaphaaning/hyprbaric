import 'package:flutter/material.dart';

import '../hypr_surface.dart';

/// The system's indeterminate progress mark.
///
/// Material's [CircularProgressIndicator] reads its colour from the ambient
/// [ThemeData], which differs between the bar, the catalog and the web embed,
/// so the same spinner rendered in three places came out three colours. This
/// pins the colour and stroke to the design tokens and leaves the ambient
/// theme out of it.
class HyprSpinner extends StatelessWidget {
  const HyprSpinner({
    super.key,
    this.size = HyprIconSizes.tiny,
    this.color = HyprColors.accent,
    this.strokeWidth = 1.5,
  });

  /// The compact mark used inline beside a label.
  const HyprSpinner.inline({Key? key, Color color = HyprColors.accent})
    : this(key: key, size: HyprIconSizes.tiny, color: color);

  /// The standalone mark used to fill an empty panel body.
  const HyprSpinner.panel({Key? key, Color color = HyprColors.accent})
    : this(key: key, size: HyprIconSizes.large, color: color, strokeWidth: 2);

  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color,
      ),
    );
  }
}
