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
        const Color accent = HyprAmberToggle.amber;
        final Color rest = lit
            ? Color.alphaBlend(
                accent.withValues(alpha: 0.045),
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
                      ? HyprAmberToggle.amber
                      : HyprConsoleColors.textFaint,
                ),
                const SizedBox(height: 4),
                HyprAmberToggle(
                  key: const ValueKey<String>('control-rocker-switch'),
                  value: lit,
                ),
                const SizedBox(height: 4),
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.center,
                  style: HyprTypography.consoleCaptionTight.copyWith(
                    color: lit
                        ? HyprConsoleColors.text
                        : HyprConsoleColors.textFaint,
                    fontSize: HyprTypography.size(11.5),
                    letterSpacing: .5,
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
