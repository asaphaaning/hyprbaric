import 'package:flutter/material.dart';

/// The quantity represented by an instrument slider's track.
enum HyprSliderKind {
  /// A level, filled from the minimum to the current value.
  amount,

  /// A hue angle shown against the complete color spectrum.
  hue,
}

/// The setup guide's carved track and shaded thumb, shared with settings.
///
/// The host owns sizing and value updates. Material ripple and halo feedback
/// are disabled; the physical thumb supplies the visual affordance.
class HyprInstrumentSlider extends StatelessWidget {
  const HyprInstrumentSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
    required this.kind,
    required this.accent,
    this.divisions,
  });

  /// Current value within [min] and [max].
  final double value;

  /// Lower end of the range.
  final double min;

  /// Upper end of the range.
  final double max;

  /// Updates the host's live preview during interaction.
  final ValueChanged<double> onChanged;

  /// Commits the final value when interaction finishes.
  final ValueChanged<double> onChangeEnd;

  /// The meaning and appearance of the track.
  final HyprSliderKind kind;

  /// Fill color for an amount track.
  final Color accent;

  /// Optional discrete steps; null keeps the range continuous.
  final int? divisions;

  @override
  Widget build(BuildContext context) => SliderTheme(
    data: SliderTheme.of(context).copyWith(
      trackHeight: 6,
      activeTrackColor: accent,
      activeTickMarkColor: Colors.transparent,
      inactiveTickMarkColor: Colors.transparent,
      overlayShape: SliderComponentShape.noOverlay,
      overlayColor: Colors.transparent,
      showValueIndicator: ShowValueIndicator.never,
      trackShape: _InstrumentSliderTrack(kind: kind),
      thumbShape: const HyprInstrumentSliderThumb(),
    ),
    child: Slider(
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      onChanged: onChanged,
      onChangeEnd: onChangeEnd,
    ),
  );
}

class _InstrumentSliderTrack extends SliderTrackShape {
  const _InstrumentSliderTrack({required this.kind});

  final HyprSliderKind kind;

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

    if (kind == HyprSliderKind.hue) {
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

/// The shaded, recessed-edge thumb used by all standard instrument sliders.
class HyprInstrumentSliderThumb extends SliderComponentShape {
  const HyprInstrumentSliderThumb();

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
