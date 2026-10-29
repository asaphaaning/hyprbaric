import 'package:flutter/material.dart';

import '../hypr_surface.dart';

class HyprToggleSwitch extends StatelessWidget {
  const HyprToggleSwitch({
    super.key,
    required this.value,
    this.width = 26,
    this.height = 14,
    this.padding = HyprSpacing.hairlineInset,
    this.thumbSize = 10,
    this.trackColor = const Color(0xFF252C36),
    this.activeTrackColor,
    this.borderColor = const Color(0xFF3B4652),
    this.activeBorderColor,
    this.thumbColor = const Color(0xC8BEC7D0),
    this.activeThumbColor = const Color(0xFFE8F5FF),
    this.borderRadius = HyprRadii.pillRadius,
    this.activeShadow,
    this.inactiveShadow,
    this.duration = HyprMotion.switcher,
    this.curve = HyprMotion.switchInCurve,
  });

  final bool value;
  final double width;
  final double height;
  final EdgeInsetsGeometry padding;
  final double thumbSize;
  final Color trackColor;
  final Color? activeTrackColor;
  final Color borderColor;
  final Color? activeBorderColor;
  final Color thumbColor;
  final Color activeThumbColor;
  final BorderRadius borderRadius;
  final List<BoxShadow>? activeShadow;
  final List<BoxShadow>? inactiveShadow;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.hyprPalette.accent;
    return AnimatedContainer(
      duration: duration,
      curve: curve,
      width: width,
      height: height,
      padding: padding,
      decoration: ShapeDecoration(
        color: value
            ? activeTrackColor ?? accent.withValues(alpha: 0.40)
            : trackColor,
        shadows: value ? activeShadow : inactiveShadow,
        shape: RoundedSuperellipseBorder(
          borderRadius: borderRadius,
          side: BorderSide(
            color: value ? activeBorderColor ?? accent : borderColor,
          ),
        ),
      ),
      child: AnimatedAlign(
        duration: HyprMotion.knob,
        curve: HyprMotion.knobCurve,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: value ? activeThumbColor : thumbColor,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(dimension: thumbSize),
        ),
      ),
    );
  }
}
