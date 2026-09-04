import 'package:flutter/material.dart';

import '../hypr_surface.dart';

class HyprEmptyState extends StatelessWidget {
  const HyprEmptyState({
    super.key,
    required this.message,
    this.subtitle,
    this.symbol,
    this.padding = HyprSpacing.emptyState,
    this.textAlign = TextAlign.center,
    this.messageStyle,
    this.subtitleStyle,
    this.symbolStyle,
    this.messageTransform,
    this.color = Colors.transparent,
    this.borderColor,
    this.borderRadius = HyprRadii.panelRadius,
    this.symbolGap = HyprSpacing.xl,
    this.subtitleGap = HyprSpacing.md,
  });

  final String message;
  final String? subtitle;
  final String? symbol;
  final EdgeInsetsGeometry padding;
  final TextAlign textAlign;
  final TextStyle? messageStyle;
  final TextStyle? subtitleStyle;
  final TextStyle? symbolStyle;
  final String Function(String message)? messageTransform;
  final Color color;
  final Color? borderColor;
  final BorderRadius borderRadius;
  final double symbolGap;
  final double subtitleGap;

  @override
  Widget build(BuildContext context) {
    final String effectiveMessage = messageTransform?.call(message) ?? message;
    final Widget content = Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (symbol != null) ...<Widget>[
            Text(
              symbol!,
              textAlign: TextAlign.center,
              style: symbolStyle ?? HyprTypography.compactMono,
            ),
            SizedBox(height: symbolGap),
          ],
          Text(
            effectiveMessage,
            textAlign: textAlign,
            style: messageStyle ?? HyprTypography.popRow,
          ),
          if (subtitle != null) ...<Widget>[
            SizedBox(height: subtitleGap),
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: textAlign,
              style: subtitleStyle ?? HyprTypography.compactMono,
            ),
          ],
        ],
      ),
    );

    final Color? stroke = borderColor;
    if (stroke == null && color == Colors.transparent) {
      return content;
    }

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: color,
        shape: RoundedSuperellipseBorder(
          borderRadius: borderRadius,
          side: stroke == null ? BorderSide.none : BorderSide(color: stroke),
        ),
      ),
      child: content,
    );
  }
}
