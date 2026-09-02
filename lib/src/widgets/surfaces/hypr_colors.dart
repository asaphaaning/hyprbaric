import 'package:flutter/material.dart';

abstract final class HyprColors {
  static const Color surface = Color(0xB80A1118);
  static const Color surfaceStrong = Color(0xC4071018);
  static const Color popoverSurface = Color(0xE6071018);
  static const Color surfaceSoft = Color(0xB80F1A22);
  static const Color fill = Color(0x101E9BCF);
  static const Color hover = Color(0x0FFFFFFF);
  static const Color hoverStrong = Color(0x14FFFFFF);
  static const Color fillStrong = Color(0x291E9BCF);
  static const Color borderOuter = Color(0x84030A10);
  static const Color border = Color(0x52B4D8E8);
  static const Color borderSoft = Color(0x34B4D8E8);
  static const Color popupStroke = Color(0x14FFFFFF);
  static const Color popupOuterRing = Color(0x66000000);
  static const Color inset = Color(0x36D8F4FF);
  static const Color insetSoft = Color(0x1856C4E2);
  static const Color insetBottom = Color(0x24D8F4FF);
  static const Color popupInset = Color(0x0DFFFFFF);
  static const Color shadow = Color(0x8A000000);

  // Recessed housings for readouts and status chips.
  static const Color well = Color(0xD907090C);
  static const Color wellBorder = Color(0x4D000000);
  static const Color wellShadow = Color(0x7A000000);

  static const Color accent = Color(0xFF16B7F4);
  static const Color accentSoft = Color(0xFF55A7FF);
  static const Color text = Color(0xFFE9F0F6);
  static const Color textMuted = Color(0xD0C3CCD5);
  static const Color textFaint = Color(0xA69AA5AF);
  static const Color danger = Color(0xFFE16658);

  // Level meters. Shared by the faders, the master rail and the OSD so a
  // position on one reads the same as the same position on another.
  static const Color levelNominal = Color(0xFF4BDA88);
  static const Color levelWarning = Color(0xFFD9C46D);
  static const Color levelPeak = danger;
  static const Color levelSlot = Color(0xFF24262A);

  // Display brightness, which reads as lamp warmth rather than escalation.
  static const Color lampCool = Color(0xFF72C7FF);
  static const Color lampWarm = Color(0xFFEFC75E);
  static const Color lampHot = Color(0xFFFFE68A);

  static const Color dangerHover = Color(0x33E16658);
  static const Color dangerHoverSoft = Color(0x26E16658);
}
