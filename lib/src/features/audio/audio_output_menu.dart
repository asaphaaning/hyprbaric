import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import 'audio_chrome.dart';
import 'audio_output_selection.dart' as selection;

/// A bounded, scrollable list of playback devices and selection feedback.
class AudioOutputMenu extends StatelessWidget {
  const AudioOutputMenu({
    super.key,
    required this.outputs,
    required this.state,
    required this.onSelected,
  });

  /// Discovered devices or a discovery error.
  final AudioOutputs? outputs;

  /// One legal selection phase, including any pending output or failure.
  final selection.State state;

  /// Selects a listed output by stable identity.
  final ValueChanged<AudioOutputId> onSelected;

  @override
  Widget build(BuildContext context) {
    final AudioOutputs? outputs = this.outputs;
    final (AudioOutputId? pending, String? error) = switch (state) {
      selection.Idle() => (null, null),
      selection.Selecting(:final id) => (id, null),
      selection.Failed(:final message) => (null, message),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 8, 13, 10),
      decoration: const BoxDecoration(
        color: Color(0xFA15181F),
        borderRadius: BorderRadius.all(Radius.circular(9)),
        border: Border.fromBorderSide(BorderSide(color: Color(0x557B8190))),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text('OUTPUT DEVICE', style: AudioMixerText.label),
          ),
          if (outputs is AudioOutputsAvailable)
            if (outputs.devices.isEmpty)
              const AudioMessage(message: 'No output devices connected')
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    for (final AudioOutput device in outputs.devices)
                      AudioOutputChoice(
                        device: device,
                        selected: device.id == outputs.selected,
                        pending: device.id == pending,
                        onPressed: pending == null
                            ? () => onSelected(device.id)
                            : null,
                      ),
                  ],
                ),
              )
          else
            AudioMessage(
              message: outputs is AudioOutputsUnavailable
                  ? outputs.message
                  : 'Output devices are unavailable',
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Semantics(
                liveRegion: true,
                child: AudioMessage(message: error),
              ),
            ),
        ],
      ),
    );
  }
}

/// One keyboard-accessible device row with confirmed and pending indicators.
class AudioOutputChoice extends StatelessWidget {
  const AudioOutputChoice({
    super.key,
    required this.device,
    required this.selected,
    required this.pending,
    required this.onPressed,
  });

  /// Device represented by this row.
  final AudioOutput device;

  /// Whether this is the backend-confirmed default output.
  final bool selected;

  /// Whether a selection command for this device is in progress.
  final bool pending;

  /// Selection action; null while another command is pending.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AudioMixerColors.text,
        backgroundColor: selected
            ? const Color(0x18FFFFFF)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.volume_up_rounded,
            size: 16,
            color: AudioMixerColors.secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              device.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AudioMixerText.meta.copyWith(color: AudioMixerColors.text),
            ),
          ),
          const SizedBox(width: 8),
          if (pending)
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )
          else if (selected)
            const Icon(
              Icons.check_rounded,
              size: 16,
              color: AudioMixerColors.secondary,
            ),
        ],
      ),
    ),
  );
}
