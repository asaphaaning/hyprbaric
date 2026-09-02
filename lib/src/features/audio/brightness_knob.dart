import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'brightness_knob_painter.dart';
import 'brightness_knob_readout.dart';

/// Visual contexts supported by [BrightnessKnob].
enum BrightnessKnobPresentation { labeled, console }

class BrightnessKnob extends StatefulWidget {
  const BrightnessKnob({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onChangeEnd,
    this.presentation = BrightnessKnobPresentation.labeled,
  });

  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onChangeEnd;
  final BrightnessKnobPresentation presentation;

  @override
  State<BrightnessKnob> createState() => BrightnessKnobState();
}

class BrightnessKnobState extends State<BrightnessKnob> {
  static const double _dragDistance = 150;

  late final HyprLiveValue _value;
  double _startY = 0;
  int _startValue = 0;

  @override
  void initState() {
    super.initState();
    _value = HyprLiveValue(initialValue: widget.value);
  }

  @override
  void didUpdateWidget(covariant BrightnessKnob oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _value.sync(widget.value);
    }
  }

  void _commit(int value, {required bool end}) {
    if (!widget.enabled) {
      return;
    }
    final int next = _value.preview(value);
    if (end) {
      _value.end();
      widget.onChangeEnd(next);
    } else {
      widget.onChanged(next);
    }
  }

  void _startDrag(DragStartDetails details) {
    if (!widget.enabled) {
      return;
    }
    setState(() => _value.begin(widget.value));
    _startY = details.globalPosition.dy;
    _startValue = widget.value;
  }

  void _updateDrag(DragUpdateDetails details) {
    if (!widget.enabled) {
      return;
    }
    final double dy = _startY - details.globalPosition.dy;
    final int next = (_startValue + (dy / _dragDistance) * 100).round();
    _commit(next, end: false);
  }

  void _endDrag() {
    if (!widget.enabled) {
      return;
    }
    final int next = _value.end();
    setState(() {});
    widget.onChangeEnd(next);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (!widget.enabled || event is! PointerScrollEvent) {
      return;
    }
    final int step = HardwareKeyboard.instance.isShiftPressed ? 1 : 4;
    final int direction = event.scrollDelta.dy.sign.toInt();
    if (direction == 0) {
      return;
    }
    _commit(widget.value - direction * step, end: true);
  }

  @override
  Widget build(BuildContext context) {
    final double knobDimension = switch (widget.presentation) {
      BrightnessKnobPresentation.labeled => 76,
      BrightnessKnobPresentation.console => 104,
    };
    final double target = widget.value / 100;
    final Widget knob = RepaintBoundary(
      child: SizedBox.square(
        dimension: knobDimension,
        child: widget.presentation == BrightnessKnobPresentation.console
            ? TweenAnimationBuilder<double>(
                tween: Tween<double>(end: target),
                duration: const Duration(milliseconds: 80),
                curve: Curves.easeOutCubic,
                builder: (BuildContext context, double pointer, Widget? child) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: target),
                    duration: HyprMotion.popup,
                    curve: HyprMotion.popupCurve,
                    builder:
                        (BuildContext context, double lamps, Widget? child) {
                          return CustomPaint(
                            painter: BrightnessKnobPainter(
                              value: pointer,
                              lampValue: lamps,
                              enabled: widget.enabled,
                              console: true,
                            ),
                          );
                        },
                  );
                },
              )
            : CustomPaint(
                painter: BrightnessKnobPainter(
                  value: target,
                  enabled: widget.enabled,
                ),
              ),
      ),
    );

    return MouseRegion(
      cursor: widget.enabled
          ? (_value.active
                ? SystemMouseCursors.grabbing
                : SystemMouseCursors.resizeUpDown)
          : MouseCursor.defer,
      child: Listener(
        onPointerSignal: _handlePointerSignal,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: _startDrag,
          onVerticalDragUpdate: _updateDrag,
          onVerticalDragEnd: (_) => _endDrag(),
          onVerticalDragCancel: _endDrag,
          child: switch (widget.presentation) {
            BrightnessKnobPresentation.console => knob,
            BrightnessKnobPresentation.labeled => Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                knob,
                const SizedBox(height: 10),
                BrightnessKnobReadout(value: widget.value),
                const SizedBox(height: 2),
                Text('BRIGHTNESS', style: HyprTypography.mixerLabel),
              ],
            ),
          },
        ),
      ),
    );
  }
}
