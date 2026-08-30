import 'package:flutter/material.dart';

import '../hypr_surface.dart';

class HyprTextFieldChrome extends StatelessWidget {
  const HyprTextFieldChrome({
    super.key,
    required this.child,
    this.focusNode,
    this.padding = HyprSpacing.textField,
    this.borderRadius = HyprRadii.fieldRadius,
    this.color = HyprColors.fill,
    this.focusedColor,
    this.borderColor = HyprColors.borderSoft,
    this.focusedBorderColor,
    this.disabledBorderColor,
    this.enabled = true,
    this.constraints,
    this.clipBehavior = Clip.antiAlias,
    this.shadows,
    this.focusedShadows,
  });

  final Widget child;
  final FocusNode? focusNode;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color color;
  final Color? focusedColor;
  final Color borderColor;
  final Color? focusedBorderColor;
  final Color? disabledBorderColor;
  final bool enabled;
  final BoxConstraints? constraints;
  final Clip clipBehavior;

  /// Outer rings drawn around the field, e.g. a focus halo.
  final List<BoxShadow>? shadows;
  final List<BoxShadow>? focusedShadows;

  @override
  Widget build(BuildContext context) {
    final FocusNode? node = focusNode;
    if (node == null) {
      return _buildChrome(context, focused: false);
    }

    return ListenableBuilder(
      listenable: node,
      builder: (BuildContext context, Widget? child) {
        return _buildChrome(context, focused: enabled && node.hasFocus);
      },
    );
  }

  Widget _buildChrome(BuildContext context, {required bool focused}) {
    final Color effectiveFill = focused ? focusedColor ?? color : color;
    final Color effectiveBorder = enabled
        ? (focused
              ? focusedBorderColor ?? context.hyprPalette.accent
              : borderColor)
        : disabledBorderColor ?? borderColor.withValues(alpha: 0.55);

    return AnimatedContainer(
      duration: HyprMotion.hover,
      curve: HyprMotion.hoverCurve,
      constraints: constraints,
      padding: padding,
      decoration: ShapeDecoration(
        color: effectiveFill,
        shape: RoundedSuperellipseBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: effectiveBorder),
        ),
        shadows: focused ? focusedShadows ?? shadows : shadows,
      ),
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}
