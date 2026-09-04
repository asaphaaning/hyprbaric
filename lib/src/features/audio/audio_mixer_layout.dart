import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'audio_channel_strip.dart';
import 'audio_chrome.dart';
import 'audio_meter_levels.dart';
import 'brightness_control.dart';

/// Mixer title and the currently selected output endpoint.
class AudioMixerHeader extends StatelessWidget {
  const AudioMixerHeader({super.key, required this.output});

  final AudioEndpoint? output;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HyprSpacing.roomy,
        HyprSpacing.xxl + HyprSpacing.hairline,
        HyprSpacing.roomy,
        HyprSpacing.xxl,
      ),
      child: HyprPanelHeader(
        title: 'MIXER',
        titleStyle: HyprTypography.mixerLegend,
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 176),
          child: HyprWell(
            height: 26,
            padding: const EdgeInsets.symmetric(
              horizontal: HyprSpacing.lg + HyprSpacing.xs,
            ),
            borderColor: const Color(0x52000000),
            shadowColor: const Color(0x80000000),
            child: Text(
              output?.name ?? 'No output device',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HyprTypography.mixerMeta.copyWith(
                color: output == null
                    ? HyprColors.textFaint
                    : const Color(0xFFD1EEF0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Layered brightness deck and two-channel audio console.
class AudioMixerStage extends StatelessWidget {
  const AudioMixerStage({
    super.key,
    required this.output,
    required this.input,
    required this.brightnessStatus,
    required this.brightnessLoading,
    required this.onSetVolume,
    required this.onSetMuted,
    required this.onSetBrightness,

    /// Live signal levels for the channel ladders and master rail. Null in
    /// the bar, where every meter follows its endpoint volume.
    this.meterLevels,
  });

  final AudioEndpoint? output;
  final AudioEndpoint? input;
  final BrightnessStatus? brightnessStatus;
  final bool brightnessLoading;
  final void Function(AudioEndpointKind kind, int volume) onSetVolume;
  final void Function(AudioEndpointKind kind, {required bool muted}) onSetMuted;
  final ValueChanged<int> onSetBrightness;
  final AudioMeterLevels? meterLevels;

  /// Where the console begins, below the brightness deck.
  static const double _consoleTop = 117;

  /// Top padding inside the console that clears the knob notch.
  static const double _notchClearance = 74;

  @override
  Widget build(BuildContext context) {
    final double illumination = brightnessStatus?.isAvailable ?? false
        ? (brightnessStatus!.displayValue / 100).clamp(0, 1).toDouble()
        : 0;

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          top: 0,
          left: HyprSpacing.roomy,
          right: HyprSpacing.roomy,
          child: _BrightnessDeck(illumination: illumination),
        ),
        // Non-positioned, so the console sizes the stage instead of a fixed
        // height that overflows the moment text scaling grows the strips.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            HyprSpacing.roomy,
            _consoleTop,
            HyprSpacing.roomy,
            0,
          ),
          child: ClipPath(
            clipper: const _ConsoleNotchClipper(),
            child: ColoredBox(
              color: AudioMixerColors.console,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  HyprSpacing.panel,
                  _notchClearance,
                  HyprSpacing.panel,
                  HyprSpacing.section,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: AudioChannelStrip(
                        channel: AudioMixerChannel.output,
                        endpoint: output,
                        fallbackName: 'No output device',
                        onSetVolume: onSetVolume,
                        onSetMuted: onSetMuted,
                      ),
                    ),
                    const SizedBox(width: HyprSpacing.xxl),
                    Expanded(
                      child: AudioChannelStrip(
                        channel: AudioMixerChannel.input,
                        endpoint: input,
                        fallbackName: 'No input device',
                        onSetVolume: onSetVolume,
                        onSetMuted: onSetMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 13,
          left: 0,
          right: 0,
          child: BrightnessControl(
            status: brightnessStatus,
            loading: brightnessLoading,
            presentation: BrightnessControlPresentation.console,
            onSetBrightness: onSetBrightness,
          ),
        ),
      ],
    );
  }
}

class _BrightnessDeck extends StatelessWidget {
  const _BrightnessDeck({required this.illumination});

  static const double _paintHeight = 197;

  final double illumination;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BrightnessDeckPainter(illumination: illumination),
      // The console removes a circular clearance for the knob. Keep this
      // field taller than that clearance so the deck, not the desktop, is
      // visible all the way around the lower arc.
      child: const SizedBox(height: _paintHeight),
    );
  }
}

class _BrightnessDeckPainter extends CustomPainter {
  const _BrightnessDeckPainter({required this.illumination});

