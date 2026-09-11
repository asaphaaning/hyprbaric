import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'audio_chrome.dart';
import 'brightness_knob.dart';
import 'brightness_status_view.dart';

export 'brightness_knob.dart' show BrightnessKnob, BrightnessKnobState;
export 'brightness_knob_painter.dart' show BrightnessKnobPainter;
export 'brightness_knob_readout.dart' show BrightnessKnobReadout;
export 'brightness_status_view.dart' show BrightnessStatusView;

/// Layouts supported by [BrightnessControl].
enum BrightnessControlPresentation { standalone, console }

class BrightnessControl extends StatefulWidget {
  const BrightnessControl({
    super.key,
    required this.status,
    required this.loading,
    required this.onSetBrightness,
    this.presentation = BrightnessControlPresentation.standalone,
  });

  final BrightnessStatus? status;
  final bool loading;
  final ValueChanged<int> onSetBrightness;
  final BrightnessControlPresentation presentation;

  @override
  State<BrightnessControl> createState() => BrightnessControlState();
}

class BrightnessControlState extends State<BrightnessControl> {
  static const int _minimum = 1;

  final HyprPreviewValue _preview = HyprPreviewValue();
  final HyprLiveValue _commits = HyprLiveValue(
    initialValue: 0,
    minimum: _minimum,
    commitInterval: HyprDurations.commit,
  );

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

  void _setValue(double value, {bool force = false}) {
    final int level = value.clamp(_minimum, 100).round();
    _preview.show(level);
    _commits.preview(level);
    final int? committed = _commits.commit(force: force);
    if (committed == null) {
      return;
    }
    // Let the frame that shows the new value present before the command
    // crosses to Rust. Guarded because the knob lives in a popover that can
    // be dismissed by the same gesture that released it.
    final ValueChanged<int> commit = widget.onSetBrightness;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        commit(committed);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final BrightnessStatus? status = widget.status;
    final bool available = status?.isAvailable ?? false;
    final int? backendValue = status?.displayValue;
    final int value = _preview.settle(backendValue) ?? 0;
    // Keep the commit baseline on the backend so returning the knob to a value
    // the backend reached by other means still dispatches.
    if (!_preview.isActive && backendValue != null) {
      _commits.sync(backendValue);
    }
    final String label = widget.loading
        ? 'Reading display...'
        : available
        ? status?.displayLabel ?? 'Display brightness'
        : status?.displayLabel ?? 'Brightness unavailable';

    final Widget knob = Center(
      child: Semantics(
        slider: available,
        label: label,
        value: available ? '$value' : '--',
        child: Opacity(
          opacity: available ? 1 : 0.45,
          child: BrightnessKnob(
            value: value.clamp(0, 100),
            enabled: available,
            presentation:
                widget.presentation == BrightnessControlPresentation.console
                ? BrightnessKnobPresentation.console
                : BrightnessKnobPresentation.labeled,
            onChanged: (int next) => _setValue(next.toDouble()),
            onChangeEnd: (int next) => _setValue(next.toDouble(), force: true),
          ),
        ),
      ),
    );

    if (widget.presentation != BrightnessControlPresentation.console) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, HyprSpacing.xxs, 0, 0),
        child: knob,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.wb_sunny_outlined,
              size: 23,
              color: AudioMixerColors.amber,
              shadows: available
                  ? const <Shadow>[
                      Shadow(color: Color(0xBBE79519), blurRadius: 7),
                    ]
                  : null,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('DISPLAY', style: AudioMixerText.label, maxLines: 1),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xDD080C17),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0x222F3B66)),
              ),
              child: Text(
                available ? '$value%' : '--',
                style: AudioMixerText.value.copyWith(
                  fontSize: 15,
                  color: AudioMixerColors.amber,
                  shadows: const <Shadow>[
                    Shadow(color: Color(0xAAE08B10), blurRadius: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        SizedBox(
          height: 92,
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: 112,
            maxHeight: 112,
            child: knob,
          ),
        ),
        SizedBox(
          width: 116,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('0', style: AudioMixerText.meta.copyWith(fontSize: 9)),
              Text('100', style: AudioMixerText.meta.copyWith(fontSize: 9)),
            ],
          ),
        ),
      ],
    );
  }
}
