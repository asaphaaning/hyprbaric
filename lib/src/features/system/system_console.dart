import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';

/// Signal colours for the system occupancy instrument.
abstract final class SystemConsole {
  static const Color text = HyprInstrumentColors.text;
  static const Color secondary = HyprInstrumentColors.secondary;
  static const Color needle = HyprAmberLight.edge;
  static const Color core = HyprAmberLight.core;
  static const Color glow = HyprAmberLight.glow;
  static const Color well = Color(0xE2080B13);
  static const Color wellBorder = Color(0x3346516D);
  static const Color bayBorder = Color(0x303F4961);
  static const Color iconWell = Color(0x70101520);
  static const Color divider = Color(0x3046516D);
  static const Color spark = Color(0xFF9AA8FF);

  static const TextStyle label = HyprInstrumentText.meta;
  static TextStyle get value =>
      HyprInstrumentText.body.copyWith(fontWeight: FontWeight.w500);
}

/// A translucent raised bay that leaves desktop blur to the compositor.
class SystemBay extends StatelessWidget {
  const SystemBay({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SystemConsole.bayBorder),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0x45303949),
            Color(0x24303949),
            Color(0x35232A37),
          ],
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
