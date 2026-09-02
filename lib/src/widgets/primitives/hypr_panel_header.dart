import 'package:flutter/material.dart';

import '../hypr_surface.dart';

class HyprPanelHeader extends StatelessWidget {
  const HyprPanelHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.titleTrailing,
    this.trailing,
    this.actionLabel,
    this.onAction,
    this.actionEnabled = true,
    this.actionKey,
    this.uppercaseTitle = false,
    this.leadingGap = HyprSpacing.xl,
    this.titleTrailingGap = HyprSpacing.xl,
    this.trailingGap = HyprSpacing.xxl,
    this.actionGap = HyprSpacing.xxl,
    this.subtitleGap = HyprSpacing.xs,
    this.titleStyle,
    this.subtitleStyle,
    this.actionStyle,
    this.titleColor,
    this.subtitleColor = HyprColors.textFaint,
    this.actionColor = HyprColors.textFaint,
    this.actionDisabledColor,
    this.titleMaxLines = 1,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? titleTrailing;
  final Widget? trailing;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool actionEnabled;
  final Key? actionKey;
  final bool uppercaseTitle;
  final double leadingGap;
  final double titleTrailingGap;
  final double trailingGap;
  final double actionGap;
  final double subtitleGap;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final TextStyle? actionStyle;
  final Color? titleColor;
  final Color subtitleColor;
  final Color actionColor;
  final Color? actionDisabledColor;
  final int titleMaxLines;

  @override
  Widget build(BuildContext context) {
    final Widget titleText = Text(
      uppercaseTitle ? title.toUpperCase() : title,
      maxLines: titleMaxLines,
      overflow: TextOverflow.ellipsis,
      style: (titleStyle ?? HyprTypography.popTitle).copyWith(
        color: titleColor,
      ),
    );

    return Row(
      children: <Widget>[
        if (leading != null) ...<Widget>[leading!, SizedBox(width: leadingGap)],
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(child: titleText),
                  if (titleTrailing != null) ...<Widget>[
                    SizedBox(width: titleTrailingGap),
                    titleTrailing!,
                  ],
                ],
              ),
              if (subtitle != null) ...<Widget>[
                SizedBox(height: subtitleGap),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (subtitleStyle ?? HyprTypography.popRow).copyWith(
                    color: subtitleColor,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          SizedBox(width: trailingGap),
          trailing!,
        ],
        if (actionLabel != null) ...<Widget>[
          SizedBox(width: actionGap),
          // An action that cannot shrink overflows any panel narrow enough,
          // or any text scale large enough, to run out of room for it.
          Flexible(
            child: _HyprPanelHeaderAction(
              key: actionKey,
              label: actionLabel!,
              enabled: actionEnabled && onAction != null,
              onPressed: onAction,
              style: actionStyle,
              color: actionColor,
              disabledColor:
                  actionDisabledColor ?? actionColor.withValues(alpha: 0.45),
            ),
          ),
        ],
      ],
    );
  }
}

class _HyprPanelHeaderAction extends StatelessWidget {
  const _HyprPanelHeaderAction({
    super.key,
    required this.label,
    required this.enabled,
    required this.onPressed,
    required this.color,
    required this.disabledColor,
    this.style,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onPressed;
  final Color color;
  final Color disabledColor;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(HyprRadii.badge),
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HyprSpacing.xxs,
          vertical: HyprSpacing.sm,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (style ?? HyprTypography.compactMono).copyWith(
            color: enabled ? color : disabledColor,
          ),
        ),
      ),
    );
  }
}
