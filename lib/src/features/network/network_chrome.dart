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
  static const Color metricTop = Color(0x70030406);
  static const Color metricBottom = Color(0x8A07090D);
  static const Color metricBorder = Color(0x21000000);
  static const Color metricHighlight = Color(0x0AFFFFFF);
  static const Color accent = HyprColors.accentSoft;
  static const Color tx = Color(0xFF92EDFF);
  static const Color rx = Color(0xFF4DE07F);
  static const Color good = rx;
  static const Color link = Color(0xFF78DDF4);
  static const Color warning = Color(0xFFFFC400);
}

/// Visual states for a Wi-Fi entry's floating plate.
enum NetworkWifiTilePhase { idle, hovered, pressed, active, expanded }

/// Reference-derived colours for the Wi-Fi entry plate and its attached
/// password drawer. The drawer deliberately shares [expanded]'s material so
/// selecting an SSID reads as a single continuous card.
abstract final class NetworkWifiColors {
  static const Color tile = Color(0xF0111216);
  static const Color hovered = Color(0xF0191A1F);
  static const Color pressed = Color(0xF00C0D10);
  static const Color active = Color(0xF0171820);
  static const Color expanded = Color(0xF01A1A20);
  static const Color well = Color(0xF008090C);
  static const Color wellFocused = Color(0xF0040507);
  static const Color badge = Color(0xC6000000);
  static const Color rim = Color(0x0EFFFFFF);
  static const Color rimStrong = Color(0x13FFFFFF);
  static const Color cast = Color(0x52000000);
  static const Color castStrong = Color(0x6B000000);
  static const Color focus = Color(0xFF45536D);
}

@immutable
class NetworkWifiTileStyle {
  const NetworkWifiTileStyle({
    required this.fill,
    required this.rim,
    required this.cast,
    required this.glow,
  });

  final Color fill;
  final Color rim;
  final Color cast;
  final Color? glow;

  factory NetworkWifiTileStyle.forPhase(NetworkWifiTilePhase phase) {
    return switch (phase) {
      NetworkWifiTilePhase.idle => const NetworkWifiTileStyle(
        fill: NetworkWifiColors.tile,
        rim: NetworkWifiColors.rim,
        cast: NetworkWifiColors.cast,
        glow: null,
      ),
      NetworkWifiTilePhase.hovered => const NetworkWifiTileStyle(
        fill: NetworkWifiColors.hovered,
        rim: NetworkWifiColors.rimStrong,
        cast: NetworkWifiColors.cast,
        glow: null,
      ),
      NetworkWifiTilePhase.pressed => const NetworkWifiTileStyle(
        fill: NetworkWifiColors.pressed,
        rim: Colors.transparent,
        cast: NetworkWifiColors.castStrong,
        glow: null,
      ),
      NetworkWifiTilePhase.active => const NetworkWifiTileStyle(
        fill: NetworkWifiColors.active,
        rim: NetworkWifiColors.rimStrong,
        cast: NetworkWifiColors.cast,
        glow: Color(0x3316B7F4),
      ),
      NetworkWifiTilePhase.expanded => const NetworkWifiTileStyle(
        fill: NetworkWifiColors.expanded,
        rim: NetworkWifiColors.rimStrong,
        cast: NetworkWifiColors.cast,
        glow: null,
      ),
    };
  }
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
