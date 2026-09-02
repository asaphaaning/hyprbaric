import 'package:flutter/widgets.dart';

import 'hypr_colors.dart';

/// The instrument ramp shared by Hyprbaric's console-styled surfaces.
///
/// These are machined-metal greys rather than semantic UI colours, which is
/// why they live apart from [HyprColors]. Anything that renders inside a
/// console panel should pull its greys from here so the controls panel and
/// the audio mixer stay lit by the same imaginary light source.
abstract final class HyprConsoleColors {
  static const Color tray = Color(0xFF121216);
  static const Color trayBorder = Color(0x182E3036);
  static const Color trayHighlight = Color(0x10FFFFFF);

  /// Raised faces sitting directly on a [tray].
  static const Color tile = Color(0xFF17171C);
  static const Color tileHover = Color(0xFF202027);
  static const Color tilePressed = Color(0xFF111116);

  /// Recessed faces nested inside a [tile], lit from above.
  static const Color wellTop = Color(0xFF101014);
  static const Color well = Color(0xFF0D0D0F);

  /// Raised faces nested inside a well, one step darker than [tile].
  static const Color face = Color(0xFF131318);
  static const Color faceHover = Color(0xFF1C1C23);
  static const Color facePressed = Color(0xFF0D0D12);

  /// Hairline that separates a machined face from its surround.
  static const Color seam = Color(0xA6000000);

  static const Color label = Color(0xFF666870);
  static const Color text = Color(0xFFB0B1B7);
  static const Color textMuted = Color(0xFF898B93);
  static const Color textFaint = Color(0xFF555760);
}

/// The vertical tint one instrument shell is lit with.
///
/// Every console-styled popover paints the same shape: a two-stop vertical
/// wash over a translucent popover surface. Each surface used to declare its
/// own pair of colours next to its own `LinearGradient`, under the same
/// `chassisTop` and `chassisBottom` names but with values an order of
/// magnitude apart in alpha, which made them read as interchangeable when
/// they are not. Naming the ramps here keeps the differences deliberate and
/// leaves one implementation of the gradient itself.
@immutable
class HyprChassisRamp {
  const HyprChassisRamp({required this.top, required this.bottom});

  /// The default shell, composited over [HyprColors.popoverSurface].
  static const HyprChassisRamp console = HyprChassisRamp(
    top: Color(0x570B0D12),
    bottom: Color(0x6B07090D),
  );

  /// The audio mixer's shell: warmer and close to opaque.
  static const HyprChassisRamp mixer = HyprChassisRamp(
    top: Color(0xF0161A20),
    bottom: Color(0xFA0E1218),
  );

  /// The notification centre's shell, lighter than the instrument panels.
  static const HyprChassisRamp notifications = HyprChassisRamp(
    top: Color(0x800E1015),
    bottom: Color(0x8F090C10),
  );

  final Color top;
  final Color bottom;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[top, bottom],
  );
}

/// One lit state of a transport-key plate face.
///
/// The plate declared these ramps as private constants beside its own three
/// `LinearGradient` literals, a single import away from the instrument greys
/// every other console face is lit by. Keeping them here puts the whole
/// machined ramp in one file and leaves one implementation of the gradient.
@immutable
class HyprPlateFace {
  const HyprPlateFace({
    required this.top,
    required this.middle,
    required this.bottom,
    required this.middleStop,
  });

  /// At rest: lit along the top, shading into the gasket at the bottom.
  static const HyprPlateFace idle = HyprPlateFace(
    top: Color(0xFF1C1F24),
    middle: Color(0xFF0E1116),
    bottom: Color(0xFF08090C),
    middleStop: 0.955,
  );

  /// Under the pointer, with the top band opened up.
  static const HyprPlateFace hovered = HyprPlateFace(
    top: Color(0xFF25282D),
    middle: Color(0xFF15171C),
    bottom: Color(0xFF0C0D0F),
    middleStop: 0.955,
  );

  /// Pressed reads as a well, so the shade moves to the top of the face.
  static const HyprPlateFace pressed = HyprPlateFace(
    top: Color(0xFF08080A),
    middle: Color(0xFF111216),
    bottom: Color(0xFF17181D),
    middleStop: 0.1,
  );

  /// The flat gasket the face is sunk into: one solid slab, no bezel.
  static const Color ring = Color(0xFF16181D);

  /// The hairline just inside the face's top border.
  static const Color rimLight = Color(0x1AFFFFFF);

  /// The recess an icon is punched into, darker than the face's darkest band.
  static const Color recessTop = Color(0xFF090B0F);
  static const Color recessBottom = Color(0xFF040508);

  final Color top;
  final Color middle;
  final Color bottom;
  final double middleStop;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[top, middle, bottom],
    stops: <double>[0, middleStop, 1],
  );
}
