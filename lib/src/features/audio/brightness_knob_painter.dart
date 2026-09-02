import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';

class BrightnessKnobPainter extends CustomPainter {
  const BrightnessKnobPainter({
    required this.value,
    required this.enabled,
    this.console = false,
    this.lampValue,
  });

  static const double _startAngle = -135;
  static const double _sweepAngle = 270;

  final double value;
  final bool enabled;
  final bool console;
  final double? lampValue;

  @override
  void paint(Canvas canvas, Size size) {
    final double progress = value.clamp(0.0, 1.0);
    final Offset center = size.center(Offset.zero);
    final double arcRadius = size.width * 48 / 92;
    final Rect arcRect = Rect.fromCircle(center: center, radius: arcRadius);
    final double start = _degreesToRadians(_startAngle - 90);
    final double sweep = _degreesToRadians(_sweepAngle);
    final double activeSweep = sweep * progress;
    final bool lit = enabled && progress > 0.001;

    if (console) {
      final double lampProgress = (lampValue ?? value).clamp(0.0, 1.0);
      _paintConsoleKnob(
        canvas,
        center,
        size.width,
        progress,
        lampProgress,
        enabled && lampProgress > 0.001,
      );
      return;
    }

    canvas.drawArc(
      arcRect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 7
        ..color = Colors.black.withValues(alpha: 0.5),
    );
    canvas.drawArc(
      arcRect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4
        ..color = const Color(0xFF29333C),
    );

    if (lit) {
      final Paint glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5
        ..color = const Color(0x88F0D76C)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawArc(arcRect, start, activeSweep, false, glow);

      final Paint active = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFE78B), Color(0xFFE39D30)],
        ).createShader(arcRect);
      canvas.drawArc(arcRect, start, activeSweep, false, active);
    }

    _paintTicks(canvas, center, size.width);
    _paintBezel(canvas, center, size.width, lit);
    _paintPointer(canvas, center, size.width, progress, lit);
  }

  void _paintConsoleKnob(
    Canvas canvas,
    Offset center,
    double width,
    double progress,
    double lampProgress,
    bool lit,
  ) {
    final double faceRadius = width * 0.35;
    final double lipRadius = faceRadius + 5;

    _paintLampSpill(canvas, center, width, lampProgress, lit);
    _paintConsoleShadow(canvas, center, width, lipRadius);
    _paintConsoleLip(canvas, center, lipRadius, faceRadius);
    _paintConsoleFace(canvas, center, faceRadius);
    _paintDotRing(canvas, center, width, lampProgress, lit);

    final double angle = _degreesToRadians(
      _startAngle + progress * _sweepAngle - 90,
    );
    final Offset direction = Offset(math.cos(angle), math.sin(angle));
    final Offset pointerStart = center + direction * (faceRadius * 0.49);
    final Offset pointerEnd = center + direction * (faceRadius * 0.87);
    canvas.drawLine(
      pointerStart.translate(0.6, 0.8),
      pointerEnd.translate(0.6, 0.8),
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3
        ..color = const Color(0xA6000000),
    );
    canvas.drawLine(
      pointerStart,
      pointerEnd,
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2
        ..color = enabled
            ? const Color(0xFFF7F7F4)
            : HyprColors.textFaint.withValues(alpha: 0.55),
    );
  }

  void _paintConsoleShadow(
    Canvas canvas,
    Offset center,
    double width,
    double lipRadius,
  ) {
    canvas.drawCircle(
      center.translate(width * 0.075, width * 0.105),
      lipRadius - 1,
      Paint()
        ..color = const Color(0xD9000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.095),
    );
    canvas.drawCircle(
      center.translate(-width * 0.045, -width * 0.05),
      lipRadius - 1,
      Paint()
        ..color = const Color(0x244F5155)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.06),
    );
  }

  void _paintConsoleLip(
    Canvas canvas,
    Offset center,
    double lipRadius,
    double faceRadius,
  ) {
    final Rect lipRect = Rect.fromCircle(center: center, radius: lipRadius);
    final Path annulus = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(lipRect)
      ..addOval(Rect.fromCircle(center: center, radius: faceRadius));

    canvas.drawPath(
      annulus,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF3B3D42),
            Color(0xFF303237),
            Color(0xFF1B1C1F),
            Color(0xFF0B0C0E),
          ],
          stops: <double>[0, 0.3, 0.7, 1],
        ).createShader(lipRect),
    );
    canvas.drawCircle(
      center,
      lipRadius - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75
        ..color = const Color(0x42000000),
    );
  }

  void _paintConsoleFace(Canvas canvas, Offset center, double faceRadius) {
    final Rect faceRect = Rect.fromCircle(center: center, radius: faceRadius);

    canvas.drawCircle(
      center.translate(0, 0.5),
      faceRadius + 0.25,
      Paint()
        ..color = const Color(0x61000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
    );
    canvas.drawCircle(
      center,
      faceRadius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF101113),
            Color(0xFF121316),
            Color(0xFF1B1D20),
            Color(0xFF25272A),
          ],
          stops: <double>[0, 0.42, 0.76, 1],
        ).createShader(faceRect),
    );
    canvas.drawCircle(
      center,
      faceRadius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.24, 1.15),
          radius: 1.15,
          colors: <Color>[
            Color(0x303D3F43),
            Color(0x1836383B),
            Color(0x08323538),
            Color(0x00303336),
          ],
          stops: <double>[0, 0.34, 0.62, 0.84],
        ).createShader(faceRect),
    );
    canvas.drawCircle(
      center,
      faceRadius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.08, -1.05),
          radius: 1.16,
          colors: <Color>[
            Color(0x72000000),
            Color(0x28000000),
            Color(0x00000000),
          ],
          stops: <double>[0, 0.38, 0.78],
        ).createShader(faceRect),
    );
  }

  void _paintLampSpill(
    Canvas canvas,
    Offset center,
    double width,
    double progress,
    bool lit,
  ) {
    if (!lit) {
      return;
    }

    final double warmth = progress * progress;
    final Color lamp = Color.lerp(
      const Color(0xFFF8FAF5),
      const Color(0xFFFFCF55),
      warmth,
    )!;
    final Rect spill = Rect.fromCircle(center: center, radius: width * 0.567);
    canvas.drawCircle(
      center.translate(-width * 0.08, width * 0.04),
      width * 0.48,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            lamp.withValues(alpha: 0.10 * progress),
            lamp.withValues(alpha: 0.04 * progress),
            Colors.transparent,
          ],
          stops: const <double>[0, 0.58, 1],
        ).createShader(Rect.fromCircle(center: center, radius: width * 0.48))
        ..blendMode = BlendMode.plus,
    );
    canvas.drawArc(
      spill,
      _degreesToRadians(_startAngle - 90),
      _degreesToRadians(_sweepAngle * progress),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width * 0.14
        ..color = lamp.withValues(alpha: 0.08 + progress * 0.08)
        ..blendMode = BlendMode.plus
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.075),
    );
  }

  void _paintDotRing(
    Canvas canvas,
    Offset center,
    double width,
    double progress,
    bool lit,
  ) {
    const int dots = 28;
    // A blur sigma that tracks the value would rebuild the mask every frame of
    // a scrub, so hold it constant and carry the change in alpha instead.
    const double glowSigma = 3.6;
    const Color inactive = Color(0xFF2D3033);

    final double radius = width * 0.567;
    final double glowRadius = 3.1 + progress * 0.7;
    final double illuminatedDots = lit ? progress * dots : 0;
    final double warmth = progress * progress;
    final Color lamp = Color.lerp(
      const Color(0xFFF8FAF5),
      const Color(0xFFFFD05A),
      warmth,
    )!;

    final List<Offset> centers = <Offset>[];
    final List<double> intensities = <double>[];
    final Path steadyGlow = Path();
    Offset? edge;
    double edgeIntensity = 0;

    for (int index = 0; index < dots; index += 1) {
      final double fraction = index / (dots - 1);
      final double angle = _degreesToRadians(
        _startAngle + fraction * _sweepAngle - 90,
      );
      final Offset dot =
          center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final double intensity = Curves.easeOutCubic.transform(
        (illuminatedDots - index).clamp(0.0, 1.0),
      );
      centers.add(dot);
      intensities.add(intensity);

      // Every lit dot but the leading one glows at full strength, so they can
      // share a single blurred draw instead of one per dot.
      if (intensity >= 1) {
        steadyGlow.addOval(Rect.fromCircle(center: dot, radius: glowRadius));
      } else if (intensity > 0) {
        edge = dot;
        edgeIntensity = intensity;
      }
    }

    Paint glowPaint(double alpha) => Paint()
      ..color = lamp.withValues(alpha: alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, glowSigma);

    if (!steadyGlow.getBounds().isEmpty) {
      canvas.drawPath(steadyGlow, glowPaint(0.34));
    }
    if (edge case final Offset dot) {
      canvas.drawCircle(dot, glowRadius, glowPaint(0.34 * edgeIntensity));
    }

    final Paint core = Paint();
    for (int index = 0; index < dots; index += 1) {
      core.color = Color.lerp(inactive, lamp, intensities[index])!;
      canvas.drawCircle(centers[index], 1.7, core);
    }
  }

  void _paintTicks(Canvas canvas, Offset center, double width) {
    final Paint paint = Paint()..strokeCap = StrokeCap.round;
    for (int i = 0; i < 5; i += 1) {
      final double t = i / 4;
      final double angle = _degreesToRadians(
        _startAngle + t * _sweepAngle - 90,
      );
      final bool major = i == 0 || i == 4;
      final double outer = width * 46 / 92;
      final double inner = outer - (major ? 6 : 4);
      final Offset direction = Offset(math.cos(angle), math.sin(angle));
      paint
        ..strokeWidth = 1
        ..color = (major ? HyprColors.textMuted : HyprColors.textFaint)
            .withValues(alpha: major ? 0.7 : 0.4);
      canvas.drawLine(
        center + direction * inner,
        center + direction * outer,
        paint,
      );
    }
  }

  void _paintBezel(Canvas canvas, Offset center, double width, bool lit) {
    final double radius = width * 30 / 92;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final Paint shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center.translate(0, 5), radius * 0.95, shadow);

    canvas.drawCircle(
      center,
      radius + 2,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0x663F4851), Color(0x00222A33)],
          stops: <double>[0, 0.55],
        ).createShader(rect.inflate(2)),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.42, -0.50),
          radius: 0.92,
          colors: <Color>[
            Color(0xFF575E66),
            Color(0xFF262D36),
            Color(0xFF121820),
          ],
          stops: <double>[0, 0.60, 1],
        ).createShader(rect),
    );
    canvas.drawCircle(
      center,
      radius - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.5),
    );
    canvas.drawArc(
      rect.deflate(0.75),
      _degreesToRadians(205),
      _degreesToRadians(130),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: lit ? 0.13 : 0.09),
    );
    canvas.drawArc(
      rect.deflate(0.75),
      _degreesToRadians(35),
      _degreesToRadians(118),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.45),
    );
  }

  void _paintPointer(
    Canvas canvas,
    Offset center,
    double width,
    double progress,
    bool lit,
  ) {
    final double angle = _degreesToRadians(
      _startAngle + progress * _sweepAngle - 90,
    );
    final Offset direction = Offset(math.cos(angle), math.sin(angle));
    final Offset tipCenter = center + direction * (width * 33 / 92);
    final Offset tangent = Offset(-direction.dy, direction.dx);
    final Path pointer = Path()
      ..moveTo((tipCenter + tangent * 1.5).dx, (tipCenter + tangent * 1.5).dy)
      ..lineTo((tipCenter - tangent * 1.5).dx, (tipCenter - tangent * 1.5).dy)
      ..lineTo(
        (tipCenter - direction * 9 - tangent * 1.5).dx,
        (tipCenter - direction * 9 - tangent * 1.5).dy,
      )
      ..lineTo(
        (tipCenter - direction * 9 + tangent * 1.5).dx,
        (tipCenter - direction * 9 + tangent * 1.5).dy,
      )
      ..close();

    if (lit) {
      canvas.drawPath(
        pointer,
        Paint()
          ..color = const Color(0xBCEFD96E)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    canvas.drawPath(
      pointer,
      Paint()
        ..color = lit
            ? const Color(0xFFEFD96E)
            : HyprColors.textMuted.withValues(alpha: 0.55),
    );
  }

  static double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  @override
  bool shouldRepaint(covariant BrightnessKnobPainter oldDelegate) {
    return value != oldDelegate.value ||
        enabled != oldDelegate.enabled ||
        console != oldDelegate.console ||
        lampValue != oldDelegate.lampValue;
  }
}
