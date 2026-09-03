import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';

abstract final class NetworkMenuColors {
  static const Color fg1 = Color(0xECCBD2DA);
  static const Color fg2 = Color(0xC8BEC7D0);
  static const Color fg3 = Color(0xA0929DA8);
  static const Color tile = Color(0xE60B0C0E);
  static const Color tileHover = Color(0xEB121314);
  static const Color hover = HyprColors.hover;
  static const Color rowHover = Color(0x0DFFFFFF);
  static const Color rowPressed = HyprColors.hoverStrong;
  static const Color rowSelected = Color(0x0FFFFFFF);
  static const Color cardBorder = Color(0x28384D5A);
  static const Color accent = HyprColors.accentSoft;
  static const Color tx = Color(0xFF92EDFF);
  static const Color rx = Color(0xFF4DE07F);
  static const Color good = rx;
  static const Color link = Color(0xFF78DDF4);
  static const Color warning = Color(0xFFFFC400);
}

class NetworkSectionTitle extends StatelessWidget {
  const NetworkSectionTitle(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return HyprSectionLabel(label, color: NetworkMenuColors.fg3);
  }
}

class NetworkEmptyState extends StatelessWidget {
  const NetworkEmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return HyprEmptyState(
      message: message,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      textAlign: TextAlign.start,
      messageStyle: HyprTypography.popRow.copyWith(
        color: NetworkMenuColors.fg3,
      ),
    );
  }
}
