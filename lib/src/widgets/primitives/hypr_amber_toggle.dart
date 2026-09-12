import 'package:flutter/material.dart';

import '../hypr_surface.dart';

/// Shared amber switch indicator. The owning control supplies input and semantics.
class HyprAmberToggle extends StatelessWidget {
  const HyprAmberToggle({super.key, required this.value});

  /// Whether the indicator is lit and its thumb sits on the right.
  final bool value;

  /// Warm signal color shared with the owning control's active icon.
  static const amber = Color(0xFFFFAF32);

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 25,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0x44121115),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: value ? const Color(0x665F421B) : const Color(0x484B536E),
      ),
    ),
    child: AnimatedAlign(
      duration: const Duration(milliseconds: 160),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: value
              ? const Color(0xFFFFF1D8)
              : HyprInstrumentColors.secondary,
          border: Border.all(color: value ? amber : const Color(0x484B536E)),
          boxShadow: value
              ? const [BoxShadow(color: Color(0x88FF9C12), blurRadius: 10)]
              : null,
        ),
      ),
    ),
  );
}
