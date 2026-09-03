import 'package:flutter/material.dart';

import '../hypr_surface.dart';

typedef HyprInteractiveTileBuilder =
    Widget Function(BuildContext context, HyprInteractiveTileState state);

typedef HyprInteractiveScaleBuilder =
    double Function(HyprInteractiveTileState state);

typedef HyprInteractiveShadowBuilder =
    List<BoxShadow> Function(HyprInteractiveTileState state);

@immutable
class HyprInteractiveTileState {
  const HyprInteractiveTileState({
    required this.hovered,
    required this.pressed,
    required this.selected,
    required this.enabled,
  });

  final bool hovered;
  final bool pressed;
  final bool selected;
  final bool enabled;

  bool get interactive => enabled;
}

class HyprInteractiveTile extends StatefulWidget {
  const HyprInteractiveTile({
    super.key,
    required this.builder,
    this.onPressed,
    this.semanticLabel,
    this.onHoverChanged,
    this.enabled = true,
    this.selected = false,
    this.padding = HyprSpacing.none,
    this.width,
    this.height,
    this.constraints,
    this.borderRadius = HyprRadii.fieldRadius,
    this.color = Colors.transparent,
    this.hoverColor = HyprColors.hover,
    this.pressedColor,
    this.disabledOpacity = 1,
    this.selectedColor = HyprColors.hoverStrong,
    this.borderColor = Colors.transparent,
    this.hoverBorderColor = HyprColors.borderSoft,
    this.selectedBorderColor = HyprColors.border,
    this.scaleBuilder,
    this.shadowsBuilder,
    this.pressedScale = 0.94,
    this.clipBehavior = Clip.antiAlias,
    this.behavior = HitTestBehavior.opaque,
    this.cursor = SystemMouseCursors.click,
    this.duration = HyprMotion.hover,
    this.curve = HyprMotion.hoverCurve,
    this.pressedDuration = HyprDurations.pressed,
    this.pressedCurve = Curves.easeOut,
  });

  final HyprInteractiveTileBuilder builder;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final ValueChanged<bool>? onHoverChanged;
  final bool enabled;
  final bool selected;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final BorderRadius borderRadius;
  final Color color;
  final Color hoverColor;

  /// Fill while the pointer is held down. Falls back to [hoverColor].
  final Color? pressedColor;

  /// Opacity applied while the tile is not interactive.
  final double disabledOpacity;
  final Color selectedColor;
  final Color borderColor;
  final Color hoverBorderColor;
  final Color selectedBorderColor;
  final HyprInteractiveScaleBuilder? scaleBuilder;
  final HyprInteractiveShadowBuilder? shadowsBuilder;
  final double pressedScale;
  final Clip clipBehavior;
  final HitTestBehavior behavior;
  final MouseCursor cursor;
  final Duration duration;
  final Curve curve;
  final Duration pressedDuration;
  final Curve pressedCurve;

  @override
  State<HyprInteractiveTile> createState() => _HyprInteractiveTileState();
}

class _HyprInteractiveTileState extends State<HyprInteractiveTile> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _interactive => widget.enabled && widget.onPressed != null;

  void _setHovered(bool hovered) {
    if (_hovered == hovered) {
      return;
    }
    setState(() => _hovered = hovered);
    widget.onHoverChanged?.call(hovered);
  }

  void _setPressed(bool pressed) {
    if (_pressed == pressed) {
      return;
    }
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final HyprInteractiveTileState state = HyprInteractiveTileState(
      hovered: _interactive && _hovered,
      pressed: _interactive && _pressed,
      selected: widget.selected,
      enabled: _interactive,
    );
    final Widget tile = _withDisabledOpacity(
      state,
      MouseRegion(
      cursor: _interactive ? widget.cursor : MouseCursor.defer,
      onEnter: _interactive ? (_) => _setHovered(true) : null,
      onExit: _interactive
          ? (_) {
              _setHovered(false);
              _setPressed(false);
            }
          : null,
      child: GestureDetector(
        behavior: widget.behavior,
        onTap: _interactive ? widget.onPressed : null,
        onTapDown: _interactive ? (_) => _setPressed(true) : null,
        onTapCancel: _interactive ? () => _setPressed(false) : null,
        onTapUp: _interactive ? (_) => _setPressed(false) : null,
        child: AnimatedScale(
          scale:
              widget.scaleBuilder?.call(state) ??
              (state.pressed ? widget.pressedScale : 1),
          duration: state.pressed ? widget.pressedDuration : widget.duration,
          curve: state.pressed ? widget.pressedCurve : widget.curve,
          child: AnimatedContainer(
            width: widget.width,
            height: widget.height,
            constraints: widget.constraints,
            duration: widget.duration,
            curve: widget.curve,
            padding: widget.padding,
            decoration: ShapeDecoration(
              color: _fillColor(state),
              shadows: widget.shadowsBuilder?.call(state),
              shape: RoundedSuperellipseBorder(
                borderRadius: widget.borderRadius,
                side: BorderSide(color: _borderColor(state)),
              ),
            ),
            clipBehavior: widget.clipBehavior,
            child: widget.builder(context, state),
          ),
        ),
      ),
      ),
    );

    final String? label = widget.semanticLabel;
    if (label == null) {
      return tile;
    }

    return Semantics(
      button: true,
      enabled: _interactive,
      label: label,
      child: tile,
    );
  }

  Widget _withDisabledOpacity(HyprInteractiveTileState state, Widget child) {
    if (widget.disabledOpacity == 1) {
      return child;
    }

    return AnimatedOpacity(
      opacity: state.enabled ? 1 : widget.disabledOpacity,
      duration: widget.duration,
      curve: widget.curve,
      child: child,
    );
  }

  Color _fillColor(HyprInteractiveTileState state) {
    if (state.pressed) {
      return widget.pressedColor ?? widget.hoverColor;
    }
    if (state.selected) {
      return widget.selectedColor;
    }
    if (state.hovered) {
      return widget.hoverColor;
    }
    return widget.color;
  }

  Color _borderColor(HyprInteractiveTileState state) {
    if (state.selected) {
      return widget.selectedBorderColor;
    }
    if (state.hovered) {
      return widget.hoverBorderColor;
    }
    return widget.borderColor;
  }
}
