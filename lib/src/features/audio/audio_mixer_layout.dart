import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import '../../widgets/primitives/primitives.dart';
import 'audio_channel_strip.dart';
import 'audio_chrome.dart';
import 'audio_meter.dart';
import 'audio_meter_levels.dart';
import 'audio_mixer_icon.dart';
import 'brightness_control.dart';

/// Mixer title and the active output device selector.
class AudioMixerHeader extends StatelessWidget {
  const AudioMixerHeader({
    super.key,
    required this.output,
    this.description,
    this.onSelectOutput,
    this.expanded = false,
  });

  final AudioEndpoint? output;
  final String? description;
  final VoidCallback? onSelectOutput;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 19, 13, 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AudioMixerColors.divider)),
      ),
      child: Row(
        children: <Widget>[
          const AudioMixerIcon(),
          const SizedBox(width: 11),
          Text(
            'MIXER',
            style: AudioMixerText.label.copyWith(
              fontSize: 13,
              letterSpacing: 1.7,
              color: AudioMixerColors.secondary,
            ),
          ),
          const SizedBox(width: 60),
          Expanded(
            child: AudioOutputSelector(
              output: output,
              description: description,
              onPressed: onSelectOutput,
              expanded: expanded,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable two-line endpoint well. Device selection belongs to the host.
class AudioOutputSelector extends StatelessWidget {
  const AudioOutputSelector({
    super.key,
    required this.output,
    this.description,
    this.onPressed,
    this.expanded = false,
  });

  final AudioEndpoint? output;
  final String? description;
  final VoidCallback? onPressed;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return HyprInteractiveTile(
      semanticLabel: 'Select output device',
      onPressed: onPressed,
      borderRadius: BorderRadius.circular(7),
      color: const Color(0xAA090C12),
      borderColor: const Color(0x22333742),
      builder: (context, state) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 5, 8, 5),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    output?.name ?? 'No output device',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AudioMixerText.meta.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AudioMixerColors.text,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    output == null
                        ? 'No device connected'
                        : (description ?? 'Output device'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AudioMixerText.meta.copyWith(fontSize: 9.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 21,
              color: AudioMixerColors.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Brightness deck above two independently controlled channel strips.
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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CustomPaint(
          painter: const _BrightnessDeckPainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(27, 13, 25, 22),
            child: BrightnessControl(
              status: brightnessStatus,
              loading: brightnessLoading,
              presentation: BrightnessControlPresentation.console,
              onSetBrightness: onSetBrightness,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 17),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: AudioChannelStrip(
                    channel: AudioMixerChannel.output,
                    endpoint: output,
                    fallbackName: 'No output device',
                    onSetVolume: onSetVolume,
                    onSetMuted: onSetMuted,
                    meterLevel: meterLevels?.output,
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 0.5,
                  color: AudioMixerColors.divider,
                ),
                Expanded(
                  child: AudioChannelStrip(
                    channel: AudioMixerChannel.input,
                    endpoint: input,
                    fallbackName: 'No input device',
                    onSetVolume: onSetVolume,
                    onSetMuted: onSetMuted,
                    meterLevel: meterLevels?.input,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The broad, smooth saddle around the dial, painted behind the controls.
class _BrightnessDeckPainter extends CustomPainter {
  const _BrightnessDeckPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double shoulder = size.height - 81;
    final double width = size.width;
    final Path deck = Path()
      ..lineTo(0, shoulder)
      ..lineTo(width * .08, shoulder)
      ..cubicTo(
        width * .27,
        shoulder,
        width * .17,
        size.height,
        width * .5,
        size.height,
      )
      ..cubicTo(
        width * .83,
        size.height,
        width * .73,
        shoulder,
        width * .92,
        shoulder,
      )
      ..lineTo(width, shoulder)
      ..lineTo(width, 0)
      ..close();
    canvas.drawPath(
      deck,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AudioMixerColors.deckTop,
            AudioMixerColors.deckMiddle,
            AudioMixerColors.deckBottom,
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      deck,
      Paint()
        ..color = AudioMixerColors.deckBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = .5,
    );
  }

  @override
  bool shouldRepaint(_BrightnessDeckPainter oldDelegate) => false;
}

/// Compact aggregate meter for the output endpoint.
class AudioMasterRail extends StatelessWidget {
  const AudioMasterRail({super.key, required this.output, this.meterLevel});

  final AudioEndpoint? output;
  final double? meterLevel;

  @override
  Widget build(BuildContext context) {
    final int volume = output?.volume ?? 0;
    final bool muted = output?.muted ?? true;
    final Widget readout = AudioUnitReadout(
      text: output == null ? '--' : audioDecibelReadout(volume, muted: muted),
      unit: 'dB',
      color: AudioMixerColors.text,
      size: 12,
      unitSize: 12,
    );
    final Widget label = Text(
      'MASTER',
      style: AudioMixerText.label.copyWith(
        fontSize: 10,
        color: AudioMixerColors.secondary,
      ),
    );
    final Widget meter = AudioMeter(
      level: muted ? 0 : (meterLevel ?? volume / 100),
      accent: AudioMixerColors.output,
    );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AudioMixerColors.divider),
          bottom: BorderSide(color: AudioMixerColors.divider),
        ),
      ),
      child: MediaQuery.textScalerOf(context).scale(10) > 14
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runSpacing: 6,
                    children: <Widget>[label, readout],
                  ),
                ),
                const SizedBox(height: 10),
                meter,
              ],
            )
          : Row(
              children: <Widget>[
                label,
                const SizedBox(width: 20),
                Expanded(child: meter),
                const SizedBox(width: 17),
                readout,
              ],
            ),
    );
  }
}

/// Input device and external mixer action along the bottom edge.
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
    final Widget device = Row(
      children: <Widget>[
        Text(
          'MIC',
          style: AudioMixerText.label.copyWith(
            fontSize: 10,
            color: AudioMixerColors.secondary,
          ),
        ),
        Container(
          width: .5,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: AudioMixerColors.border,
        ),
        Expanded(
          child: Text(
            input?.name ?? 'No input device',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AudioMixerText.meta.copyWith(color: AudioMixerColors.text),
          ),
        ),
      ],
    );
    final Widget action = HyprInteractiveTile(
      semanticLabel: 'Open Pavucontrol',
      onPressed: onOpenMixer,
      borderRadius: BorderRadius.circular(4),
      builder: (context, state) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Pavucontrol',
              style: AudioMixerText.meta.copyWith(color: AudioMixerColors.text),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.north_east_rounded,
              size: 15,
              color: AudioMixerColors.secondary,
            ),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(21, 14, 15, 17),
      child: MediaQuery.textScalerOf(context).scale(10) > 14
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                device,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            )
          : Row(
              children: <Widget>[
                Expanded(child: device),
                const SizedBox(width: 10),
                action,
              ],
            ),
    );
  }
}
