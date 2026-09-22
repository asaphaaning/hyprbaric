import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../widgets/hypr_surface.dart';
import 'system_level.dart';

/// Analog CPU face. Occupancy rides a −30 dB to 0 dB arc, and the needle
/// rotates around a concealed pivot below the smoked glass.
///
/// The needle eases toward [ratio] with [NeedleMotion], so successive host
/// samples sweep instead of stepping.
class SystemGauge extends StatefulWidget {
  const SystemGauge({
    super.key,
    required this.ratio,
    this.label = 'CPU',
    this.width = 236,
    this.height = 168,
  });

  /// Occupancy as a `0..=1` fraction of full scale.
  final double ratio;
  final String label;
  final double width;
  final double height;

  @override
  State<SystemGauge> createState() => _SystemGaugeState();
}

class _SystemGaugeState extends State<SystemGauge>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final ValueNotifier<double> _position;
  Duration? _previousTick;
  double _velocity = 0;

  double get _target => widget.ratio.clamp(0, 1).toDouble();

  bool get _settled =>
      (_target - _position.value).abs() < 0.0005 && _velocity.abs() < 0.001;

  @override
  void initState() {
    super.initState();
    _position = ValueNotifier(_target);
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _followTarget();
  }

  @override
  void didUpdateWidget(SystemGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _followTarget();
  }

  void _followTarget() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _position.value = _target;
      _velocity = 0;
      _ticker.stop();
      return;
    }
    if (_settled || _ticker.isActive) {
      return;
    }
    _previousTick = null;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final Duration? previous = _previousTick;
    _previousTick = elapsed;
    if (previous == null) {
      return;
    }

    final double dt = ((elapsed - previous).inMicroseconds / 1000000).clamp(
      0.0,
      0.032,
    );
    final ({double position, double velocity}) next = NeedleMotion.step(
      position: _position.value,
      velocity: _velocity,
      target: _target,
      dt: dt,
    );
    if ((_target - next.position).abs() < 0.0005 &&
        next.velocity.abs() < 0.001) {
      _position.value = _target;
      _velocity = 0;
      _ticker.stop();
      return;
    }

    _position.value = next.position;
    _velocity = next.velocity;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const RepaintBoundary(
            child: CustomPaint(painter: _GaugeFacePainter()),
          ),
          RepaintBoundary(
            child: CustomPaint(painter: _GaugeMotionPainter(_position)),
          ),
          RepaintBoundary(
            child: CustomPaint(painter: _GaugeChromePainter(widget.label)),
          ),
        ],
      ),
    );
  }
}

const _gaugeArt = _GaugeArt();

class _GaugeFacePainter extends CustomPainter {
  const _GaugeFacePainter();

  @override
  void paint(Canvas canvas, Size size) => _gaugeArt.paintFace(canvas, size);

  @override
  bool shouldRepaint(covariant _GaugeFacePainter oldDelegate) => false;
}

class _GaugeMotionPainter extends CustomPainter {
  _GaugeMotionPainter(this.position) : super(repaint: position);

  final ValueListenable<double> position;

  @override
  void paint(Canvas canvas, Size size) =>
      _gaugeArt.paintMotion(canvas, size, position.value);

  @override
  bool shouldRepaint(covariant _GaugeMotionPainter oldDelegate) =>
      oldDelegate.position != position;
}

class _GaugeChromePainter extends CustomPainter {
  const _GaugeChromePainter(this.label);

  final String label;

  @override
  void paint(Canvas canvas, Size size) =>
      _gaugeArt.paintChrome(canvas, size, label);

  @override
  bool shouldRepaint(covariant _GaugeChromePainter oldDelegate) =>
      oldDelegate.label != label;
}

class _GaugeArt {
  const _GaugeArt();

  static const Size _faceSize = Size(320, 204);
  static final RRect _face = RRect.fromRectAndRadius(
    const Rect.fromLTWH(1, 1, 318, 202),
    const Radius.circular(26),
  );
  static const Offset _pivot = Offset(160, 350);
  static const double _radius = 282;

  /// A concealed pivot gives the scale its shallow instrument arc.
  static const double _startAngle = 246 * math.pi / 180;
  static const double _sweepAngle = 48 * math.pi / 180;

  static const Color _lamp = Color(0xFFFF5A0A);
  static const Color _needle = Color(0xFFFF6414);
  static const Color _scale = Color(0x506F625B);

