import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';

/// Whether a control can act, and if not, why.
///
/// The panel has exactly one story for "you cannot use this": the face dims,
/// it announces itself as unavailable, and it stays tappable purely so a tap
/// can surface [reason]. Both "not implemented yet" and "the backend said no"
/// go through here so they cannot drift apart.
@immutable
class ControlAvailability {
  const ControlAvailability.available() : reason = null;

  const ControlAvailability.unavailable(String this.reason);

  /// Null when the control is usable, otherwise the message to surface.
  final String? reason;

  bool get isAvailable => reason == null;

  /// Opacity applied to an unavailable face.
  static const double dimmed = 0.46;
}

/// Rest/hover/pressed resolution for a raised console face.
///
/// Disabled faces stay at [rest]: an unavailable control must never light up
/// as though it were about to do something.
Color controlFaceColor(
  HyprInteractionState state, {
  Color rest = HyprConsoleColors.tile,
  Color hover = HyprConsoleColors.tileHover,
  Color pressed = HyprConsoleColors.tilePressed,
}) {
  if (!state.enabled) {
    return rest;
  }
  if (state.pressed) {
    return pressed;
  }
  if (state.hovered) {
    return hover;
  }
  return rest;
}

/// The travel a console face makes while held.
Matrix4 controlPressTransform(HyprInteractionState state) =>
    Matrix4.translationValues(0, state.pressed ? kHyprConsolePressDepth : 0, 0);

/// A recessed face, lit from above like every other well in the console.
ShapeDecoration controlWellDecoration({
  BorderRadius borderRadius = HyprRadii.fieldRadius,
}) {
  return ShapeDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[HyprConsoleColors.wellTop, HyprConsoleColors.well],
    ),
    shape: RoundedSuperellipseBorder(borderRadius: borderRadius),
  );
}

/// The chord hint stamped onto a console face.
///
/// Chords come from user configuration, so the label must be free to shrink:
/// it ellipsises rather than forcing its parent row wider.
class ControlShortcutBadge extends StatelessWidget {
  const ControlShortcutBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: HyprConsoleColors.seam,
        shape: RoundedSuperellipseBorder(
          borderRadius: HyprRadii.badgeRadius,
          side: BorderSide(color: Color(0x66000000)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HyprSpacing.sm,
          vertical: HyprSpacing.xxs,
        ),
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
