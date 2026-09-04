import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'controls_chrome.dart';

class ControlInspectButton extends StatelessWidget {
  const ControlInspectButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.shortcut,
    this.availability = const ControlAvailability.available(),
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// The user's configured chord, or null when the binding is unknown or
  /// disabled.
  final String? shortcut;

  final ControlAvailability availability;

  bool get enabled => availability.isAvailable;

  @override
  Widget build(BuildContext context) {
    return HyprInteractionRegion(
      semanticLabel: enabled ? label : '$label, unavailable',
      onPressed: onPressed,
      builder: (BuildContext context, HyprInteractionState rawState) {
        final HyprInteractionState state = HyprInteractionState(
          hovered: rawState.hovered,
          pressed: rawState.pressed,
          enabled: enabled && rawState.enabled,
        );
        final bool lit = state.enabled && state.active;

        return AnimatedContainer(
          duration: HyprMotion.hover,
          curve: HyprMotion.hoverCurve,
          height: 53,
          transform: controlPressTransform(state),
          padding: const EdgeInsets.symmetric(
            horizontal: HyprSpacing.xxl + HyprSpacing.hairline,
          ),
          decoration: ShapeDecoration(
            color: controlFaceColor(state),
            shape: const RoundedSuperellipseBorder(
              borderRadius: HyprRadii.fieldRadius,
            ),
          ),
          child: Opacity(
            opacity: enabled ? 1 : ControlAvailability.dimmed,
            child: Row(
              children: <Widget>[
                DecoratedBox(
                  decoration: const ShapeDecoration(
                    color: HyprConsoleColors.well,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: HyprRadii.rowRadius,
                    ),
                  ),
                  child: SizedBox.square(
                    dimension: 31,
                    child: Icon(
                      icon,
                      size: 17,
                      color: lit
                          ? HyprConsoleColors.textMuted
                          : HyprConsoleColors.textFaint,
                    ),
                  ),
                ),
                const SizedBox(width: HyprSpacing.xxl + HyprSpacing.hairline),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: HyprTypography.consoleCaption.copyWith(
                          color: lit
                              ? HyprConsoleColors.text
                              : HyprConsoleColors.textMuted,
                        ),
                      ),
                      if (shortcut case final String chord) ...<Widget>[
                        const SizedBox(height: HyprSpacing.sm),
                        Text(
                          chord,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: HyprTypography.consoleShortcut.copyWith(
                            fontSize: HyprTypography.size(8.5),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.35,
                          ),
                        ),
                      ],
                    ],
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
