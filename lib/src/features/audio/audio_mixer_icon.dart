import 'package:flutter/material.dart';

import 'audio_chrome.dart';

/// Three fine slider rails used to identify the display/audio mixer.
class AudioMixerIcon extends StatelessWidget {
  const AudioMixerIcon({
    super.key,
    this.size = 23,
    this.color = AudioMixerColors.text,
  });

  /// Square extent of the glyph.
  final double size;

  /// Rail and slider color.
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _Rails(color)),
  );
}

/// Draws interrupted rails around short, flat slider markers.
class _Rails extends CustomPainter {
  const _Rails(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 23, size.height / 23);
    final Paint stroke = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final (double horizontal, double marker) in <(double, double)>[
      (4, 10),
      (11.5, 15),
      (19, 9),
    ]) {
      canvas.drawLine(
        Offset(horizontal, 2),
        Offset(horizontal, marker - 3),
        stroke,
      );
      canvas.drawLine(
        Offset(horizontal, marker + 3),
        Offset(horizontal, 21),
        stroke,
      );
      canvas.drawLine(
        Offset(horizontal - 2.5, marker),
        Offset(horizontal + 2.5, marker),
        stroke,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Rails oldDelegate) => oldDelegate.color != color;
}
