import 'package:flutter/material.dart';

import 'hypr_colors.dart';
import 'hypr_surface_frame.dart';

class HyprInsetBorder extends StatelessWidget {
  const HyprInsetBorder({
    super.key,
    required this.borderRadius,
    required this.borderColor,
    required this.frame,
  });

  final BorderRadius borderRadius;
  final Color borderColor;
  final HyprSurfaceFrame frame;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: HyprInsetBorderPainter(
        borderRadius: borderRadius,
        borderColor: borderColor,
        frame: frame,
      ),
    );
  }
}

class HyprInsetBorderPainter extends CustomPainter {
  const HyprInsetBorderPainter({
    required this.borderRadius,
    required this.borderColor,
    required this.frame,
  });

  final BorderRadius borderRadius;
  final Color borderColor;
  final HyprSurfaceFrame frame;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 2 || size.height <= 4) {
      return;
    }

    if (frame == HyprSurfaceFrame.popover) {
      _drawPopoverStroke(canvas, size);
      // Held clear of the corner curves: a full-width line has to be cut off
      // by the clip mid-arc, which shows up as a broken nub in the corner.
      final double corner =
          borderRadius.resolve(TextDirection.ltr).topLeft.x + 2;
      _drawInsetLine(
        canvas,
        Rect.fromLTWH(corner, 2, size.width - corner * 2, 1),
        const <Color>[
          Color(0x00FFFFFF),
          HyprColors.popupInset,
          HyprColors.popupInset,
          Color(0x00FFFFFF),
        ],
      );
      return;
    }

    _drawInsetLine(
      canvas,
      Rect.fromLTWH(1, 1, size.width - 2, 1),
      const <Color>[
        Color(0x00D8F4FF),
        HyprColors.inset,
        Color(0x20FFFFFF),
        Color(0x00D8F4FF),
      ],
    );
    _drawInsetLine(
      canvas,
      Rect.fromLTWH(1, 2, size.width - 2, 1),
      const <Color>[
        Color(0x0056C4E2),
        HyprColors.insetSoft,
        Color(0x1056C4E2),
        Color(0x0056C4E2),
      ],
    );
    _drawInsetLine(
      canvas,
      Rect.fromLTWH(1, size.height - 2, size.width - 2, 1),
      const <Color>[
        Color(0x00D8F4FF),
        HyprColors.insetBottom,
        Color(0x12FFFFFF),
        Color(0x00D8F4FF),
      ],
    );
  }

  /// Only the inner ring is painted here. The outer ring rides on the
  /// surface's unclipped decoration instead: a stroke sitting on the clip
  /// boundary is half cut away, and the clip and stroke approximate the
  /// superellipse differently, so the arc breaks up in the corners.
  void _drawPopoverStroke(Canvas canvas, Size size) {
    final BorderRadius resolved = borderRadius.resolve(TextDirection.ltr);
    final Rect outerRect = Offset.zero & size;
    final Paint innerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRSuperellipse(
      resolved.toRSuperellipse(outerRect.deflate(1.5)),
      innerPaint,
    );
  }

  void _drawInsetLine(Canvas canvas, Rect rect, List<Color> colors) {
    final Paint paint = Paint()
      ..shader = LinearGradient(
        colors: colors,
        stops: const <double>[0, 0.22, 0.78, 1],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant HyprInsetBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.frame != frame;
  }
}
