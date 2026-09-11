import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import 'audio_chrome.dart';
import 'audio_meter_levels.dart';
import 'audio_mixer_layout.dart';
import 'audio_mixer_surface.dart';
import 'audio_output_picker.dart';

/// The complete display and audio mixer, composed from reusable instruments.
///
/// At its natural width of 354 logical pixels, the glass panel follows the
/// reference's portrait proportions. Short hosts scroll the contents without
/// shrinking the controls or their pointer targets.
class AudioPanel extends StatelessWidget {
  const AudioPanel({
    super.key,
    this.borderRadius = radius,
    required this.status,
    required this.brightnessStatus,
    required this.onSetVolume,
    required this.onSetMuted,
    required this.onSetBrightness,
    required this.onOpenMixer,
    this.onSelectOutput,
    this.commandResult,

    /// Live signal levels for the channel ladders and master rail. Null in
    /// the bar, where every meter follows its endpoint volume.
    this.meterLevels,
    this.outputDescription,
  });

  /// Resting width shared with popup positioning and catalog hosts.
  static const double width = 354;

  /// Glass outline shared with the native popup input region.
  static const BorderRadius radius = BorderRadius.all(Radius.circular(17));

  final BorderRadius borderRadius;
  final AsyncValue<AudioStatus> status;
  final AsyncValue<BrightnessStatus> brightnessStatus;
  final void Function(AudioEndpointKind kind, int volume) onSetVolume;
  final void Function(AudioEndpointKind kind, {required bool muted}) onSetMuted;
  final ValueChanged<int> onSetBrightness;
  final VoidCallback onOpenMixer;

  /// Selects the system default playback device.
  final ValueChanged<AudioOutputId>? onSelectOutput;

  /// Latest backend command feedback, including device selection failures.
  final AudioCommandResult? commandResult;
  final AudioMeterLevels? meterLevels;

  /// Optional port description supplied by the host when it is known.
  final String? outputDescription;

  @override
  Widget build(BuildContext context) {
    final AudioStatus? snapshot = status.asData?.value;
    final AudioEndpoint? output = snapshot?.output;
    final AudioEndpoint? input = snapshot?.input;
    final bool unavailable =
        snapshot != null &&
        (!snapshot.isAvailable || (output == null && input == null));

    return AudioMixerSurface(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(
          child: AudioOutputPicker(
            output: output,
            outputs: snapshot is AudioStatusAvailable ? snapshot.outputs : null,
            description: outputDescription,
            onSelected: onSelectOutput,
            commandResult: commandResult,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AudioMixerStage(
                  output: output,
                  input: input,
                  brightnessStatus: brightnessStatus.asData?.value,
                  brightnessLoading: brightnessStatus.isLoading,
                  onSetVolume: onSetVolume,
                  onSetMuted: onSetMuted,
                  onSetBrightness: onSetBrightness,
                  meterLevels: meterLevels,
                ),
                AudioMasterRail(
                  output: output,
                  meterLevel: meterLevels?.output,
                ),
                AudioMixerFooter(input: input, onOpenMixer: onOpenMixer),
                if (status.isLoading)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      HyprSpacing.panel,
                      0,
                      HyprSpacing.panel,
                      HyprSpacing.section,
                    ),
                    child: AudioMessage(message: 'Reading audio devices...'),
                  )
                else if (unavailable)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      HyprSpacing.panel,
                      0,
                      HyprSpacing.panel,
                      HyprSpacing.section,
                    ),
                    child: AudioMessage(
                      message:
                          snapshot.message ?? 'Audio controls are unavailable.',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
