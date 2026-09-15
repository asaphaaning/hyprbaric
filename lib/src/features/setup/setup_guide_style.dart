import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import '../settings/settings_primitives.dart';
import 'setup_guide_state.dart';

const String setupGuideWallpaper = 'assets/wallpaper-demo.png';

abstract final class SetupGuideColors {
  static const Color text = Color(0xFFF0F1F4);
  static const Color textMuted = Color(0xFF92949C);
  static const Color textFaint = HyprInstrumentColors.secondary;
  static const Color cardTitleText = Color(0xFFD5D7DC);
  static const Color rowTitleText = Color(0xFFCACCD2);
  static const Color summaryText = Color(0xFFB8BAC1);
  static const Color glyphActive = Color(0xFFE3E5ED);
  static const Color glyphIdle = Color(0xFF74757D);
  static const Color stageBase = Color(0xFF21171D);
  static const Color wellTop = Color(0xB8171920);
  static const Color wellBottom = Color(0xB821232B);
  static const Color faceTop = Color(0xD0454852);
  static const Color faceBottom = Color(0xD032343D);

  static const LinearGradient chassis = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFA15181E), Color(0xFE0E1116)],
  );

  static const LinearGradient quietFace = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFF4B4D55), Color(0xFF35373E)],
  );
}

extension SetupGuidePalette on BuildContext {
  Color get setupGuideAccent => hyprPalette.accent;

  Color get setupGuideAccentSoft => hyprPalette.accentSoft;
}

/// Setup text roles drawn from the shared instrument typography.
abstract final class SetupGuideTypography {
  static TextStyle get stepTitle => HyprInstrumentText.body.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w500,
  );

  static TextStyle get stepSubtitle =>
      HyprInstrumentText.meta.copyWith(fontSize: 13);
  static TextStyle get cardTitle =>
      HyprInstrumentText.body.copyWith(fontSize: 14);
  static TextStyle get rowTitle => cardTitle;
  static TextStyle get cardSubtitle => HyprInstrumentText.meta;
  static TextStyle get summaryRow =>
      HyprInstrumentText.body.copyWith(fontSize: 13);

  static TextStyle glyph({required bool active}) => TextStyle(
    fontFamily: HyprTypography.monoFamily,
    fontFamilyFallback: const <String>['monospace'],
    color: active ? SetupGuideColors.glyphActive : SetupGuideColors.glyphIdle,
    fontSize: HyprTypography.size(10),
    fontWeight: FontWeight.w600,
  );
}

TextStyle setupMono({
  Color color = SetupGuideColors.textFaint,
  double size = 9.5,
  double spacing = 1.55,
}) => TextStyle(
  color: color,
  fontFamily: HyprTypography.monoFamily,
  fontFamilyFallback: const <String>['monospace'],
  fontSize: HyprTypography.size(size),
  fontWeight: FontWeight.w700,
  letterSpacing: spacing,
);

BoxDecoration setupWell({double radius = 11}) => BoxDecoration(
  borderRadius: BorderRadius.circular(radius),
  gradient: const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[SetupGuideColors.wellTop, SetupGuideColors.wellBottom],
  ),
  border: Border.all(color: const Color(0x6E000000)),
  boxShadow: const <BoxShadow>[
    BoxShadow(
      color: Color(0x99000000),
      blurRadius: 5,
      offset: Offset(0, 2),
      blurStyle: BlurStyle.inner,
    ),
    BoxShadow(
      color: Color(0x10FFFFFF),
      offset: Offset(0, 1),
      blurStyle: BlurStyle.inner,
    ),
  ],
);

enum SetupGuideButtonKind { quiet, primary }

/// Shared ringed settings key used for setup navigation.
class SetupGuideButton extends StatelessWidget {
  const SetupGuideButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = SetupGuideButtonKind.quiet,
  });
  final String label;
  final VoidCallback onPressed;
  final SetupGuideButtonKind kind;

  @override
  Widget build(BuildContext context) => SettingsChoice(
    label: label.toUpperCase(),
    selected: kind == SetupGuideButtonKind.primary,
    onPressed: onPressed,
  );
}

/// The shared instrument slider, with an amount fill or a hue spectrum.
class SetupGuideSlider extends StatelessWidget {
  const SetupGuideSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
    required this.kind,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final HyprSliderKind kind;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey<String>('setup-guide-${kind.name}-slider'),
      width: 120,
      child: HyprInstrumentSlider(
        value: value,
        min: min,
        max: max,
        kind: kind,
        accent: context.setupGuideAccent,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}

/// Visual vocabulary shared by the navigation rail and current step header.
IconData setupStepIcon(SetupStep step) => switch (step) {
  SetupStep.welcome => Icons.auto_awesome_outlined,
  SetupStep.transparency => Icons.blur_on_rounded,
  SetupStep.accent => Icons.palette_outlined,
  SetupStep.layout => Icons.view_quilt_outlined,
  SetupStep.globalMenu => Icons.menu_rounded,
};
