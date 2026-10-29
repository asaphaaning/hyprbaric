import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../theme/hypr_motion.dart';
import '../../theme/hypr_radii.dart';
import '../surfaces/hypr_colors.dart';

/// How a [HyprPlateTrack] paints its plate.
@immutable
class HyprPlateStyle {
  const HyprPlateStyle({
    this.fill = HyprColors.hoverStrong,
    this.border = HyprColors.border,
    this.borderWidth = 1.1,
    this.radius = HyprRadii.row,
    this.glow = const Color(0x00000000),
    this.glowBlur = 0,
    this.inflate = EdgeInsets.zero,
    this.gradient,
  });

  /// The plate shown under hovered slots.
  static const HyprPlateStyle hover = HyprPlateStyle(
    fill: HyprColors.hover,
    border: Color(0x00000000),
    borderWidth: 0,
  );

  final Color fill;
  final Color border;
  final double borderWidth;
  final double radius;

  /// Soft light around the plate; transparent paints none.
  final Color glow;
  final double glowBlur;

  /// Grows the plate beyond its slot, e.g. to sit around a label.
  final EdgeInsets inflate;

  /// Material painted instead of [fill], for plates that are not flat.
  final Gradient? gradient;

  factory HyprPlateStyle.lerp(HyprPlateStyle a, HyprPlateStyle b, double t) {
    if (identical(a, b) || t <= 0) {
      return a;
    }
    if (t >= 1) {
      return b;
    }
    return HyprPlateStyle(
      fill: Color.lerp(a.fill, b.fill, t)!,
      border: Color.lerp(a.border, b.border, t)!,
      borderWidth: ui.lerpDouble(a.borderWidth, b.borderWidth, t)!,
      radius: ui.lerpDouble(a.radius, b.radius, t)!,
      glow: Color.lerp(a.glow, b.glow, t)!,
      glowBlur: ui.lerpDouble(a.glowBlur, b.glowBlur, t)!,
      inflate: EdgeInsets.lerp(a.inflate, b.inflate, t)!,
      gradient: Gradient.lerp(a.gradient, b.gradient, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HyprPlateStyle &&
      other.fill == fill &&
      other.border == border &&
      other.borderWidth == borderWidth &&
      other.radius == radius &&
      other.glow == glow &&
      other.glowBlur == glowBlur &&
      other.inflate == inflate &&
      other.gradient == gradient;

  @override
  int get hashCode => Object.hash(
    fill,
    border,
    borderWidth,
    radius,
    glow,
    glowBlur,
    inflate,
    gradient,
  );
}

/// One plate gliding between the [HyprPlateSlot]s below it.
///
/// Slots say whether they are active; the track paints a single plate under
/// the active slot and, on a change, slides it across with the leading edge
/// running ahead of the trailing one. With [hoverStyle] a second, quieter
/// plate follows the pointer between slots. Both are paint-only: neither
/// rebuilds nor relays out the slots while it moves.
class HyprPlateTrack extends StatefulWidget {
  const HyprPlateTrack({
    super.key,
    required this.child,
    this.style = const HyprPlateStyle(),
    this.hoverStyle,
    this.duration = HyprMotion.plate,
    this.hoverDuration = HyprMotion.plateHover,
  });

  final Widget child;
  final HyprPlateStyle style;
  final HyprPlateStyle? hoverStyle;
  final Duration duration;
  final Duration hoverDuration;

  /// Whether [context] sits below a track, so its slots' plate is painted
  /// by the track rather than by the controls themselves.
  static bool isPresent(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PlateScope>() != null;

  @override
  State<HyprPlateTrack> createState() => _HyprPlateTrackState();
}

class _HyprPlateTrackState extends State<HyprPlateTrack>
    with TickerProviderStateMixin {
  late final _Plate _active = _Plate(
    AnimationController(vsync: this, duration: widget.duration),
  );
  late final _Plate _hover = _Plate(
    AnimationController(vsync: this, duration: widget.hoverDuration),
  );

  @override
  void didUpdateWidget(HyprPlateTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _active.controller.duration = widget.duration;
    _hover.controller.duration = widget.hoverDuration;
  }

  @override
  void dispose() {
    _active.controller.dispose();
    _hover.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PlateScope(
      active: _active,
      hover: widget.hoverStyle == null ? null : _hover,
      child: _PlatePaint(
        active: _active,
        hover: _hover,
        style: widget.style,
        hoverStyle: widget.hoverStyle,
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}

/// One plate's travel: which slot it is heading for and where it set off.
class _Plate {
  _Plate(this.controller);

  final AnimationController controller;
  _RenderPlateSlot? target;
  _RenderPlateSlot? origin;

  /// Where the plate was painted last, relative to the track.
  Rect? shown;
  HyprPlateStyle? shownStyle;
  double shownOpacity = 0;

  Rect? _from;
  HyprPlateStyle? _fromStyle;
  double _fromOpacity = 0;

  void moveTo(_RenderPlateSlot? slot) {
    if (identical(slot, target)) {
      return;
    }
    _from = shown;
    _fromStyle = shownStyle;
    _fromOpacity = shownOpacity;
    origin = target;
    target = slot;
    controller.forward(from: 0);
  }

  void release(_RenderPlateSlot slot) {
    if (identical(target, slot)) {
      moveTo(null);
    }
  }

  void forget(_RenderPlateSlot slot) {
    if (identical(target, slot)) {
      target = null;
    }
    if (identical(origin, slot)) {
      origin = null;
    }
  }
}

class _PlateScope extends InheritedWidget {
  const _PlateScope({
    required this.active,
    required this.hover,
    required super.child,
  });

  final _Plate active;
  final _Plate? hover;

  @override
  bool updateShouldNotify(_PlateScope oldWidget) =>
      !identical(oldWidget.active, active) ||
      !identical(oldWidget.hover, hover);
}

/// A place a [HyprPlateTrack]'s plate can rest.
class HyprPlateSlot extends StatelessWidget {
  const HyprPlateSlot({
    super.key,
    required this.active,
    required this.child,
    this.style,
  });

  /// Whether the track's plate rests here.
  final bool active;

  /// This slot's own plate, blended into as the plate arrives.
  final HyprPlateStyle? style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final _PlateScope? scope = context
        .dependOnInheritedWidgetOfExactType<_PlateScope>();
    if (scope == null) {
      return child;
    }
    final Widget slot = _PlateSlot(
      plate: scope.active,
      active: active,
      style: style,
      child: child,
    );
    final _Plate? hover = scope.hover;
    if (hover == null) {
      return slot;
    }
    return _HoverRegion(plate: hover, child: slot);
  }
}

class _HoverRegion extends StatelessWidget {
  const _HoverRegion({required this.plate, required this.child});

  final _Plate plate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      opaque: false,
      hitTestBehavior: HitTestBehavior.deferToChild,
      onEnter: (_) {
        final _RenderPlateSlot? slot = _slotIn(context);
        if (slot != null) {
          plate.moveTo(slot);
        }
      },
      onExit: (_) {
        final _RenderPlateSlot? slot = _slotIn(context);
        if (slot != null) {
          plate.release(slot);
        }
      },
      child: child,
    );
  }

  static _RenderPlateSlot? _slotIn(BuildContext context) {
    _RenderPlateSlot? found;
    void visit(Element element) {
      if (found != null) {
        return;
      }
      final RenderObject? object = element.renderObject;
      if (object is _RenderPlateSlot) {
        found = object;
        return;
      }
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    return found;
  }
}

class _PlateSlot extends SingleChildRenderObjectWidget {
  const _PlateSlot({
    required this.plate,
    required this.active,
    required this.style,
    required super.child,
  });

  final _Plate plate;
  final bool active;
  final HyprPlateStyle? style;

  @override
  _RenderPlateSlot createRenderObject(BuildContext context) =>
      _RenderPlateSlot(plate: plate, active: active, style: style);

  @override
  void updateRenderObject(BuildContext context, _RenderPlateSlot renderObject) {
    renderObject
      ..style = style
      ..plate = plate
      ..active = active;
  }
}

class _RenderPlateSlot extends RenderProxyBox {
  _RenderPlateSlot({
    required _Plate plate,
    required bool active,
    required this.style,
  }) : _plate = plate,
       _active = active;

  HyprPlateStyle? style;

  _Plate _plate;
  set plate(_Plate value) {
    if (identical(value, _plate)) {
      return;
    }
    _plate.forget(this);
    _plate = value;
    if (_active) {
      _plate.moveTo(this);
    }
  }

  bool _active;
  set active(bool value) {
    if (value == _active) {
      return;
    }
    _active = value;
    if (value) {
      _plate.moveTo(this);
    } else {
      // Another slot activated in the same frame has already taken over.
      _plate.release(this);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (_active) {
      // A slot that mounts active is where the plate starts; it does not
      // fly in from nowhere.
      if (_plate.target == null && _plate.shown == null) {
        _plate.target = this;
        _plate.controller.value = 1;
      } else {
        _plate.moveTo(this);
      }
    }
  }

  @override
  void detach() {
    _plate.forget(this);
    super.detach();
  }
}

class _PlatePaint extends SingleChildRenderObjectWidget {
  const _PlatePaint({
    required this.active,
    required this.hover,
    required this.style,
    required this.hoverStyle,
    required super.child,
  });

  final _Plate active;
  final _Plate hover;
  final HyprPlateStyle style;
  final HyprPlateStyle? hoverStyle;

  @override
  _RenderPlatePaint createRenderObject(BuildContext context) =>
      _RenderPlatePaint(
        active: active,
        hover: hover,
        style: style,
        hoverStyle: hoverStyle,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPlatePaint renderObject,
  ) {
    renderObject
      ..style = style
      ..hoverStyle = hoverStyle;
  }
}

class _RenderPlatePaint extends RenderProxyBox {
  _RenderPlatePaint({
    required this.active,
    required this.hover,
    required HyprPlateStyle style,
    required HyprPlateStyle? hoverStyle,
  }) : _style = style,
       _hoverStyle = hoverStyle;

  final _Plate active;
  final _Plate hover;

  HyprPlateStyle _style;
  set style(HyprPlateStyle value) {
    if (value == _style) {
      return;
    }
    _style = value;
    markNeedsPaint();
  }

  HyprPlateStyle? _hoverStyle;
  set hoverStyle(HyprPlateStyle? value) {
    if (value == _hoverStyle) {
      return;
    }
    _hoverStyle = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    active.controller.addListener(markNeedsPaint);
    hover.controller.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    active.controller.removeListener(markNeedsPaint);
    hover.controller.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    // Slots may have moved; repaint so the plate follows them.
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final HyprPlateStyle? hoverStyle = _hoverStyle;
    if (hoverStyle != null) {
      _paintPlate(context.canvas, offset, hover, hoverStyle, stretch: false);
    }
    _paintPlate(context.canvas, offset, active, _style, stretch: true);
    super.paint(context, offset);
  }

  Rect? _slotRect(_RenderPlateSlot? slot) {
    if (slot == null || !slot.attached || !slot.hasSize) {
      return null;
    }
    final Matrix4 transform = slot.getTransformTo(this);
    return MatrixUtils.transformRect(transform, Offset.zero & slot.size);
  }

  void _paintPlate(
    Canvas canvas,
    Offset offset,
    _Plate plate,
    HyprPlateStyle trackStyle, {
    required bool stretch,
  }) {
    final double t = plate.controller.value;
    final Rect? target = _slotRect(plate.target);
    final HyprPlateStyle targetStyle = plate.target?.style ?? trackStyle;
    final Rect? from = plate._from;
    final HyprPlateStyle fromStyle = plate._fromStyle ?? targetStyle;

    Rect? rect;
    double opacity;
    HyprPlateStyle style;
    if (target != null && from != null) {
      rect = stretch ? _stretch(from, target, t) : _glide(from, target, t);
      opacity = ui.lerpDouble(plate._fromOpacity, 1, _fade(t))!;
      style = HyprPlateStyle.lerp(fromStyle, targetStyle, _glideCurve(t));
    } else if (target != null) {
      // Appearing from nowhere is not a move: the selection plate is simply
      // there, and the hover plate fades in as a hover colour would.
      rect = target;
      opacity = stretch ? 1 : _fade(t);
      style = targetStyle;
    } else if (from != null) {
      // Leaving likewise: the selection plate goes at once.
      rect = from;
      opacity = stretch ? 0 : plate._fromOpacity * (1 - _fade(t));
      style = fromStyle;
    } else {
      opacity = 0;
      style = targetStyle;
    }

    plate
      ..shown = rect
      ..shownStyle = style
      ..shownOpacity = opacity;
    if (rect == null || opacity <= 0.003) {
      return;
    }
    _drawPlate(canvas, rect.shift(offset), style, opacity);
  }

  static double _glideCurve(double t) => HyprMotion.plateCurve.transform(t);

  static double _fade(double t) => (t / .35).clamp(0.0, 1.0);

  static Rect _glide(Rect from, Rect to, double t) =>
      Rect.lerp(from, to, _glideCurve(t))!;

  /// Leading edge first, trailing edge catching up: the plate stretches
  /// toward its destination and contracts as it lands.
  static Rect _stretch(Rect from, Rect to, double t) {
    final double lead = HyprMotion.plateLeadCurve.transform(t);
    final double trail = HyprMotion.plateTrailCurve.transform(t);
    final bool rightward = to.center.dx >= from.center.dx;
    final double left = ui.lerpDouble(
      from.left,
      to.left,
      rightward ? trail : lead,
    )!;
    final double right = ui.lerpDouble(
      from.right,
      to.right,
      rightward ? lead : trail,
    )!;
    final double top = ui.lerpDouble(from.top, to.top, lead)!;
    final double bottom = ui.lerpDouble(from.bottom, to.bottom, lead)!;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  static void _drawPlate(
    Canvas canvas,
    Rect slot,
    HyprPlateStyle style,
    double opacity,
  ) {
    final Rect rect = style.inflate.inflateRect(slot);
    final RRect shape = RRect.fromRectAndRadius(
      rect,
      Radius.circular(style.radius),
    );
    if (style.glow.a > 0 && style.glowBlur > 0) {
      canvas.drawRRect(
        shape,
        Paint()
          ..color = style.glow.withValues(alpha: style.glow.a * opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.outer, style.glowBlur),
      );
    }
    final Gradient? gradient = style.gradient;
    canvas.drawRRect(
      shape,
      gradient == null
          ? (Paint()
              ..color = style.fill.withValues(alpha: style.fill.a * opacity))
          : (Paint()
              ..shader = gradient.createShader(rect)
              ..color = Color.fromRGBO(0, 0, 0, opacity)),
    );
    if (style.borderWidth > 0 && style.border.a > 0) {
      canvas.drawRRect(
        shape.deflate(style.borderWidth / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = style.borderWidth
          ..color = style.border.withValues(alpha: style.border.a * opacity),
      );
    }
  }
}
