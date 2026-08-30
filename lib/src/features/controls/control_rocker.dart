import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'controls_chrome.dart';

class ControlRocker extends StatelessWidget {
  const ControlRocker({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return HyprInteractionRegion(
      semanticLabel: label,
      enabled: enabled,
      onPressed: () => onChanged(!value),
      builder: (BuildContext context, HyprInteractionState state) {
        final Color accent = context.hyprPalette.accent;
        final Color color = value
            ? Color.alphaBlend(
                accent.withValues(alpha: 0.12),
                const Color(0xFF131318),
              )
            : state.pressed
            ? ControlColors.tilePressed
            : state.hovered
            ? ControlColors.tileHover
            : const Color(0xFF131318);

        return AnimatedContainer(
          duration: HyprMotion.hover,
          curve: HyprMotion.hoverCurve,
          transform: Matrix4.translationValues(0, state.pressed ? 1 : 0, 0),
          padding: const EdgeInsets.fromLTRB(5, 9, 5, 8),
          decoration: ShapeDecoration(
            color: color,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Opacity(
            opacity: enabled ? 1 : 0.46,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  size: 21,
                  color: value
                      ? context.hyprPalette.accentSoft
                      : ControlColors.textFaint,
                ),
                const SizedBox(height: 8),
                _RockerSwitch(value: value, enabled: enabled),
                const SizedBox(height: 8),
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.center,
                  style: HyprTypography.compactMonoStrong.copyWith(
                    color: value ? ControlColors.text : ControlColors.textFaint,
                    fontSize: HyprTypography.size(8),
                    fontWeight: FontWeight.w700,
                    height: 1,
                    letterSpacing: 1.05,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RockerSwitch extends StatelessWidget {
  const _RockerSwitch({required this.value, required this.enabled});

  final bool value;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.hyprPalette.accent;

    return AnimatedContainer(
      duration: HyprMotion.switcher,
      curve: HyprMotion.switchInCurve,
      width: 36,
      height: 18,
      padding: const EdgeInsets.all(1.5),
      decoration: ShapeDecoration(
        gradient: value
            ? LinearGradient(
                colors: <Color>[
                  accent.withValues(alpha: enabled ? 0.38 : 0.18),
                  accent.withValues(alpha: enabled ? 0.22 : 0.12),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF101116), Color(0xFF08090D)],
              ),
        shadows: <BoxShadow>[
          const BoxShadow(
            color: Color(0xC8000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
          if (value && enabled)
            BoxShadow(
              color: accent.withValues(alpha: 0.38),
              blurRadius: 10,
              spreadRadius: -2,
            ),
        ],
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(7),
          side: const BorderSide(color: Color(0x66000000)),
        ),
      ),
      child: AnimatedAlign(
        duration: HyprMotion.switcher,
        curve: HyprMotion.switchInCurve,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 16,
          height: 15,
          decoration: ShapeDecoration(
            gradient: value
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color.lerp(accent, Colors.white, 0.44)!,
                      Color.lerp(accent, Colors.white, 0.12)!,
                      Color.lerp(accent, Colors.black, 0.14)!,
                    ],
                    stops: const <double>[0, 0.5, 1],
                  )
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0xFFABADB1),
                      Color(0xFF74767C),
                      Color(0xFF4A4C51),
                    ],
                    stops: <double>[0, 0.5, 1],
                  ),
            shadows: <BoxShadow>[
              const BoxShadow(
                color: Color(0xB8000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
              if (value && enabled)
                BoxShadow(color: accent.withValues(alpha: 0.52), blurRadius: 8),
            ],
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }
}
