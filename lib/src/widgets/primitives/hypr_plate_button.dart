import 'package:flutter/material.dart';

import '../../theme/hypr_motion.dart';
import '../surfaces/hypr_console_colors.dart';
import '../surfaces/hypr_typography.dart';
import 'hypr_interaction_region.dart';

/// Transport-key plate: a dimensional face sunk into a thick flat gasket.
///
/// Shared by the controls and network popovers, which use the same
/// `.bar-settings-row` / `.plate-btn` treatment in the reference design.
class HyprPlateButton extends StatelessWidget {
  const HyprPlateButton({
    super.key,
    required this.label,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    required this.labelColor,
    required this.iconColor,
    required this.trailingColor,
    this.shortcut,
    this.frameKey,
    this.faceKey,
  });

  /// The plate's fixed height, exposed so layout tests do not have to
  /// hardcode it as a magic number.
  static const double height = 60;

  final String label;
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;
  final Color labelColor;
  final Color iconColor;
  final Color trailingColor;

  /// An optional chord hint stamped between the label and the chevron. Null
  /// when no binding is known: a guessed chord is worse than none at all.
  final String? shortcut;

  final Key? frameKey;
  final Key? faceKey;

  @override
  Widget build(BuildContext context) {
    return HyprInteractionRegion(
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      builder: (BuildContext context, HyprInteractionState state) {
        return SizedBox(
          height: height,
          child: DecoratedBox(
            key: frameKey,
            decoration: const ShapeDecoration(
              color: HyprPlateFace.ring,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.all(Radius.circular(15)),
                side: BorderSide(color: Color(0x99000000)),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: AnimatedContainer(
                key: faceKey,
                duration: HyprMotion.hover,
                curve: HyprMotion.hoverCurve,
                transform: Matrix4.translationValues(
                  0,
                  state.pressed ? 1 : 0,
                  0,
                ),
                clipBehavior: Clip.antiAlias,
                decoration: ShapeDecoration(
                  gradient: _faceGradient(state),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0x99000000)),
                  ),
                ),
                child: Stack(
                  // Non-positioned children default to topStart, which would
                  // pin the row to the face's top edge.
                  alignment: Alignment.center,
                  children: <Widget>[
                    if (!state.pressed)
                      const Positioned(
                        top: 1,
                        left: 4,
                        right: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                Colors.transparent,
                                HyprPlateFace.rimLight,
                                HyprPlateFace.rimLight,
                                Colors.transparent,
                              ],
                              stops: <double>[0, 0.1, 0.9, 1],
                            ),
                          ),
                          child: SizedBox(height: 1),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      child: Row(
                        children: <Widget>[
                          DecoratedBox(
                            decoration: const ShapeDecoration(
                              // Reads as a recess punched into the face, so it
                              // must stay darker than the face's darkest band.
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  HyprPlateFace.recessTop,
                                  HyprPlateFace.recessBottom,
                                ],
                              ),
                              shadows: <BoxShadow>[
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
                              dimension: 27,
                              child: Icon(icon, size: 14, color: iconColor),
                            ),
                          ),
                          const SizedBox(width: 13),
                          // Both the label and the chord flex: the chord is
                          // user configurable, so neither may force the row
                          // wider than the plate that contains it.
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: HyprTypography.compactMonoStrong.copyWith(
                                color: labelColor,
                                fontSize: HyprTypography.size(10.5),
                                fontWeight: FontWeight.w700,
                                height: 1,
                                letterSpacing: 1.25,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (shortcut case final String chord) ...<Widget>[
                            Flexible(child: _ShortcutBadge(chord)),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            '›',
                            style: HyprTypography.compactMono.copyWith(
                              color: trailingColor,
                              fontSize: HyprTypography.size(14),
                              height: 1,
                            ),
                          ),
                        ],
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

/// The bottom shade is baked into the gradient rather than drawn with
/// `BlurStyle.inner` shadows: Flutter's inner shadows offset the wrong way
/// here, which inverted the reference's lit-top / shaded-bottom rim. The top
/// rim light is a real hairline in the stack above, since a gradient band was
/// swallowed by the face's own 1px border.
LinearGradient _faceGradient(HyprInteractionState state) {
  if (state.pressed) {
    return HyprPlateFace.pressed.gradient;
  }
  if (state.hovered) {
    return HyprPlateFace.hovered.gradient;
  }
  return HyprPlateFace.idle.gradient;
}

/// The chord hint stamped onto a plate.
class _ShortcutBadge extends StatelessWidget {
  const _ShortcutBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: HyprConsoleColors.seam,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          side: BorderSide(color: Color(0x66000000)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: HyprTypography.consoleShortcut,
        ),
      ),
    );
  }
}
