import 'package:flutter/widgets.dart';

/// The instrument ramp shared by Hyprbaric's console-styled surfaces.
///
/// These are machined-metal greys rather than semantic UI colours, which is
/// why they live apart from [HyprColors]. Anything that renders inside a
/// [HyprConsoleChassis] should pull its greys from here so the controls panel
/// and the audio mixer stay lit by the same imaginary light source.
abstract final class HyprConsoleColors {
  static const Color chassisTop = Color(0x570B0D12);
  static const Color chassisBottom = Color(0x6B07090D);

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
