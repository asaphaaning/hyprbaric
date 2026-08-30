import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'controls_chrome.dart';

class ControlInspectButton extends StatelessWidget {
  const ControlInspectButton({
    super.key,
    required this.label,
    required this.shortcut,
    required this.icon,
    this.onPressed,
    this.active = false,
  });

  final String label;
  final String shortcut;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return HyprInteractionRegion(
      semanticLabel: label,
      enabled: onPressed != null,
      onPressed: onPressed,
      builder: (BuildContext context, HyprInteractionState state) {
        final Color accent = context.hyprPalette.accent;
        final Color color = active
            ? Color.alphaBlend(
                accent.withValues(alpha: 0.16),
                ControlColors.tile,
              )
            : state.pressed
            ? ControlColors.tilePressed
            : state.hovered
            ? ControlColors.tileHover
            : ControlColors.tile;

        return AnimatedContainer(
          duration: HyprMotion.hover,
          curve: HyprMotion.hoverCurve,
          height: 53,
          transform: Matrix4.translationValues(0, state.pressed ? 1 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: ShapeDecoration(
            color: color,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Row(
            children: <Widget>[
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: active
                      ? accent.withValues(alpha: 0.10)
                      : ControlColors.well,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: SizedBox.square(
                  dimension: 31,
                  child: Icon(
                    icon,
                    size: 17,
                    color: active
                        ? context.hyprPalette.accentSoft
                        : ControlColors.textFaint,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: HyprTypography.compactMonoStrong.copyWith(
                        color: active
                            ? ControlColors.text
                            : ControlColors.textMuted,
                        fontSize: HyprTypography.size(10),
                        fontWeight: FontWeight.w700,
                        height: 1,
                        letterSpacing: 1.45,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shortcut,
                      style: HyprTypography.compactMono.copyWith(
                        color: ControlColors.textFaint,
                        fontSize: HyprTypography.size(8.5),
                        fontWeight: FontWeight.w500,
                        height: 1,
                        letterSpacing: 0.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
