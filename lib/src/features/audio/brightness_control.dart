import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
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
    // crosses to Rust.
    final ValueChanged<int> commit = widget.onSetBrightness;
    WidgetsBinding.instance.addPostFrameCallback((_) => commit(committed));
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
        HyprWell(
          padding: const EdgeInsets.symmetric(
            horizontal: HyprSpacing.xxl,
            vertical: HyprSpacing.sm,
          ),
          borderColor: Colors.transparent,
          shadowColor: const Color(0x70000000),
          child: Text.rich(
            TextSpan(
              text: 'DISPLAY ',
              children: <InlineSpan>[
                TextSpan(
                  text: available ? '$value%' : '--',
                  style: const TextStyle(color: HyprColors.textMuted),
                ),
              ],
            ),
            style: HyprTypography.mixerLegend.copyWith(color: HyprColors.text),
          ),
        ),
        const SizedBox(height: HyprSpacing.loose + HyprSpacing.sm),
        knob,
      ],
    );
  }
}
