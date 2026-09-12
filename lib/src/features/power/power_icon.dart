import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The battery instrument's outlined measurement symbols.
enum PowerSymbol { battery, power, voltage, temperature }

/// A consistent stroke vocabulary for the header and telemetry wells.
class PowerIcon extends StatelessWidget {
  const PowerIcon(
    this.symbol, {
    super.key,
    required this.color,
    this.size = 28,
  });

  /// Physical quantity represented by this symbol.
  final PowerSymbol symbol;

  /// Stroke color, inherited from the instrument's signal palette.
  final Color color;

  /// Square logical bounds of the icon.
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _SymbolPainter(symbol, color)),
  );
}

class _SymbolPainter extends CustomPainter {
  const _SymbolPainter(this.symbol, this.color);
  final PowerSymbol symbol;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (symbol) {
      case PowerSymbol.battery:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(7, 5, 18, 24),
            const Radius.circular(2.5),
          ),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(12, 5)
            ..lineTo(12, 2)
            ..lineTo(20, 2)
            ..lineTo(20, 5),
          stroke,
        );
        canvas.drawLine(const Offset(11, 25), const Offset(21, 25), stroke);
      case PowerSymbol.power:
        canvas.drawPath(
          Path()
            ..moveTo(18, 2)
            ..lineTo(7, 18)
            ..lineTo(15, 18)
            ..lineTo(13, 30)
            ..lineTo(25, 13)
            ..lineTo(17, 13)
            ..close(),
          stroke,
        );
      case PowerSymbol.voltage:
        final wave = Path();
        for (var index = 0; index <= 60; index++) {
          final fraction = index / 60;
          final point = Offset(
            3 + fraction * 26,
            16 -
                math.sin(fraction * math.pi * 2) *
                    8 *
                    math.sin(fraction * math.pi),
          );
          if (index == 0) {
            wave.moveTo(point.dx, point.dy);
          } else {
            wave.lineTo(point.dx, point.dy);
          }
        }
        canvas.drawPath(wave, stroke);
      case PowerSymbol.temperature:
        canvas.drawPath(
          Path()
            ..moveTo(12, 19)
            ..lineTo(12, 6)
            ..cubicTo(12, 0, 20, 0, 20, 6)
            ..lineTo(20, 19)
            ..cubicTo(28, 27, 17, 35, 11, 28)
            ..quadraticBezierTo(7, 23, 12, 19),
          stroke,
        );
        canvas.drawLine(const Offset(16, 7), const Offset(16, 23), stroke);
        canvas.drawCircle(const Offset(16, 25), 2.5, Paint()..color = color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SymbolPainter oldDelegate) =>
      symbol != oldDelegate.symbol || color != oldDelegate.color;
}
