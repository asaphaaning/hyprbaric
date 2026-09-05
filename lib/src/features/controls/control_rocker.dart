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
    this.availability = const ControlAvailability.available(),
  });

  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ControlAvailability availability;

  bool get enabled => availability.isAvailable;

  @override
  Widget build(BuildContext context) {
    // Unavailable rockers stay tappable so a tap can surface the reason, but
    // they must not read as on: `value` is whatever the backend last knew.
    final bool lit = value && enabled;

    return HyprInteractionRegion(
      semanticLabel: enabled ? label : '$label, unavailable',
      semanticToggled: lit,
      onPressed: () => onChanged(!value),
      builder: (BuildContext context, HyprInteractionState rawState) {
        final HyprInteractionState state = HyprInteractionState(
          hovered: rawState.hovered,
          pressed: rawState.pressed,
          enabled: enabled && rawState.enabled,
        );
        final Color accent = context.hyprPalette.accent;
        final Color rest = lit
            ? Color.alphaBlend(
                accent.withValues(alpha: 0.12),
                HyprConsoleColors.face,
              )
            : HyprConsoleColors.face;
        final Color color = controlFaceColor(
          state,
          rest: rest,
          hover: HyprConsoleColors.faceHover,
          pressed: HyprConsoleColors.facePressed,
        );

        return AnimatedContainer(
          duration: HyprMotion.hover,
          curve: HyprMotion.hoverCurve,
          transform: controlPressTransform(state),
          padding: const EdgeInsets.fromLTRB(
            HyprSpacing.md,
            HyprSpacing.panel - HyprSpacing.md,
            HyprSpacing.md,
            HyprSpacing.xl,
          ),
          decoration: ShapeDecoration(
            color: color,
            shape: const RoundedSuperellipseBorder(
              borderRadius: HyprRadii.fieldRadius,
            ),
          ),
          child: Opacity(
            opacity: enabled ? 1 : ControlAvailability.dimmed,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  size: 21,
                  color: lit
                      ? context.hyprPalette.accentSoft
                      : HyprConsoleColors.textFaint,
                ),
                const SizedBox(height: HyprSpacing.xl),
                _RockerSwitch(value: value, enabled: enabled),
                const SizedBox(height: HyprSpacing.xl),
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.center,
                  style: HyprTypography.consoleCaptionTight.copyWith(
                    color: lit
                        ? HyprConsoleColors.text
                        : HyprConsoleColors.textFaint,
                    fontSize: HyprTypography.size(8),
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
      width: 50,
      height: 18,
      padding: const EdgeInsets.all(1.5),
      decoration: ShapeDecoration(
        // Flat, not graded: the reference well is one even tone, and a
        // vertical falloff here dulled the lit tint by the bottom edge.
        color: value
            ? accent.withValues(alpha: enabled ? 0.32 : 0.16)
            : const Color(0xFF101116),
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
          width: 19,
          height: 15,
          decoration: ShapeDecoration(
            // The cap is a solid moulded key, not a metallic barrel: the
            // three-stop gradient this used to carry shaded the bottom two
            // thirds so far down that the unlit cap read charcoal instead of
            // light grey. The drop shadow below supplies the dimension.
            color: value
                ? Color.lerp(accent, Colors.white, 0.44)!
                : const Color(0xFFABADB1),
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
