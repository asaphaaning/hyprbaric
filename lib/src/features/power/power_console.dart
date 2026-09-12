import 'package:flutter/material.dart';
import '../../widgets/hypr_surface.dart';
import 'power_icon.dart';

/// Typography and signal colors of the battery instrument.
abstract final class PowerConsole {
  static const text = HyprInstrumentColors.text;
  static const muted = HyprInstrumentColors.secondary;
  static const pink = Color(0xFFE68AFF);
  static const label = TextStyle(
    fontFamily: 'Roboto Condensed',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.8,
    color: muted,
    height: 1.2,
  );
  static const value = TextStyle(
    fontFamily: 'Roboto Condensed',
    fontSize: 19,
    fontWeight: FontWeight.w500,
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
        colors: [Color(0x45303949), Color(0x24303949), Color(0x35232A37)],
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
  final PowerSymbol icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 28,
        height: 32,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x70101520),
        ),
        child: Center(
          child: PowerIcon(
            icon,
            color: HyprInstrumentColors.secondary,
            size: 23,
          ),
        ),
      ),
      const SizedBox(width: 5),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: PowerConsole.value.copyWith(fontSize: 16),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: PowerConsole.label.copyWith(
                fontSize: 10.5,
                letterSpacing: .8,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Highlighted numeric display with a smaller, baseline-aligned unit suffix.
class PowerReadout extends StatelessWidget {
  const PowerReadout({
    super.key,
    required this.value,
    this.unit = '',
    this.size = 45,
  });

  /// Formatted measurement, or an explicit unavailable marker.
  final String value;

  /// Compact suffix such as percent or minutes.
  final String unit;

  /// Main value's logical font size.
  final double size;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (bounds) => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF0D8FF), PowerConsole.pink],
    ).createShader(bounds),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: value),
          if (unit.isNotEmpty)
            TextSpan(
              text: unit,
              style: TextStyle(fontSize: size * .66),
            ),
        ],
      ),
      style: PowerConsole.value.copyWith(
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.1,
      ),
    ),
  );
}
