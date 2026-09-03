import 'package:flutter/material.dart';

import '../hypr_surface.dart';
import 'hypr_interactive_tile.dart';

enum HyprCommandButtonVariant { quiet, primary, danger }

class HyprCommandButton extends StatelessWidget {
  const HyprCommandButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = HyprCommandButtonVariant.quiet,
    this.icon,
    this.padding = HyprSpacing.commandButton,
    this.constraints = const BoxConstraints(minHeight: 34),
    this.borderRadius = HyprRadii.rowRadius,
    this.textStyle,
    this.textAlign = TextAlign.center,
    this.maxLines = 2,
    this.enabled = true,
    this.color,
    this.hoverColor,
    this.pressedColor,
    this.disabledOpacity = 1,
    this.foregroundColor,
    this.hoverForegroundColor,
    this.borderColor,
    this.hoverBorderColor,
    this.iconGap = HyprSpacing.lg,
    this.shadowsBuilder,
    this.pressedScale = 0.94,
  });

  final String label;
  final VoidCallback? onPressed;
  final HyprCommandButtonVariant variant;
  final Widget? icon;
  final EdgeInsetsGeometry padding;
  final BoxConstraints constraints;
  final BorderRadius borderRadius;
  final TextStyle? textStyle;
  final TextAlign textAlign;
  final int maxLines;
  final bool enabled;
  final Color? color;
  final Color? hoverColor;

  /// Fill while the pointer is held down. Falls back to the hover fill.
  final Color? pressedColor;

  /// Opacity applied while the button is not interactive.
  final double disabledOpacity;
  final Color? foregroundColor;
  final Color? hoverForegroundColor;
  final Color? borderColor;
  final Color? hoverBorderColor;
  final double iconGap;
  final HyprInteractiveShadowBuilder? shadowsBuilder;
  final double pressedScale;

  @override
  Widget build(BuildContext context) {
    final _CommandButtonColors colors = _CommandButtonColors.resolve(
      variant,
      color: color,
      hoverColor: hoverColor,
      foregroundColor: foregroundColor,
      hoverForegroundColor: hoverForegroundColor,
      borderColor: borderColor,
      hoverBorderColor: hoverBorderColor,
    );

    return HyprInteractiveTile(
      semanticLabel: label,
      onPressed: onPressed,
      enabled: enabled,
      pressedColor: pressedColor,
      disabledOpacity: disabledOpacity,
      shadowsBuilder: shadowsBuilder,
      pressedScale: pressedScale,
      padding: padding,
      constraints: constraints,
      borderRadius: borderRadius,
      color: colors.fill,
      hoverColor: colors.hoverFill,
      selectedColor: colors.hoverFill,
      borderColor: colors.border,
      hoverBorderColor: colors.hoverBorder,
      selectedBorderColor: colors.hoverBorder,
      builder: (BuildContext context, HyprInteractiveTileState state) {
        final Color foreground = state.hovered
            ? colors.hoverForeground
            : colors.foreground;
        final TextStyle style = (textStyle ?? HyprTypography.popRow).copyWith(
          color: foreground,
          height: 1.15,
        );

        final Widget labelWidget = Text(
          label,
          softWrap: true,
          maxLines: maxLines,
          overflow: TextOverflow.visible,
          textAlign: textAlign,
          style: style,
        );

        final Widget? iconWidget = icon;
        if (iconWidget == null) {
          return Center(child: labelWidget);
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconTheme.merge(
              data: IconThemeData(color: foreground),
              child: iconWidget,
            ),
            SizedBox(width: iconGap),
            labelWidget,
          ],
        );
      },
    );
  }
}

@immutable
class _CommandButtonColors {
  const _CommandButtonColors({
    required this.fill,
    required this.hoverFill,
    required this.foreground,
    required this.hoverForeground,
    required this.border,
    required this.hoverBorder,
  });

  final Color fill;
  final Color hoverFill;
  final Color foreground;
  final Color hoverForeground;
  final Color border;
  final Color hoverBorder;

  factory _CommandButtonColors.resolve(
    HyprCommandButtonVariant variant, {
    Color? color,
    Color? hoverColor,
    Color? foregroundColor,
    Color? hoverForegroundColor,
    Color? borderColor,
    Color? hoverBorderColor,
  }) {
    final _CommandButtonColors defaults = switch (variant) {
      HyprCommandButtonVariant.quiet => const _CommandButtonColors(
        fill: Colors.transparent,
        hoverFill: HyprColors.hover,
        foreground: HyprColors.textMuted,
        hoverForeground: HyprColors.text,
        border: Colors.transparent,
        hoverBorder: Colors.transparent,
      ),
      HyprCommandButtonVariant.primary => const _CommandButtonColors(
        fill: Color(0x3324B8FF),
        hoverFill: Color(0x5530C8FF),
        foreground: HyprColors.text,
        hoverForeground: HyprColors.text,
        border: Color(0x6630C8FF),
        hoverBorder: Color(0xAA55D6FF),
      ),
      HyprCommandButtonVariant.danger => const _CommandButtonColors(
        fill: HyprColors.dangerHoverSoft,
        hoverFill: HyprColors.dangerHover,
        foreground: HyprColors.text,
        hoverForeground: HyprColors.text,
        border: Colors.transparent,
        hoverBorder: Color(0x66E16658),
      ),
    };

    return _CommandButtonColors(
      fill: color ?? defaults.fill,
      hoverFill: hoverColor ?? defaults.hoverFill,
      foreground: foregroundColor ?? defaults.foreground,
      hoverForeground: hoverForegroundColor ?? defaults.hoverForeground,
      border: borderColor ?? defaults.border,
      hoverBorder: hoverBorderColor ?? defaults.hoverBorder,
    );
  }
}
