import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../widgets/hypr_surface.dart';

/// Outlined measurement symbols for the system instrument.
enum SystemSymbol { cpu, memory, disk, uptime, temperature, processes }

/// A consistent stroke vocabulary for the header, meters, and footer wells.
class SystemIcon extends StatelessWidget {
  const SystemIcon(
    this.symbol, {
    super.key,
    required this.color,
    this.size = 22,
  });

  final SystemSymbol symbol;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final IconData? glyph = switch (symbol) {
      SystemSymbol.cpu => Iconsax.cpu,
      SystemSymbol.memory => Iconsax.ram,
      _ => null,
    };
    if (glyph != null) {
      return Icon(glyph, size: size, color: color);
    }
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SymbolPainter(symbol, color)),
    );
  }
}

class _SymbolPainter extends CustomPainter {
  const _SymbolPainter(this.symbol, this.color);

  final SystemSymbol symbol;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (symbol) {
      case SystemSymbol.cpu || SystemSymbol.memory:
        break;
      case SystemSymbol.disk:
        canvas.drawOval(const Rect.fromLTWH(6, 7, 20, 18), stroke);
        canvas.drawOval(const Rect.fromLTWH(13, 13.5, 6, 5), stroke);
        canvas.drawLine(const Offset(16, 16), const Offset(22, 11), stroke);
      case SystemSymbol.uptime:
        canvas.drawCircle(const Offset(16, 16), 10.5, stroke);
        canvas.drawLine(const Offset(16, 16), const Offset(16, 10), stroke);
        canvas.drawLine(const Offset(16, 16), const Offset(21, 18), stroke);
      case SystemSymbol.temperature:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(13, 4, 6, 16),
            const Radius.circular(3),
          ),
          stroke,
        );
        canvas.drawCircle(const Offset(16, 24), 6, stroke);
        canvas.drawLine(const Offset(16, 12), const Offset(16, 23), stroke);
      case SystemSymbol.processes:
        final Path pulse = Path()
          ..moveTo(4, 18)
          ..lineTo(9, 18)
          ..lineTo(12, 8)
          ..lineTo(16, 24)
          ..lineTo(20, 14)
          ..lineTo(23, 18)
          ..lineTo(28, 18);
        canvas.drawPath(pulse, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SymbolPainter oldDelegate) {
    return oldDelegate.symbol != symbol || oldDelegate.color != color;
  }
}

/// Tiny circular well used beside meter labels and footer stats.
class SystemGlyphWell extends StatelessWidget {
  const SystemGlyphWell({super.key, required this.symbol, this.size = 28});

  final SystemSymbol symbol;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size + 4,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0x70101520),
      ),
      child: Center(
        child: SystemIcon(
          symbol,
          color: HyprInstrumentColors.secondary,
          size: size * 0.72,
        ),
      ),
    );
  }
}
