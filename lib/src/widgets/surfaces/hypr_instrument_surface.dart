import 'package:flutter/material.dart';

import 'hypr_glass_surface.dart';
import 'hypr_surface_frame.dart';

/// Common materials for the mixer, network and battery instruments.
abstract final class HyprInstrumentColors {
  static const text = Color(0xFFF7F6FF);
  static const secondary = Color(0xFFB8C4FF);
  static const border = Color(0x887E86B4);

  /// The gradient owns opacity; its tint must not be multiplied by another fill.
  static const glass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xC914171E), Color(0xBC101218), Color(0xD00B0E13)],
    stops: [0, .55, 1],
  );
}

/// Corner-safe charcoal glass shared by all three instrument popovers.
///
/// Hyprland blurs the desktop behind this translucent surface. A Flutter
/// backdrop filter would only sample this window, not the desktop beneath it.
/// Section overlays should remain translucent to preserve that composition.
class HyprInstrumentSurface extends StatelessWidget {
  const HyprInstrumentSurface({
    super.key,
    required this.borderRadius,
    required this.child,
    this.borderColor = HyprInstrumentColors.border,
  });

  /// The same radius clips the contents and draws the outer frame.
  final BorderRadius borderRadius;

  /// Instrument-specific layout and translucent section overlays.
  final Widget child;

  /// Frame intensity, independent of the shared glass opacity.
  final Color borderColor;

  @override
  Widget build(BuildContext context) => HyprGlassSurface(
    borderRadius: borderRadius,
    color: Colors.white,
    gradient: HyprInstrumentColors.glass,
    borderColor: borderColor,
    frame: HyprSurfaceFrame.popover,
    inset: false,
    child: child,
  );
}
