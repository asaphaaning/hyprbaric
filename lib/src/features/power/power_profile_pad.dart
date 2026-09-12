import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../bindings/bindings.dart';
import '../../widgets/primitives/primitives.dart';
import 'power_console.dart';
import 'power_formatting.dart';

/// A selectable power policy with a decorative, fixed consumption silhouette.
class PowerProfilePad extends StatelessWidget {
  const PowerProfilePad({
    super.key,
    required this.profile,
    required this.active,
    required this.enabled,
    required this.onPressed,
  });
  final PowerProfile profile;
  final bool active;
  final bool enabled;
  final ValueChanged<PowerProfile> onPressed;
  @override
  Widget build(BuildContext context) {
    final color = switch (profile) {
      PowerProfile.saver => const Color(0xFF20DCD0),
      PowerProfile.balanced => const Color(0xFFFFC052),
      PowerProfile.performance => const Color(0xFFC383FF),
    };
    final icon = switch (profile) {
      PowerProfile.saver => Icons.eco,
      PowerProfile.balanced => Icons.bar_chart,
      PowerProfile.performance => Icons.speed,
    };
    return RepaintBoundary(
      child: HyprInteractiveTile(
        semanticLabel: '${profileLabel(profile)} power profile',
        enabled: enabled,
        selected: active,
        onPressed: () => onPressed(profile),
        height: 112,
        borderRadius: BorderRadius.circular(12),
        color: const Color(0x30101420),
        hoverColor: const Color(0x50364050),
        selectedColor: color.withValues(alpha: .08),
        borderColor: const Color(0x60414C69),
        selectedBorderColor: color,
        hoverBorderColor: color.withValues(alpha: .6),
        pressedScale: .985,
        shadowsBuilder: (_) => active
            ? [
                BoxShadow(
                  color: color.withValues(alpha: .22),
                  blurRadius: 10,
                  blurStyle: BlurStyle.outer,
                ),
              ]
            : [],
        builder: (context, state) => Opacity(
          opacity: enabled ? 1 : .42,
          child: Stack(
            children: [
              Positioned(
                left: 9,
                right: 9,
                bottom: 6,
                height: 51,
                child: CustomPaint(painter: _ProfileSpectrum(profile, color)),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: color, size: 26),
                    const SizedBox(height: 3),
                    Text(
                      profileLabel(profile).toUpperCase(),
                      style: PowerConsole.value.copyWith(
                        fontSize: 13.5,
                        letterSpacing: .6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profileSubtitle(profile).toUpperCase(),
                      style: PowerConsole.label.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Icon(
                  active
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 19,
                  color: active ? color : const Color(0xFF475170),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSpectrum extends CustomPainter {
  const _ProfileSpectrum(this.profile, this.color);
  final PowerProfile profile;
  final Color color;
  double height(double fraction) => switch (profile) {
    PowerProfile.saver => .08 + .42 * math.exp(-fraction * 4),
    PowerProfile.balanced =>
      .18 + .45 * math.exp(-math.pow((fraction - .5) * 4, 2)),
    PowerProfile.performance =>
      .12 + .72 / (1 + math.exp(-(fraction - .68) * 8)),
  };
  @override
  void paint(Canvas canvas, Size size) {
    for (var column = 1; column < 9; column++) {
      for (var row = 0; row < 9; row++) {
        canvas.drawCircle(
          Offset(size.width * column / 9, size.height * row / 9),
          .45,
          Paint()..color = color.withValues(alpha: .25),
        );
      }
    }
    for (var index = 0; index < 17; index++) {
      final fraction = index / 16;
      final barHeight =
          size.height * height(fraction) * (.75 + .15 * math.sin(index * 1.7));
      final rect = Rect.fromLTWH(
        index * size.width / 17 + 1,
        size.height - barHeight,
        size.width / 17 * .52,
        barHeight,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color, color.withValues(alpha: .03)],
          ).createShader(rect),
      );
    }
    final path = Path();
    for (var step = 0; step <= 80; step++) {
      final fraction = step / 80;
      final point = Offset(
        fraction * size.width,
        size.height * (1 - height(fraction)) - 3,
      );
      if (step == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_ProfileSpectrum oldDelegate) =>
      profile != oldDelegate.profile || color != oldDelegate.color;
}
