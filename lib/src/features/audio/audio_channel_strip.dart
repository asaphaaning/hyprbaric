import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'audio_chrome.dart';
import 'audio_fader.dart';

/// Identity and visual vocabulary of the two mixer channels.
enum AudioMixerChannel {
  /// Playback through the selected output.
  output('OUT', AudioMixerColors.output),

  /// Capture from the selected microphone.
  input('MIC', AudioMixerColors.input);

  const AudioMixerChannel(this.label, this.accent);

  /// Short channel heading.
  final String label;

  /// Color shared by the meter, fader, and readout.
  final Color accent;

  /// Filled icon used in the channel heading.
  IconData get icon => switch (this) {
    output => Icons.volume_up_rounded,
    input => Icons.mic_rounded,
  };
}

class AudioChannelStrip extends StatefulWidget {
  const AudioChannelStrip({
    super.key,
    required this.channel,
    required this.endpoint,
    required this.fallbackName,
    required this.onSetVolume,
    required this.onSetMuted,

    /// Live signal level for this channel's meter ladder. See
    /// [AudioFader.meterLevel].
    this.meterLevel,
  });

  final AudioMixerChannel channel;
  final AudioEndpoint? endpoint;
  final String fallbackName;
  final void Function(AudioEndpointKind kind, int volume) onSetVolume;
  final void Function(AudioEndpointKind kind, {required bool muted}) onSetMuted;
  final double? meterLevel;

  @override
  State<AudioChannelStrip> createState() => AudioChannelStripState();
}

class AudioChannelStripState extends State<AudioChannelStrip> {
  final HyprPreviewValue _preview = HyprPreviewValue();

  @override
  void initState() {
    super.initState();
    _preview.addListener(_onPreviewChanged);
  }

  @override
  void dispose() {
    _preview
      ..removeListener(_onPreviewChanged)
      ..dispose();
    super.dispose();
  }

  void _onPreviewChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final AudioEndpoint? value = widget.endpoint;
    final int? displayedVolume = _preview.settle(
      value?.volume,
      scope: value?.id,
    );
    final bool muted = value?.muted ?? true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Row(
              children: <Widget>[
                Icon(
                  widget.channel.icon,
                  size: 22,
                  color: AudioMixerColors.text,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.channel.label,
                  style: AudioMixerText.label.copyWith(
                    fontSize: 12,
                    color: value == null
                        ? AudioMixerColors.secondary
                        : AudioMixerColors.text,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: widget.channel == AudioMixerChannel.output
                ? const Alignment(-.4, 0)
                : const Alignment(.25, 0),
            child: value == null
                ? AudioDisabledFader(accent: widget.channel.accent)
                : AudioFader(
                    endpoint: value,
                    accent: widget.channel.accent,
                    onPreviewVolume: (int volume) =>
                        _preview.show(volume, scope: value.id),
                    onSetVolume: widget.onSetVolume,
                    meterLevel: widget.meterLevel,
                  ),
          ),
          const SizedBox(height: 13),
          AudioDbReadout(
            value: displayedVolume,
            muted: muted,
            accent: widget.channel.accent,
          ),
          const SizedBox(height: 13),
          AudioMuteButton(
            channel: widget.channel,
            muted: muted,
            label: value == null
                ? widget.fallbackName
                : muted
                ? 'Unmute ${value.name}'
                : 'Mute ${value.name}',
            onPressed: value == null
                ? null
                : () => widget.onSetMuted(value.kind, muted: !muted),
          ),
        ],
      ),
    );
  }
}

/// Illuminated decibel display for an audio endpoint.
class AudioDbReadout extends StatelessWidget {
  const AudioDbReadout({
    super.key,
    required this.value,
    required this.muted,
    required this.accent,
  });

  final int? value;
  final bool muted;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AudioUnitReadout(
      text: value == null ? '--' : audioDecibelReadout(value!, muted: muted),
      unit: 'dB',
      color: muted ? HyprColors.textFaint : accent,
      textAlign: TextAlign.center,
    );
  }
}

/// A measured value followed by its unit, sized as one readout.
class AudioUnitReadout extends StatelessWidget {
  const AudioUnitReadout({
    super.key,
    required this.text,
    required this.unit,
    required this.color,
    this.textAlign = TextAlign.left,
    this.size = 17,
    this.unitSize,
  });

  final String text;
  final String unit;
  final Color color;
  final TextAlign textAlign;
  final double size;

  /// Explicit unit size for inline readouts such as the master rail.
  final double? unitSize;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        children: <InlineSpan>[
          TextSpan(
            text: ' $unit',
            style: TextStyle(
              color: Color.lerp(color, AudioMixerColors.secondary, .6),
              fontSize: unitSize ?? size * .68,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
      textAlign: textAlign,
      style: AudioMixerText.value.copyWith(color: color, fontSize: size),
    );
  }
}

/// Compact mute control for a mixer channel.
class AudioMuteButton extends StatelessWidget {
  const AudioMuteButton({
    super.key,
    required this.muted,
    required this.label,
    required this.onPressed,
    this.channel = AudioMixerChannel.output,
  });

  final bool muted;
  final String label;
  final VoidCallback? onPressed;
  final AudioMixerChannel channel;

  @override
  Widget build(BuildContext context) {
    return HyprInteractiveTile(
      onPressed: onPressed,
      semanticLabel: label,
      selected: muted && onPressed != null,
      borderRadius: BorderRadius.circular(5),
      color: Colors.transparent,
      borderColor: Colors.transparent,
      hoverColor: const Color(0x224B5081),
      selectedColor: const Color(0x225F346E),
      selectedBorderColor: const Color(0x554E375F),
      builder: (BuildContext context, HyprInteractiveTileState state) {
        final Color color = !state.enabled
            ? HyprColors.textFaint
            : muted
            ? channel.accent
            : AudioMixerColors.secondary;
        return ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  muted
                      ? (channel == AudioMixerChannel.input
                            ? Icons.mic_off_outlined
                            : Icons.volume_off_outlined)
                      : (channel == AudioMixerChannel.input
                            ? Icons.mic_none_rounded
                            : Icons.volume_up_outlined),
                  size: 21,
                  color: color,
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    muted && state.enabled ? 'Unmute' : 'Mute',
                    style: AudioMixerText.meta.copyWith(
                      fontSize: 12,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
