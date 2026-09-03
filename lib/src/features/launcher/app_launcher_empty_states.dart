import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';

class LauncherLoadingState extends StatelessWidget {
  const LauncherLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: HyprSpinner(size: HyprIconSizes.action, strokeWidth: 2),
    );
  }
}

class LauncherEmptyState extends StatelessWidget {
  const LauncherEmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'NO MATCHES',
              style: HyprTypography.compactMonoStrong.copyWith(
                color: HyprColors.textMuted,
                fontSize: HyprTypography.size(11),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.66,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: HyprTypography.compactMono.copyWith(
                color: HyprColors.textFaint,
                fontSize: HyprTypography.size(10),
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LauncherDotGridPainter extends CustomPainter {
  const LauncherDotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..style = PaintingStyle.fill;
    for (double y = 0; y < size.height; y += 11) {
      for (double x = 0; x < size.width; x += 11) {
        final double alpha = (1 - (y / size.height)).clamp(0.24, 1.0);
        paint.color = Colors.white.withValues(alpha: 0.045 * alpha);
        canvas.drawCircle(Offset(x - 1, y - 1), 0.75, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant LauncherDotGridPainter oldDelegate) => false;
}
