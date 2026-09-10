import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../bindings/bindings.dart';
import 'audio_mixer_layout.dart';
import 'audio_output_menu.dart';
import 'audio_output_selection.dart' as selection;

/// Device chooser kept inside the mixer’s scroll and native input region.
///
/// Selection is confirmed by the backend snapshot rather than optimistically
/// replacing the endpoint. Discovery and command failures stay in the chooser.
class AudioOutputPicker extends StatefulWidget {
  const AudioOutputPicker({
    super.key,
    required this.output,
    required this.outputs,
    required this.child,
    this.description,
    this.onSelected,
    this.commandResult,
  });

  /// Mixer instruments beneath the header and floating device menu.
  final Widget child;

  /// Current default endpoint and its volume.
  final AudioEndpoint? output;

  /// Live device discovery, or null while audio is loading/unavailable.
  final AudioOutputs? outputs;

  /// Optional description below the device name.
  final String? description;

  /// Requests a new default output; null makes the selector read-only.
  final ValueChanged<AudioOutputId>? onSelected;

  /// Backend feedback for a pending selection.
  final AudioCommandResult? commandResult;

  @override
  State<AudioOutputPicker> createState() => _AudioOutputPickerState();
}

class _AudioOutputPickerState extends State<AudioOutputPicker> {
  final FocusNode _toggleFocus = FocusNode();
  final LayerLink _headerLink = LayerLink();
  bool _expanded = false;
  final selection.Control _selection = selection.Control();

  @override
  void dispose() {
    _selection.dispose();
    _toggleFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AudioOutputPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final confirmation = _selection.receive(
      widget.outputs,
      result: identical(widget.commandResult, oldWidget.commandResult)
          ? null
          : widget.commandResult,
    );
    if (confirmation == selection.Confirmation.received) {
      _expanded = false;
      _toggleFocus.requestFocus();
    }
  }

  void _toggle() => setState(() {
    _toggleFocus.requestFocus();
    _expanded = !_expanded;
    _selection.clearFailure();
  });

  void _close() {
    setState(() => _expanded = false);
    _toggleFocus.requestFocus();
  }

  void _select(AudioOutputId id, AudioOutputId? selected) {
    if (id == selected) {
      _close();
      return;
    }
    _selection.select(id);
    widget.onSelected?.call(id);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _selection,
    builder: (context, _) => _buildPicker(context, _selection.state),
  );

  Widget _buildPicker(BuildContext context, selection.State state) {
    final AudioOutputs? outputs = widget.outputs;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        if (_expanded) const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Stack(
        children: <Widget>[
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              CompositedTransformTarget(
                link: _headerLink,
                child: CallbackShortcuts(
                  bindings: <ShortcutActivator, VoidCallback>{
                    if (widget.onSelected != null) ...{
                      const SingleActivator(LogicalKeyboardKey.enter): _toggle,
                      const SingleActivator(LogicalKeyboardKey.space): _toggle,
                    },
                  },
                  child: Focus(
                    focusNode: _toggleFocus,
                    canRequestFocus: widget.onSelected != null,
                    child: Semantics(
                      expanded: _expanded,
                      child: AudioMixerHeader(
                        output: widget.output,
                        description: widget.description,
                        expanded: _expanded,
                        onSelectOutput: widget.onSelected == null
                            ? null
                            : _toggle,
                      ),
                    ),
                  ),
                ),
              ),
              ExcludeFocus(
                excluding: _expanded,
                child: ExcludeSemantics(
                  excluding: _expanded,
                  child: widget.child,
                ),
              ),
            ],
          ),
          if (_expanded)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                excludeFromSemantics: true,
              ),
            ),
          if (_expanded)
            Positioned(
              top: 0,
              left: 13,
              right: 13,
              child: CompositedTransformFollower(
                link: _headerLink,
                targetAnchor: Alignment.bottomLeft,
                offset: const Offset(13, 4),
                showWhenUnlinked: false,
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  child: AudioOutputMenu(
                    outputs: outputs,
                    state: state,
                    onSelected: (id) => _select(
                      id,
                      outputs is AudioOutputsAvailable
                          ? outputs.selected
                          : null,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
