import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../../widgets/primitives/primitives.dart';
import 'audio_chrome.dart';
import 'audio_mixer_layout.dart';

class AudioPanel extends StatelessWidget {
  const AudioPanel({
    super.key,
    required this.borderRadius,
    required this.status,
    required this.brightnessStatus,
    required this.onSetVolume,
    required this.onSetMuted,
    required this.onSetBrightness,
    required this.onOpenMixer,
  });

  final BorderRadius borderRadius;
  final AsyncValue<AudioStatus> status;
  final AsyncValue<BrightnessStatus> brightnessStatus;
  final void Function(AudioEndpointKind kind, int volume) onSetVolume;
  final void Function(AudioEndpointKind kind, {required bool muted}) onSetMuted;
  final ValueChanged<int> onSetBrightness;
  final VoidCallback onOpenMixer;

  @override
  Widget build(BuildContext context) {
    final AudioStatus? snapshot = status.asData?.value;
    final AudioEndpoint? output = snapshot?.output;
    final AudioEndpoint? input = snapshot?.input;
    final bool unavailable =
        snapshot != null &&
        (!snapshot.isAvailable || (output == null && input == null));

    return HyprPopoverPanel(
      borderRadius: borderRadius,
      constraints: const BoxConstraints(minWidth: 336, maxWidth: 336),
      padding: EdgeInsets.zero,
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              AudioMixerColors.chassisTop,
              AudioMixerColors.chassisBottom,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AudioMixerHeader(output: output),
            AudioMixerStage(
              output: output,
              input: input,
              brightnessStatus: brightnessStatus.asData?.value,
              brightnessLoading: brightnessStatus.isLoading,
              onSetVolume: onSetVolume,
              onSetMuted: onSetMuted,
              onSetBrightness: onSetBrightness,
            ),
            AudioMasterRail(output: output),
            AudioMixerFooter(input: input, onOpenMixer: onOpenMixer),
            if (status.isLoading) ...<Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: AudioMessage(message: 'Reading audio devices...'),
              ),
            ] else if (unavailable) ...<Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: AudioMessage(
                  message:
                      snapshot.message ?? 'Audio controls are unavailable.',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
