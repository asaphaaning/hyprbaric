import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';

class AppLauncherHeader extends StatelessWidget {
  const AppLauncherHeader({
    super.key,
    required this.queryController,
    required this.queryFocusNode,
    required this.onClose,
  });

  final TextEditingController queryController;
  final FocusNode queryFocusNode;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0x08FFFFFF), Color(0x00000000)],
        ),
        border: Border(bottom: BorderSide(color: HyprColors.popupStroke)),
      ),
      child: Stack(
        children: <Widget>[
          const Positioned(
            left: 14,
            right: 14,
            bottom: 0,
            child: _LauncherAccentSeam(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: <Widget>[
                const Icon(
                  Iconsax.search_normal_1_copy,
                  size: 16,
                  color: HyprColors.textFaint,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const ValueKey<String>('app-launcher-query'),
                    controller: queryController,
                    focusNode: queryFocusNode,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search apps…',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: HyprTypography.popRowStrong.copyWith(
                      fontSize: HyprTypography.size(16),
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.16,
                    ),
                    cursorColor: context.hyprPalette.accent,
                  ),
                ),
                const SizedBox(width: 10),
                HyprInteractiveTile(
                  semanticLabel: 'Close app launcher',
                  onPressed: onClose,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  borderRadius: HyprRadii.badgeRadius,
                  color: const Color(0x59000000),
                  hoverColor: HyprColors.hover,
                  borderColor: HyprColors.popupStroke,
                  hoverBorderColor: HyprColors.borderSoft,
                  pressedScale: 0.98,
                  builder:
                      (BuildContext context, HyprInteractiveTileState state) {
                        return Text(
                          'ESC',
                          style: HyprTypography.compactMonoStrong.copyWith(
                            color: state.hovered
                                ? HyprColors.textMuted
                                : HyprColors.textFaint,
                            fontSize: HyprTypography.size(9.5),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.95,
                            height: 1,
                          ),
                        );
                      },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LauncherAccentSeam extends StatelessWidget {
  const _LauncherAccentSeam();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Color(0x00000000),
            Color(0x7F16B7F4),
            Color(0x00000000),
          ],
        ),
      ),
      child: SizedBox(height: 1),
    );
  }
}

class LauncherErrorStrip extends StatelessWidget {
  const LauncherErrorStrip({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: HyprColors.dangerHoverSoft,
        border: Border(bottom: BorderSide(color: Color(0x40E16658))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: <Widget>[
            const Icon(
              Iconsax.info_circle_copy,
              size: 14,
              color: HyprColors.danger,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: HyprTypography.popRow.copyWith(
                  color: HyprColors.danger,
                  fontSize: HyprTypography.size(12),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
