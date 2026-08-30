import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'controls_chrome.dart';

class ControlSettingsRow extends StatelessWidget {
  const ControlSettingsRow({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return HyprInteractionRegion(
      semanticLabel: 'Bar settings',
      onPressed: onPressed,
      builder: (BuildContext context, HyprInteractionState state) {
        return SizedBox(
          height: 62,
          child: DecoratedBox(
            key: const ValueKey<String>('control-settings-frame'),
            decoration: ShapeDecoration(
              color: const Color(0xFF24262A),
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xA6000000)),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: AnimatedContainer(
                key: const ValueKey<String>('control-settings-face'),
                duration: HyprMotion.hover,
                curve: HyprMotion.hoverCurve,
                transform: Matrix4.translationValues(
                  0,
                  state.pressed ? 1 : 0,
                  0,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 13),
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
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0x99000000)),
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
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                      child: SizedBox.square(
                        dimension: 31,
                        child: Icon(
                          Iconsax.setting_2_copy,
                          size: 16,
                          color: ControlColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Text(
                      'BAR SETTINGS',
                      style: HyprTypography.compactMonoStrong.copyWith(
                        color: ControlColors.text,
                        fontSize: HyprTypography.size(10.5),
                        fontWeight: FontWeight.w700,
                        height: 1,
                        letterSpacing: 1.25,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '›',
                      style: HyprTypography.compactMono.copyWith(
                        color: ControlColors.textFaint,
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
