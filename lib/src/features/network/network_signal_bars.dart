import 'package:flutter/material.dart';

import '../../theme/hypr_palette.dart';
import 'network_chrome.dart';

class NetworkSignalBars extends StatelessWidget {
  const NetworkSignalBars({
    super.key,
    required this.strength,
    required this.active,
  });

  final int strength;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: CustomPaint(
        painter: NetworkSignalBarsPainter(
          strength: strength,
          color: active
              ? context.hyprPalette.accentSoft
              : NetworkMenuColors.fg2,
        ),
      ),
    );
  }
}

class NetworkSignalBarsPainter extends CustomPainter {
  const NetworkSignalBarsPainter({required this.strength, required this.color});

  final int strength;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final int litBars = strength <= 0
        ? 0
        : (strength.clamp(0, 100) / 25).ceil().clamp(1, 4);
    const double barWidth = 2.5;
    const double gap = 2;
    const List<double> heights = <double>[4, 7, 10, 13];
    final double left = (size.width - (barWidth * 4 + gap * 3)) / 2;
    final double bottom = size.height;

    for (int index = 0; index < heights.length; index += 1) {
      final double opacity = index < litBars ? 1 : 0.25;
      final double x = left + index * (barWidth + gap);
      final double height = heights[index];
      final RRect rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, bottom - height, barWidth, height),
        const Radius.circular(1.2),
      );
      canvas.drawRRect(rect, paint..color = color.withValues(alpha: opacity));
    }
  }

  @override
  bool shouldRepaint(covariant NetworkSignalBarsPainter oldDelegate) {
    return oldDelegate.strength != strength || oldDelegate.color != color;
  }
}
