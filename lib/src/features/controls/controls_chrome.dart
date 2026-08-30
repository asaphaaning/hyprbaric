import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';

abstract final class ControlColors {
  static const Color chassis = Color(0xEE03050B);
  static const Color tray = Color(0xFF121216);
  static const Color trayBorder = Color(0x182E3036);
  static const Color trayHighlight = Color(0x10FFFFFF);
  static const Color tile = Color(0xFF17171C);
  static const Color tileHover = Color(0xFF202027);
  static const Color tilePressed = Color(0xFF111116);
  static const Color well = Color(0xFF0D0D0F);
  static const Color wellBottom = Color(0xFF101014);
  static const Color label = Color(0xFF666870);
  static const Color text = Color(0xFFB0B1B7);
  static const Color textMuted = Color(0xFF898B93);
  static const Color textFaint = Color(0xFF555760);
  static const Color danger = Color(0xFFE16658);
}

class ControlSectionTray extends StatelessWidget {
  const ControlSectionTray({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const BorderRadius radius = BorderRadius.all(Radius.circular(17));

    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: ControlColors.tray,
        shape: RoundedSuperellipseBorder(
          borderRadius: radius,
          side: BorderSide(color: ControlColors.trayBorder),
        ),
      ),
      child: ClipRSuperellipse(
        borderRadius: radius,
        child: Stack(
          children: <Widget>[
            const Positioned(
              top: 1,
              left: 16,
              right: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      Colors.transparent,
                      ControlColors.trayHighlight,
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SizedBox(height: 1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 17, 17, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ControlSectionLabel(label),
                  const SizedBox(height: 13),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ControlSectionLabel extends StatelessWidget {
  const ControlSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 13,
      child: Row(
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: HyprTypography.compactMonoStrong.copyWith(
              color: ControlColors.label,
              fontSize: HyprTypography.size(10.5),
              fontWeight: FontWeight.w600,
              height: 1,
              letterSpacing: 1.05,
              shadows: const <Shadow>[
                Shadow(
                  color: Color(0xBF000000),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Color(0x003C3D43),
                    Color(0x993C3D43),
                    Color(0x003C3D43),
                  ],
                ),
              ),
              child: SizedBox(height: 1),
            ),
          ),
        ],
      ),
    );
  }
}
