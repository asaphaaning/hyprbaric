import 'package:flutter/material.dart';

/// Typography and signal colors of the battery instrument.
abstract final class PowerConsole {
  static const text = Color(0xFFF0EFFF);
  static const muted = Color(0xFFA2ADD3);
  static const pink = Color(0xFFE68AFF);
  static const label = TextStyle(
    fontFamily: 'Roboto Condensed',
    fontSize: 12,
    letterSpacing: 1.8,
    color: muted,
    height: 1.2,
  );
  static const value = TextStyle(
    fontFamily: 'Roboto Condensed',
    fontSize: 19,
    fontWeight: FontWeight.w600,
    color: text,
    height: 1.2,
  );
}

/// A translucent raised bay that leaves desktop blur to the compositor.
class PowerBay extends StatelessWidget {
  const PowerBay({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x303F4961)),
      gradient: const LinearGradient(
        colors: [Color(0x70303949), Color(0x30303949), Color(0x50232A37)],
      ),
    ),
    child: Padding(padding: padding, child: child),
  );
}

/// One labelled measurement, shared by the battery telemetry strip.
class PowerMetric extends StatelessWidget {
  const PowerMetric({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x70101520),
        ),
        child: Icon(icon, color: const Color(0xFFC0BCFF), size: 27),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: PowerConsole.value),
            ),
            const SizedBox(height: 4),
            Text(label, style: PowerConsole.label),
          ],
        ),
      ),
    ],
  );
}
