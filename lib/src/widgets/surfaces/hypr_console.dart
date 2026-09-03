import 'package:flutter/material.dart';

import '../../theme/hypr_tokens.dart';
import 'hypr_colors.dart';
import 'hypr_console_colors.dart';
import 'hypr_popover_surface.dart';
import 'hypr_typography.dart';

/// How far a console face sinks while pressed.
const double kHyprConsolePressDepth = 1;

/// The translucent outer instrument shell shared by console-styled panels.
///
/// The gradient tint is composited *over* [surfaceColor] rather than replacing
/// it, so a console reads at the same baseline opacity as every other popover
/// instead of letting the wallpaper through its own chassis.
class HyprConsoleChassis extends StatelessWidget {
  const HyprConsoleChassis({
    super.key,
    required this.borderRadius,
    required this.constraints,
    required this.padding,
    required this.child,
    this.ramp = HyprChassisRamp.console,
    this.surfaceColor = HyprColors.popoverSurface,
    this.borderColor = HyprColors.popupStroke,
  });

  final BorderRadius borderRadius;
  final BoxConstraints constraints;
  final EdgeInsetsGeometry padding;
  final Widget child;
  final HyprChassisRamp ramp;
  final Color surfaceColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return HyprPopoverSurface(
      borderRadius: borderRadius,
      color: surfaceColor,
      borderColor: borderColor,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: ramp.gradient),
        child: ConstrainedBox(
          constraints: constraints,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A labelled bay recessed into a [HyprConsoleChassis].
class HyprConsoleTray extends StatelessWidget {
  const HyprConsoleTray({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const BorderRadius radius = HyprRadii.clockCardRadius;

    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: HyprConsoleColors.tray,
        shape: RoundedSuperellipseBorder(
          borderRadius: radius,
          side: BorderSide(color: HyprConsoleColors.trayBorder),
        ),
      ),
      child: ClipRSuperellipse(
        borderRadius: radius,
        child: Stack(
          children: <Widget>[
            const Positioned(
              top: HyprSpacing.hairline,
              left: HyprSpacing.roomy,
              right: HyprSpacing.roomy,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      Color(0x00FFFFFF),
                      HyprConsoleColors.trayHighlight,
                      Color(0x00FFFFFF),
                    ],
                  ),
                ),
                child: SizedBox(height: HyprSpacing.hairline),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 17, 17, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  HyprConsoleSectionLabel(label),
                  const SizedBox(height: HyprSpacing.section + 1),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An engraved heading with a hairline rule running out to the tray edge.
class HyprConsoleSectionLabel extends StatelessWidget {
  const HyprConsoleSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 13,
      child: Row(
        children: <Widget>[
          Text(label.toUpperCase(), style: HyprTypography.consoleSection),
          const SizedBox(width: HyprSpacing.section),
          const Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Color(0x003C3D43),
                    Color(0x993C3D43),
                    Color(0x003C3D43),
                  ],
                ),
              ),
              child: SizedBox(height: HyprSpacing.hairline),
            ),
          ),
        ],
      ),
    );
  }
}
