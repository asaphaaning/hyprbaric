import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';

const String setupGuideWallpaper = 'assets/wallpaper-demo.png';

abstract final class SetupGuideColors {
  static const Color scrim = Color(0xB8000308);
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

enum SetupGuideSliderKind { amount, hue }

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
  final SetupGuideSliderKind kind;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey<String>('setup-guide-${kind.name}-slider'),
      width: 120,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 6,
          activeTrackColor: context.setupGuideAccent,
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
          overlayColor: Colors.white.withValues(alpha: .08),
          trackShape: _SetupSliderTrack(kind: kind),
          thumbShape: const _SetupSliderThumb(),
        ),
        child: Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ),
    );
  }
}

class _SetupSliderTrack extends SliderTrackShape {
  const _SetupSliderTrack({required this.kind});

  final SetupGuideSliderKind kind;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    const double horizontalInset = 8;
    return Rect.fromLTWH(
      offset.dx + horizontalInset,
      offset.dy + (parentBox.size.height - 6) / 2,
      parentBox.size.width - horizontalInset * 2,
      6,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final Canvas canvas = context.canvas;
    final Rect track = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );
    final RRect channel = RRect.fromRectAndRadius(
      track,
      const Radius.circular(3),
    );
    canvas.drawRRect(
      channel.shift(const Offset(0, 1)),
      Paint()
        ..color = const Color(0xB5000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );

    if (kind == SetupGuideSliderKind.hue) {
      canvas.drawRRect(
        channel,
        Paint()
          ..shader = const LinearGradient(
            colors: <Color>[
              Color(0xFFE65872),
              Color(0xFFE8B752),
              Color(0xFF69D37A),
              Color(0xFF4FD4D7),
              Color(0xFF5D8FE7),
              Color(0xFF9C6BE4),
              Color(0xFFE658B7),
              Color(0xFFE65872),
            ],
          ).createShader(track),
      );
    } else {
      canvas.drawRRect(
        channel,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF4B4D55), Color(0xFF383A42)],
          ).createShader(track),
      );
      final Rect active = Rect.fromLTRB(
        track.left,
        track.top,
        thumbCenter.dx.clamp(track.left, track.right),
        track.bottom,
      );
      if (active.width > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(active, const Radius.circular(3)),
          Paint()
            ..shader = LinearGradient(
              colors: <Color>[
                sliderTheme.activeTrackColor ?? const Color(0xFF6F95E8),
                (sliderTheme.activeTrackColor ?? const Color(0xFF6F95E8))
                    .withValues(alpha: .72),
              ],
            ).createShader(active),
        );
      }
    }

    canvas.drawRRect(
      channel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x95000000),
    );
  }
}

class _SetupSliderThumb extends SliderComponentShape {
  const _SetupSliderThumb();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(15, 15);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    canvas.drawCircle(
      center + const Offset(0, 2),
      8,
      Paint()
        ..color = const Color(0xB5000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(
      center,
      7.5,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.35, -.45),
          radius: .95,
          colors: <Color>[
            Color(0xFFFFFFFF),
            Color(0xFFD2D5DF),
            Color(0xFF9195A2),
          ],
          stops: <double>[0, .55, 1],
        ).createShader(Rect.fromCircle(center: center, radius: 7.5)),
    );
    canvas.drawCircle(
      center,
      7.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x7A000000),
    );
  }
}
