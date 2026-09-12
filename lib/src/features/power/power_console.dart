import 'package:flutter/material.dart';
import '../../widgets/hypr_surface.dart';
import 'power_icon.dart';

/// Typography and signal colors of the battery instrument.
abstract final class PowerConsole {
  static const text = HyprInstrumentColors.text;
  static const muted = HyprInstrumentColors.secondary;
  static const pink = Color(0xFFE68AFF);
  static const label = HyprInstrumentText.meta;
  static TextStyle get value =>
      HyprInstrumentText.body.copyWith(fontWeight: FontWeight.w500);
}

/// A translucent raised bay that leaves desktop blur to the compositor.
class PowerBay extends StatelessWidget {
  const PowerBay({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
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
                style: PowerConsole.value.copyWith(fontSize: 14.5),
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

/// Highlighted measurement with smaller, baseline-aligned unit suffixes.
class PowerReadout extends StatelessWidget {
  PowerReadout({
    super.key,
    required String value,
    String unit = '',
    this.size = 40,
  }) : _parts = [(value: value, unit: unit)];

  /// Formats remaining-time estimates without treating the unit letters as digits.
  factory PowerReadout.duration(Duration? remaining, {Key? key}) {
    if (remaining == null || remaining.inSeconds <= 0) {
      return PowerReadout(key: key, value: '--');
    }
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    return PowerReadout._(
      key: key,
      parts: [
        if (hours > 0) (value: '$hours', unit: 'h '),
        (value: hours > 0 ? '$minutes'.padLeft(2, '0') : '$minutes', unit: 'm'),
      ],
    );
  }

  const PowerReadout._({
    super.key,
    required List<({String value, String unit})> parts,
  }) : _parts = parts,
       size = 40;

  final List<({String value, String unit})> _parts;

  /// Preferred logical font size; long estimates scale down within their bay.
  final double size;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF0D8FF), PowerConsole.pink],
      ).createShader(bounds),
      child: Text.rich(
        TextSpan(
          children: [
            for (final part in _parts) ...[
              TextSpan(text: part.value),
              TextSpan(
                text: part.unit,
                style: TextStyle(fontSize: size * .62),
              ),
            ],
          ],
        ),
        maxLines: 1,
        softWrap: false,
        style: PowerConsole.value.copyWith(
          fontSize: size,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    ),
  );
}
