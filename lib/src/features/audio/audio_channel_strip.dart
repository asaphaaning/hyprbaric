import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'audio_chrome.dart';
import 'audio_fader.dart';

enum AudioMixerChannel {
  output('OUT', AudioMixerColors.output),
  input('MIC', AudioMixerColors.input);

  const AudioMixerChannel(this.label, this.accent);

  final String label;
  final Color accent;
}

class AudioChannelStrip extends StatefulWidget {
  const AudioChannelStrip({
    super.key,
    required this.channel,
    required this.endpoint,
    required this.fallbackName,
    required this.onSetVolume,
    required this.onSetMuted,
  });

  final AudioMixerChannel channel;
  final AudioEndpoint? endpoint;
  final String fallbackName;
  final void Function(AudioEndpointKind kind, int volume) onSetVolume;
  final void Function(AudioEndpointKind kind, {required bool muted}) onSetMuted;

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
      padding: const EdgeInsets.fromLTRB(
        HyprSpacing.lg,
        HyprSpacing.xl,
        HyprSpacing.lg,
        HyprSpacing.panel - HyprSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.channel.label,
            textAlign: TextAlign.center,
            style: HyprTypography.mixerLabel.copyWith(
              color: value == null || muted
                  ? HyprColors.textFaint
                  : HyprColors.textMuted,
            ),
          ),
          const SizedBox(height: HyprSpacing.xl),
          Center(
            child: value == null
                ? AudioDisabledFader(accent: widget.channel.accent)
                : AudioFader(
                    endpoint: value,
                    accent: widget.channel.accent,
                    onPreviewVolume: (int volume) =>
                        _preview.show(volume, scope: value.id),
                    onSetVolume: widget.onSetVolume,
                  ),
          ),
          const SizedBox(height: HyprSpacing.xl),
          AudioDbReadout(
            value: displayedVolume,
            muted: muted,
            accent: widget.channel.accent,
          ),
          const SizedBox(height: HyprSpacing.lg + HyprSpacing.hairline),
          AudioMuteButton(
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

/// Recessed decibel display for an audio endpoint.
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
    return HyprWell(
      padding: const EdgeInsets.symmetric(vertical: HyprSpacing.xs),
      borderRadius: HyprRadii.cardRadius,
      child: AudioUnitReadout(
        text: value == null ? '--' : audioDecibelReadout(value!, muted: muted),
        unit: 'dB',
        color: muted ? HyprColors.textFaint : accent,
        textAlign: TextAlign.center,
      ),
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
  });

  final String text;
  final String unit;
  final Color color;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        children: <InlineSpan>[
          TextSpan(
            text: ' $unit',
            style: TextStyle(
              color: HyprColors.textFaint,
              fontSize: HyprTypography.size(7),
            ),
          ),
        ],
      ),
      textAlign: textAlign,
      style: HyprTypography.mixerValue.copyWith(color: color),
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
  });

  final bool muted;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return HyprInteractiveTile(
      onPressed: onPressed,
      semanticLabel: label,
      selected: muted,
      height: 21,
      borderRadius: HyprRadii.badgeRadius,
      color: HyprColors.well,
      borderColor: HyprColors.wellBorder,
      hoverColor: HyprColors.hoverStrong,
      hoverBorderColor: HyprColors.borderSoft,
      selectedColor: HyprColors.dangerHoverSoft,
      selectedBorderColor: HyprColors.danger,
      builder: (BuildContext context, HyprInteractiveTileState state) {
        // The tile already carries the label; the glyph must not merge into it.
        return ExcludeSemantics(
          child: Center(
            child: Text(
              'M',
              style: HyprTypography.mixerLabel.copyWith(
                letterSpacing: 0,
                color: !state.enabled
                    ? HyprColors.textFaint
                    : muted
                    ? HyprColors.danger
                    : HyprColors.textMuted,
              ),
            ),
          ),
        );
      },
    );
  }
}
