import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';

class AppLauncherFooter extends StatelessWidget {
  const AppLauncherFooter({super.key, required this.resultCount});

  final int resultCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0x40000000), Color(0x73000000)],
        ),
        border: Border(top: BorderSide(color: HyprColors.popupStroke)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: <Widget>[
            Text(
              '$resultCount RESULT${resultCount == 1 ? '' : 'S'}',
              style: _footerStyle(),
            ),
            const Spacer(),
            const _FooterHint(keys: <String>['↑↓'], label: 'navigate'),
            const SizedBox(width: 10),
            const _FooterHint(keys: <String>['↵'], label: 'open'),
          ],
        ),
      ),
    );
  }

  static TextStyle _footerStyle({Color color = HyprColors.textFaint}) {
    return HyprTypography.compactMono.copyWith(
      color: color,
      fontSize: HyprTypography.size(10),
      letterSpacing: 1,
      fontWeight: FontWeight.w500,
      height: 1,
    );
  }
}

class _FooterHint extends StatelessWidget {
  const _FooterHint({required this.keys, required this.label});

  final List<String> keys;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final String key in keys) LauncherKeycap(label: key),
        const SizedBox(width: 4),
        Text(
          label,
          style: HyprTypography.compactMono.copyWith(
            color: HyprColors.textFaint,
            fontSize: HyprTypography.size(10),
            letterSpacing: 0.8,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class LauncherKeycap extends StatelessWidget {
  const LauncherKeycap({super.key, required this.label, this.primary = false});

  final String label;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: primary ? const Color(0x2616B7F4) : const Color(0x73000000),
        shape: RoundedSuperellipseBorder(
          borderRadius: HyprRadii.tagRadius,
          side: BorderSide(
            color: primary ? const Color(0x5916B7F4) : HyprColors.popupStroke,
          ),
        ),
      ),
      child: SizedBox(
        height: 17,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Center(
            child: Text(
              label,
              style: HyprTypography.compactMonoStrong.copyWith(
                color: primary
                    ? context.hyprPalette.accentSoft
                    : HyprColors.textMuted,
                fontSize: HyprTypography.size(9.5),
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
