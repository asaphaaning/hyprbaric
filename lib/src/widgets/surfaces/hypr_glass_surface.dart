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
    if (frame == HyprSurfaceFrame.popover) {
      return _buildPopover(frameShadows);
    }

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
              side: BorderSide(color: borderColor),
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

  /// Popover chrome is painted as one superellipse, then content is clipped to
  /// the same shape. A [ShapeDecoration] stroke would pad the child by the
  /// border width and keep the original radii, so the clip and the ring stop
  /// nesting at the corner apex and leave a pale fringe.
  Widget _buildPopover(List<BoxShadow>? frameShadows) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(borderRadius: borderRadius),
        shadows: frameShadows,
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _PopoverFillPainter(
                color: color,
                gradient: gradient,
                borderRadius: borderRadius,
              ),
            ),
          ),
          ClipRSuperellipse(
            borderRadius: borderRadius,
            clipBehavior: Clip.hardEdge,
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
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _PopoverRingPainter(
                  borderRadius: borderRadius,
                  innerColor: borderColor,
                  outerColor: HyprColors.popupOuterRing,
                ),
              ),
            ),
          ),
        ],
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

class _PopoverFillPainter extends CustomPainter {
  const _PopoverFillPainter({
    required this.color,
    required this.gradient,
    required this.borderRadius,
  });

  final Color color;
  final Gradient? gradient;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final RSuperellipse shape = borderRadius
        .resolve(TextDirection.ltr)
        .toRSuperellipse(Offset.zero & size);
    final Paint paint = Paint()..color = color;
    if (gradient != null) {
      paint.shader = gradient!.createShader(Offset.zero & size);
    }
    canvas.drawRSuperellipse(shape, paint);
  }

  @override
  bool shouldRepaint(covariant _PopoverFillPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.gradient != gradient ||
        oldDelegate.borderRadius != borderRadius;
  }
}

/// Dark outer ring and light inner hairline, both offset from the same
/// [RSuperellipse] as the fill.
class _PopoverRingPainter extends CustomPainter {
  const _PopoverRingPainter({
    required this.borderRadius,
    required this.innerColor,
    required this.outerColor,
  });

  final BorderRadius borderRadius;
  final Color innerColor;
  final Color outerColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final RSuperellipse shape = borderRadius
        .resolve(TextDirection.ltr)
        .toRSuperellipse(Offset.zero & size);
    _fillRing(canvas, outer: shape, inner: shape.deflate(1), color: outerColor);
    _fillRing(
      canvas,
      outer: shape.deflate(1),
      inner: shape.deflate(2),
      color: innerColor,
    );
  }

  void _fillRing(
    Canvas canvas, {
    required RSuperellipse outer,
    required RSuperellipse inner,
    required Color color,
  }) {
    final Path path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRSuperellipse(outer)
      ..addRSuperellipse(inner);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PopoverRingPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.innerColor != innerColor ||
        oldDelegate.outerColor != outerColor;
  }
}
