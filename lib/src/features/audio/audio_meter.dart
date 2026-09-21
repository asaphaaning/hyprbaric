import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'audio_chrome.dart';

/// Shared channel and master LED ladder, independent of the control position.
class AudioMeter extends StatelessWidget {
  const AudioMeter({
    super.key,
    required this.level,
    required this.accent,
    this.direction = HyprMeterDirection.leftToRight,
    this.rail = false,
  });

  /// Thickness of the recessed channel ladder, in either orientation.
  static const double railExtent = 15;

  /// Signal strength as a fraction of the meter's range.
  final double level;

  /// Nominal channel color, below the warning and peak bands.
  final Color accent;

  /// Orientation of the LED ladder.
  final HyprMeterDirection direction;

  /// Recessed LED rail. The channel column uses this; the master strip does not.
  final bool rail;

  @override
  Widget build(BuildContext context) {
    final bool vertical = direction == HyprMeterDirection.bottomToTop;
    final bool ladder = rail || vertical;
    return SizedBox(
      height: vertical
          ? null
          : ladder
          ? railExtent
          : 8,
      child: CustomPaint(
        painter: HyprSegmentedMeterPainter(
          value: level,
          ramp: HyprLevelRamp(
            nominal: accent,
            warning: AudioMixerColors.amber,
            peak: const Color(0xFFFF8B8B),
            warningAt: .75,
            peakAt: .91,
          ),
          segments: 22,
          direction: direction,
          inset: ladder ? 4.5 : 0.5,
          gap: ladder ? 1.8 : 2.5,
          segmentRadius: 1.3,
          inactiveColor: Color.lerp(const Color(0xFF333B5C), accent, .18)!,
          trackColor: ladder ? AudioMixerColors.rail : null,
          trackRadius: 4,
          glow: 2,
        ),
      ),
    );
  }
}

/// Decibel guide aligned with the meter, separate from the fader hit region.
class AudioDecibelScale extends StatelessWidget {
  const AudioDecibelScale({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        for (final String label in <String>[
          '0',
          '−6',
          '−12',
          '−24',
          '−36',
          '−60',
        ])
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: AudioMixerText.meta.copyWith(fontSize: 9),
            ),
          ),
      ],
    );
  }
}
