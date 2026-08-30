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
        return AnimatedContainer(
          duration: HyprMotion.hover,
          curve: HyprMotion.hoverCurve,
          height: 62,
          transform: Matrix4.translationValues(0, state.pressed ? 1 : 0, 0),
          padding: const EdgeInsets.all(1),
          decoration: ShapeDecoration(
            color: const Color(0xD9000000),
            shadows: const <BoxShadow>[
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 9,
                offset: Offset(0, 4),
              ),
            ],
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: const Color(0xFF27292E),
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: const Color(0x99000000),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: AnimatedContainer(
                    duration: HyprMotion.hover,
                    curve: HyprMotion.hoverCurve,
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    decoration: ShapeDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: state.pressed
                            ? const <Color>[
                                Color(0xFF111216),
                                Color(0xFF17181D),
                              ]
                            : state.hovered
                            ? const <Color>[
                                Color(0xFF27282E),
                                Color(0xFF1B1C21),
                              ]
                            : const <Color>[
                                Color(0xFF1D1E23),
                                Color(0xFF141519),
                              ],
                      ),
                      shadows: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x1AFFFFFF),
                          offset: Offset(0, 1),
                        ),
                        BoxShadow(
                          color: Color(0x73000000),
                          offset: Offset(0, -1),
                        ),
                      ],
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        const DecoratedBox(
                          decoration: ShapeDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Color(0xFF141519),
                                Color(0xFF0D0E12),
                              ],
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
                              borderRadius: BorderRadius.all(
                                Radius.circular(8),
                              ),
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
            ),
          ),
        );
      },
    );
  }
}
