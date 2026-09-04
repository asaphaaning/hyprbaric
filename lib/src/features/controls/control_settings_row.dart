import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'controls_chrome.dart';

class ControlSettingsRow extends StatelessWidget {
  const ControlSettingsRow({super.key, required this.onPressed, this.shortcut});

  final VoidCallback onPressed;

  /// The user's configured chord, or null when the binding is unknown or
  /// disabled.
  final String? shortcut;

  /// The row's fixed height, exposed so layout tests do not have to hardcode
  /// it as a magic number.
  static const double height = 62;

  @override
  Widget build(BuildContext context) {
    final String? chord = shortcut;

    return HyprInteractionRegion(
      semanticLabel: 'Bar settings',
      onPressed: onPressed,
      builder: (BuildContext context, HyprInteractionState state) {
        return SizedBox(
          height: height,
          child: DecoratedBox(
            key: const ValueKey<String>('control-settings-frame'),
            decoration: const ShapeDecoration(
              color: Color(0xFF24262A),
              shape: RoundedSuperellipseBorder(
                borderRadius: HyprRadii.tileRadius,
                side: BorderSide(color: HyprConsoleColors.seam),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(HyprSpacing.md),
              child: AnimatedContainer(
                key: const ValueKey<String>('control-settings-face'),
                duration: HyprMotion.hover,
                curve: HyprMotion.hoverCurve,
                transform: controlPressTransform(state),
                padding: const EdgeInsets.symmetric(
                  horizontal: HyprSpacing.section + HyprSpacing.hairline,
                ),
                decoration: ShapeDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: _faceColors(state),
                  ),
                  shadows: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x1AFFFFFF),
                      offset: Offset(0, 1),
                      blurStyle: BlurStyle.inner,
                    ),
                    BoxShadow(
                      color: Color(0x73000000),
                      offset: Offset(0, -1),
                      blurStyle: BlurStyle.inner,
                    ),
                  ],
                  shape: const RoundedSuperellipseBorder(
                    borderRadius: HyprRadii.fieldRadius,
                    side: BorderSide(color: Color(0x99000000)),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const DecoratedBox(
                      decoration: ShapeDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[Color(0xFF141519), Color(0xFF0D0E12)],
                        ),
                        shadows: <BoxShadow>[
                          BoxShadow(
                            color: Color(0xB8000000),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                          BoxShadow(
                            color: Color(0x12FFFFFF),
                            offset: Offset(0, 1),
                          ),
                        ],
                        shape: RoundedSuperellipseBorder(
                          borderRadius: HyprRadii.rowRadius,
                        ),
                      ),
                      child: SizedBox.square(
                        dimension: 31,
                        child: Icon(
                          Iconsax.setting_2_copy,
                          size: 16,
                          color: HyprConsoleColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: HyprSpacing.section + HyprSpacing.hairline,
                    ),
                    // Both the label and the chord flex: the chord is user
                    // configurable, so neither may force the row wider than
                    // the panel that contains it.
                    Flexible(
                      child: Text(
                        'BAR SETTINGS',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: HyprTypography.consoleCaption.copyWith(
                          color: HyprConsoleColors.text,
                          fontSize: HyprTypography.size(10.5),
                          letterSpacing: 1.25,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (chord != null) ...<Widget>[
                      Flexible(child: ControlShortcutBadge(chord)),
                      const SizedBox(width: HyprSpacing.xl),
                    ],
                    Text(
                      '›',
                      style: HyprTypography.compactMono.copyWith(
                        color: HyprConsoleColors.textFaint,
                        fontSize: HyprTypography.size(14),
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

List<Color> _faceColors(HyprInteractionState state) {
  if (state.pressed) {
    return const <Color>[Color(0xFF111216), Color(0xFF17181D)];
  }

  if (state.hovered) {
    return const <Color>[Color(0xFF27282E), Color(0xFF1B1C21)];
  }

  return const <Color>[Color(0xFF1C1F24), Color(0xFF0F1115)];
}
