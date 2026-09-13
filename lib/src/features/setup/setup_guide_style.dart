import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/hypr_instrument_slider.dart';

const String setupGuideWallpaper = 'assets/wallpaper-demo.png';

abstract final class SetupGuideColors {
  static const Color text = Color(0xFFF0F1F4);
  static const Color textMuted = Color(0xFF92949C);
  static const Color textFaint = Color(0xFF60636C);
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

/// Named text roles for the setup guide.
///
/// The guide keeps its own colour palette (the warm chassis look is
/// deliberately not the bar's blue-accented glass) but it draws families and
/// sizing from [HyprTypography] so it snaps to the device pixel grid the same
/// way every other surface does.
abstract final class SetupGuideTypography {
  static TextStyle get stepTitle => TextStyle(
    fontFamily: HyprTypography.uiFamily,
    color: SetupGuideColors.text,
    fontSize: HyprTypography.size(24),
    fontWeight: FontWeight.w600,
    height: 1.16,
    letterSpacing: -.48,
  );

  static TextStyle get stepSubtitle => TextStyle(
    fontFamily: HyprTypography.uiFamily,
    color: SetupGuideColors.textMuted,
    fontSize: HyprTypography.size(12.5),
    height: 1.65,
  );

  static TextStyle get cardTitle => TextStyle(
    fontFamily: HyprTypography.uiFamily,
    color: SetupGuideColors.cardTitleText,
    fontSize: HyprTypography.size(12.5),
    fontWeight: FontWeight.w600,
  );

  static TextStyle get rowTitle => TextStyle(
    fontFamily: HyprTypography.uiFamily,
    color: SetupGuideColors.rowTitleText,
    fontSize: HyprTypography.size(12.5),
    fontWeight: FontWeight.w500,
  );

  /// Shared by choice-card and settings-row supporting copy.
  static TextStyle get cardSubtitle => TextStyle(
    fontFamily: HyprTypography.uiFamily,
    color: SetupGuideColors.textFaint,
    fontSize: HyprTypography.size(11),
    height: 1.45,
  );

  static TextStyle get summaryRow => TextStyle(
    fontFamily: HyprTypography.uiFamily,
    color: SetupGuideColors.summaryText,
    fontSize: HyprTypography.size(12),
  );

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

/// The v6 stage clips inward by 34 logical pixels at its lower edge.
class SetupStageClipper extends CustomClipper<Path> {
  const SetupStageClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width - 34, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(SetupStageClipper oldClipper) => false;
}

/// Draws the faint accent seam that follows [SetupStageClipper].
class SetupSeamPainter extends CustomPainter {
  const SetupSeamPainter({required this.split, required this.accent});

  final double split;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final double top = size.width * split;
    final Paint paint = Paint()
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.transparent,
          accent.withValues(alpha: .28),
          accent.withValues(alpha: .28),
          Colors.transparent,
        ],
        stops: const <double>[0, .22, .78, 1],
      ).createShader(Rect.fromLTWH(top - 34, 0, 34, size.height));
    canvas.drawLine(Offset(top, 0), Offset(top - 34, size.height), paint);
  }

  @override
  bool shouldRepaint(SetupSeamPainter oldDelegate) =>
      split != oldDelegate.split || accent != oldDelegate.accent;
}

enum SetupGuideButtonKind { quiet, primary }

/// A plug-in-plate button with the pronounced v6 chassis ring.
class SetupGuideButton extends StatefulWidget {
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
  State<SetupGuideButton> createState() => _SetupGuideButtonState();
}

class _SetupGuideButtonState extends State<SetupGuideButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool primary = widget.kind == SetupGuideButtonKind.primary;
    final Color accent = context.setupGuideAccent;
    final bool highlighted = _hovered || _focused;
    final LinearGradient face = primary
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color.lerp(accent, Colors.white, highlighted ? .20 : .11)!,
              Color.lerp(accent, Colors.black, .13)!,
            ],
          )
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              highlighted ? const Color(0xFF55575F) : const Color(0xFF4B4D55),
              highlighted ? const Color(0xFF3C3E46) : const Color(0xFF35373E),
            ],
          );

    return Semantics(
      button: true,
      label: widget.label,
      focused: _focused,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (bool value) => setState(() => _focused = value),
        onShowHoverHighlight: (bool value) {
          setState(() {
            _hovered = value;
            if (!value) {
              _pressed = false;
            }
          });
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (ActivateIntent intent) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onPressed();
          },
          child: AnimatedScale(
            scale: _pressed ? .97 : 1,
            duration: const Duration(milliseconds: 90),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFF24262D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xD9000000)),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x99000000),
                    blurRadius: 5,
                    spreadRadius: -2,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: face,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0xA3000000)),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x24FFFFFF),
                      offset: Offset(0, 1),
                      blurStyle: BlurStyle.inner,
                    ),
                    BoxShadow(
                      color: Color(0x59000000),
                      offset: Offset(0, -1),
                      blurStyle: BlurStyle.inner,
                    ),
                  ],
                ),
                child: Text(
                  widget.label.toUpperCase(),
                  style: setupMono(
                    color: primary ? Colors.white : const Color(0xFFCACBD0),
                    size: 10,
                    spacing: 1.3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A carved v6 slider, with either an accent fill or a full hue spectrum.
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