  final double illumination;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect deckBounds = Rect.fromLTWH(0, 0, size.width, 196.5);
    final Paint deckPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          AudioMixerColors.deckTop,
          AudioMixerColors.deckMiddle,
          AudioMixerColors.deckBottom,
        ],
        stops: <double>[0, 0.48, 1],
      ).createShader(deckBounds);
    final RRect deck = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 0, size.width, 131),
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
    );
    final Path silhouette = Path()
      ..addRRect(deck)
      ..addOval(
        Rect.fromCircle(center: Offset(size.width / 2, 122), radius: 74.5),
      );

    canvas.save();
    canvas.clipPath(silhouette);
    canvas.drawRect(deckBounds, deckPaint);
    canvas.drawRect(
      deckBounds,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.42, -0.92),
          radius: 1.1,
          colors: <Color>[
            Color(0x16FFFFFF),
            Color(0x08FFFFFF),
            Colors.transparent,
          ],
          stops: <double>[0, 0.42, 1],
        ).createShader(deckBounds),
    );

    if (illumination > 0) {
      final Offset lampCenter = Offset(size.width / 2 - 10, 114);
      final Rect lampBounds = Rect.fromCircle(center: lampCenter, radius: 96);
      canvas.drawCircle(
        lampCenter,
        96,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              const Color(0x18F2D77A).withValues(alpha: 0.09 * illumination),
              const Color(0x0CF2D77A).withValues(alpha: 0.045 * illumination),
              Colors.transparent,
            ],
            stops: const <double>[0, 0.48, 1],
          ).createShader(lampBounds)
          ..blendMode = BlendMode.plus,
      );
    }

    canvas.restore();
    canvas.drawLine(
      const Offset(12, 0),
      Offset(size.width - 12, 0),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.07)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_BrightnessDeckPainter oldDelegate) =>
      illumination != oldDelegate.illumination;
}

class _ConsoleNotchClipper extends CustomClipper<Path> {
  const _ConsoleNotchClipper();

  @override
  Path getClip(Size size) {
    final Path console = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          Offset.zero & size,
          bottomLeft: const Radius.circular(HyprRadii.chassis),
          bottomRight: const Radius.circular(HyprRadii.chassis),
        ),
      );
    final Path clearance = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(size.width / 2, -6), radius: 74),
      );
    return Path.combine(PathOperation.difference, console, clearance);
  }

  @override
  bool shouldReclip(_ConsoleNotchClipper oldClipper) => false;
}

/// Compact aggregate meter for the output endpoint.
class AudioMasterRail extends StatelessWidget {
  const AudioMasterRail({super.key, required this.output, this.meterLevel});

  final AudioEndpoint? output;

  /// Live output signal for the aggregate meter. See [AudioFader.meterLevel].
  final double? meterLevel;

  @override
  Widget build(BuildContext context) {
    final int volume = output?.volume ?? 0;
    final bool muted = output?.muted ?? true;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HyprSpacing.roomy,
            vertical: HyprSpacing.xl + HyprSpacing.hairline,
          ),
          child: Row(
            children: <Widget>[
              Text('MASTER', style: HyprTypography.mixerLabel),
              const SizedBox(width: HyprSpacing.xxl),
              Expanded(
                child: SizedBox(
                  height: HyprSpacing.xl,
                  child: CustomPaint(
                    painter: HyprSegmentedMeterPainter(
                      value: muted ? 0 : (meterLevel ?? volume / 100),
                      ramp: HyprLevelRamp.audio,
                      trackColor: AudioMixerColors.rail,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: HyprSpacing.xxl),
              SizedBox(
                width: 54,
                child: AudioUnitReadout(
                  text: audioDecibelReadout(volume, muted: muted),
                  unit: 'dB',
                  color: HyprColors.text,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        const HyprPanelDivider(),
      ],
    );
  }
}

/// Input device and the external mixer affordance.
class AudioMixerFooter extends StatelessWidget {
  const AudioMixerFooter({
    super.key,
    required this.input,
    required this.onOpenMixer,
  });

  final AudioEndpoint? input;
  final VoidCallback onOpenMixer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HyprSpacing.roomy,
        HyprSpacing.xl,
        HyprSpacing.roomy,
        HyprSpacing.xxl,
      ),
      child: HyprPanelHeader(
        title: input?.name ?? 'No input device',
        titleStyle: HyprTypography.mixerMeta,
        titleColor: input == null ? HyprColors.textFaint : null,
        leading: Text('MIC', style: HyprTypography.mixerLabel),
        leadingGap: HyprSpacing.xxl,
        actionLabel: 'PAVUCONTROL →',
        actionStyle: HyprTypography.mixerLabel,
        onAction: onOpenMixer,
      ),
    );
  }
}