  void paintFace(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _faceSize.width, size.height / _faceSize.height);
    canvas.clipRRect(_face);
    _paintGlass(canvas, _faceSize, _pivot);
    _paintScale(canvas, _faceSize, _pivot, _radius);
    canvas.restore();
  }

  void paintMotion(Canvas canvas, Size size, double ratio) {
    canvas.save();
    canvas.scale(size.width / _faceSize.width, size.height / _faceSize.height);
    canvas.clipRRect(_face);
    _paintNeedle(canvas, _pivot, _radius, ratio);
    _paintReadout(
      canvas,
      origin: const Offset(28, 0),
      alignRight: false,
      size: _faceSize,
      caption: 'USAGE',
      value: '${(ratio * 100).round()}%',
    );
    canvas.restore();
  }

  void paintChrome(Canvas canvas, Size size, String label) {
    canvas.save();
    canvas.scale(size.width / _faceSize.width, size.height / _faceSize.height);
    canvas.save();
    canvas.clipRRect(_face);
    _paintCentre(canvas, _pivot, label);
    _paintReadout(
      canvas,
      origin: Offset.zero,
      alignRight: true,
      size: _faceSize,
      caption: 'MAX',
      value: '100%',
    );
    _paintReflection(canvas, _faceSize);
    canvas.restore();
    _paintRim(canvas, _face);
    canvas.restore();
  }

  void _paintGlass(Canvas canvas, Size size, Offset pivot) {
    final Rect bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = ui.Gradient.linear(
          bounds.topCenter,
          bounds.bottomCenter,
          const <Color>[Color(0xFF262527), Color(0xFF291C17)],
        ),
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(pivot.dx - 12, size.height * 1.15),
          size.width * 0.68,
          const <Color>[
            Color(0xC0BA3C0C),
            Color(0x806D240C),
            Color(0x302F160E),
            Color(0x002F160E),
          ],
          const <double>[0, 0.32, 0.7, 1],
        ),
    );
  }

  /// Broad reflections sit on the glass; the perimeter stays a fine hairline.
  void _paintReflection(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = ui.Gradient.radial(const Offset(8, -28), 180, const <Color>[
          Color(0x18DDE2EB),
          Color(0x00DDE2EB),
        ]),
    );
    final Path reflection = Path()
      ..moveTo(284, 0)
      ..lineTo(320, 0)
      ..lineTo(320, 138)
      ..lineTo(225, 85)
      ..close();
    canvas.drawPath(
      reflection,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
        ..shader = ui.Gradient.linear(
          const Offset(310, 0),
          const Offset(266, 100),
          const <Color>[Color(0x08DFE6F0), Color(0x00DFE6F0)],
        ),
    );
  }

  void _paintRim(Canvas canvas, RRect face) {
    canvas.drawRRect(
      face,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = const Color(0xB0101114),
    );
    canvas.drawRRect(
      face.deflate(0.9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..shader = ui.Gradient.linear(
          face.outerRect.topLeft,
          face.outerRect.bottomRight,
          const <Color>[
            Color(0x65C2C4C8),
            Color(0x126F6663),
            Color(0x306F4231),
            Color(0x284E4240),
          ],
          const <double>[0, 0.35, 0.8, 1],
        ),
    );
    canvas.drawRRect(
      face.deflate(2.2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x106E747F)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
    );
  }

  void _paintScale(Canvas canvas, Size size, Offset pivot, double radius) {
    final Rect arc = Rect.fromCircle(center: pivot, radius: radius);
    canvas.drawArc(
      arc,
      _startAngle - 0.08,
      _sweepAngle + 0.16,
      false,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(28, 0),
          const Offset(292, 0),
          const <Color>[
            Color(0x006F625B),
            Color(0x807E6255),
            Color(0x607E6255),
            Color(0x006F625B),
          ],
          const <double>[0, 0.3, 0.65, 1],
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15
        ..strokeCap = StrokeCap.round,
    );

    final Paint tick = Paint()
      ..color = _scale
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round;
    for (final double db in AnalogLevel.ticks) {
      final double angle = _angleForDb(db);
      final Offset direction = _direction(angle);
      final Offset onArc = pivot + direction * radius;
      canvas.drawLine(onArc + direction * 16, onArc - direction * 14, tick);

      final String text = db == 0 ? '0' : db.toStringAsFixed(0);
      final TextPainter painter = _text(
        text,
        HyprInstrumentText.meta.copyWith(
          color: const Color(0xFFB3ADB0),
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      );
      final Offset origin = pivot + direction * (radius + 28);
      final double left = (origin.dx - painter.width / 2)
          .clamp(10.0, size.width - painter.width - 10)
          .toDouble();
      final double top = (origin.dy - painter.height / 2)
          .clamp(6.0, size.height - painter.height - 6)
          .toDouble();
      painter.paint(canvas, Offset(left, top));
    }
  }

  void _paintNeedle(Canvas canvas, Offset pivot, double radius, double ratio) {
    final double angle = _startAngle + _sweepAngle * AnalogLevel.sweep(ratio);
    final Offset tip = pivot + _direction(angle) * (radius + 12);
    canvas.drawLine(
      pivot,
      tip,
      Paint()
        ..color = _lamp.withValues(alpha: 0.45)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawLine(
      pivot,
      tip,
      Paint()
        ..color = _needle
        ..strokeWidth = 1.9
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintCentre(Canvas canvas, Offset pivot, String label) {
    final TextPainter title = _text(
      label,
      HyprInstrumentText.body.copyWith(
        color: const Color(0xFFC4B7B3),
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.6,
      ),
    );
    title.paint(
      canvas,
      Offset(pivot.dx - title.width / 2, 133 - title.height / 2),
    );
  }

  void _paintReadout(
    Canvas canvas, {
    required Offset origin,
    required bool alignRight,
    required Size size,
    required String caption,
    required String value,
  }) {
    final TextPainter label = _text(
      caption,
      HyprInstrumentText.meta.copyWith(
        color: const Color(0xFFABA1A0),
        fontSize: 10,
        letterSpacing: 0.3,
      ),
    );
    final TextPainter amount = _text(
      value,
      HyprInstrumentText.body.copyWith(
        color: const Color(0xFFC5BABC),
        fontSize: 17,
        fontWeight: FontWeight.w400,
      ),
    );
    final double block = label.height + 2 + amount.height;
    final double top = size.height - block - 18;
    final double labelLeft = alignRight
        ? size.width - 28 - label.width
        : origin.dx;
    final double amountLeft = alignRight
        ? size.width - 28 - amount.width
        : origin.dx;
    label.paint(canvas, Offset(labelLeft, top));
    amount.paint(canvas, Offset(amountLeft, top + label.height + 2));
  }

  double _angleForDb(double db) {
    final double sweep =
        (db - AnalogLevel.floorDb) /
        (AnalogLevel.ceilingDb - AnalogLevel.floorDb);
    return _startAngle + _sweepAngle * sweep;
  }

  Offset _direction(double angle) {
    return Offset(math.cos(angle), math.sin(angle));
  }

  TextPainter _text(String value, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
  }
}
