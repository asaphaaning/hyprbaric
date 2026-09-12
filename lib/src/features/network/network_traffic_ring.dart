import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'network_console.dart';
import 'network_traffic_history.dart';

/// Two independently scaled traces with age increasing clockwise from NOW.
///
/// The outer band is download (0–60 Mbps); the inner is upload (0–10 Mbps).
/// Values above the fixed scales clip visually while the readouts stay exact.
class NetworkTrafficRing extends StatelessWidget {
  const NetworkTrafficRing({super.key, required this.history});

  final TrafficHistory history;

  @override
  Widget build(BuildContext context) {
    final latest = history.latest;
    return Semantics(
      label:
          'Traffic over the last 60 seconds. Newest at the top; older clockwise. '
          'Download ${latest?.download.toStringAsFixed(1) ?? "unavailable"} Mbps. '
          'Upload ${latest?.upload.toStringAsFixed(1) ?? "unavailable"} Mbps.',
      child: AspectRatio(
        aspectRatio: 396 / 344,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = constraints.maxWidth / 396;
            return Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: TrafficRingPainter(history: history),
                      isComplex: true,
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Text(
                    'NOW',
                    textAlign: TextAlign.center,
                    style: NetworkConsole.body.copyWith(
                      fontSize: 10.5 * scale,
                      height: 1,
                      letterSpacing: 1.1,
                      color: const Color(0xFFE1C2FF),
                    ),
                  ),
                ),
                for (final tick in const [
                  (label: '15s', left: 358.0, top: 157.0),
                  (label: '30s', left: 188.0, top: 322.0),
                  (label: '45s', left: 16.0, top: 157.0),
                ])
                  Positioned(
                    left: tick.left * scale,
                    top: tick.top * scale,
                    child: Text(
                      tick.label,
                      style: NetworkConsole.body.copyWith(
                        fontSize: 11.5 * scale,
                      ),
                    ),
                  ),
                Positioned(
                  top: 110 * scale,
                  left: 126 * scale,
                  width: 144 * scale,
                  child: Column(
                    children: [
                      Text(
                        'LIVE TRAFFIC',
                        style: NetworkConsole.label.copyWith(
                          fontSize: 10 * scale,
                          letterSpacing: 1.35 * scale,
                          color: NetworkConsole.muted,
                        ),
                      ),
                      SizedBox(height: 6 * scale),
                      _Rate(
                        value: latest?.download,
                        color: NetworkConsole.downloadText,
                        down: true,
                        scale: scale,
                      ),
                      Container(
                        margin: EdgeInsets.symmetric(vertical: 6 * scale),
                        height: .5,
                        width: 80 * scale,
                        color: const Color(0x88536D9F),
                      ),
                      _Rate(
                        value: latest?.upload,
                        color: NetworkConsole.uploadText,
                        down: false,
                        scale: scale,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Rate extends StatelessWidget {
  const _Rate({
    required this.value,
    required this.color,
    required this.down,
    required this.scale,
  });
  final double? value;
  final Color color;
  final bool down;
  final double scale;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        width: 136 * scale,
        height: 33 * scale,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                down
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: color,
                size: 27 * scale,
              ),
              SizedBox(width: 5 * scale),
              Text(
                value?.toStringAsFixed(1) ?? '—',
                style: NetworkConsole.body.copyWith(
                  fontSize: 30 * scale,
                  height: 1.08,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
      Text(
        'Mbps',
        style: NetworkConsole.body.copyWith(fontSize: 12 * scale, color: color),
      ),
    ],
  );
}

/// Paint-only projection of [TrafficHistory]; it never invents past samples.
class TrafficRingPainter extends CustomPainter {
  const TrafficRingPainter({required this.history});
  final TrafficHistory history;

  static const _center = Offset(198, 165);
  static const _gap = .045;

  Offset _point(double radius, double angle) =>
      _center + Offset(math.sin(angle), -math.cos(angle)) * radius;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 396);
    // Keep the central readout distinct from the blue light under the rings.
    canvas.drawCircle(
      _center,
      74.5,
      Paint()
        ..shader = ui.Gradient.radial(
          _center - const Offset(0, 25),
          110,
          const [Color(0xED0B0F19), Color(0x99101726)],
        ),
    );
    _track(canvas, 105, 146, NetworkConsole.download);
    _track(canvas, 75, 103, NetworkConsole.upload);
    _trace(
      canvas,
      inner: 105,
      outer: 146,
      maximum: 60,
      color: NetworkConsole.download,
      rate: (sample) => sample.download,
    );
    _trace(
      canvas,
      inner: 75,
      outer: 103,
      maximum: 10,
      color: NetworkConsole.upload,
      rate: (sample) => sample.upload,
    );

    for (final radius in [152.0, 102.0]) {
      for (var index = 1; index < 240; index++) {
        final angle = index / 240 * math.pi * 2;
        if (angle < .095 || angle > math.pi * 2 - .095) continue;
        canvas.drawCircle(
          _point(radius, angle),
          .48,
          Paint()
            ..color = radius == 152
                ? const Color(0xC9C2B4FB)
                : const Color(0xA9FC9DD8),
        );
      }
    }
    for (final angle in [math.pi / 2, math.pi, math.pi * 1.5]) {
      canvas.drawLine(
        _point(146, angle),
        _point(152, angle),
        Paint()
          ..color = NetworkConsole.download
          ..strokeWidth = .8,
      );
    }
    canvas.drawLine(
      const Offset(198, 16),
      const Offset(198, 90),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(198, 16),
          const Offset(198, 90),
          const [Color(0xFFE4BDFF), Color(0x555794C1)],
        )
        ..strokeWidth = .8,
    );
    if (history.latest != null) {
      canvas.drawCircle(
        const Offset(198, 15),
        4,
        Paint()
          ..color = NetworkConsole.download
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(
        const Offset(198, 15),
        2.9,
        Paint()..color = const Color(0xFFF4D9FF),
      );
    }
    canvas.restore();
  }

  void _track(Canvas canvas, double inner, double outer, Color color) {
    final path = Path()
      ..addArc(
        Rect.fromCircle(center: _center, radius: outer),
        -math.pi / 2 + _gap,
        2 * math.pi - 2 * _gap,
      )
      ..arcTo(
        Rect.fromCircle(center: _center, radius: inner),
        -math.pi / 2 - _gap,
        -2 * math.pi + 2 * _gap,
        false,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: .055));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .45
        ..color = color.withValues(alpha: .35),
    );
  }

  void _trace(
    Canvas canvas, {
    required double inner,
    required double outer,
    required double maximum,
    required Color color,
    required double Function(TrafficSample) rate,
  }) {
    if (history.samples.length < 2) return;
    final samples = history.samples.reversed.toList(growable: false);
    final extent =
        history.extent.inMicroseconds /
        TrafficHistory.window.inMicroseconds *
        2 *
        math.pi;
    final end = math.min(2 * math.pi - _gap, extent);
    if (end <= _gap) return;
    final points = <Offset>[];
    var segment = 0;
    final count = math.max(2, (end * 80).ceil());
    for (var index = 0; index <= count; index++) {
      final angle = _gap + (end - _gap) * index / count;
      final age = angle / (2 * math.pi) * 60;
      final time = samples.first.at.inMicroseconds / 1e6 - age;
      while (segment < samples.length - 2 &&
          samples[segment + 1].at.inMicroseconds / 1e6 > time) {
        segment++;
      }
      final newer = samples[segment];
      final older = samples[segment + 1];
      final span = (newer.at - older.at).inMicroseconds / 1e6;
      final fraction = span <= 0
          ? 0.0
          : ((newer.at.inMicroseconds / 1e6 - time) / span).clamp(0.0, 1.0);
      // Smooth interpolation stays between actual observations (no overshoot).
      final blend = fraction * fraction * (3 - 2 * fraction);
      final value = rate(newer) + (rate(older) - rate(newer)) * blend;
      points.add(
        _point(
          inner + (outer - inner) * (value / maximum).clamp(0.0, 1.0),
          angle,
        ),
      );
    }
    final crest = Path()..addPolygon(points, false);
    final fill = Path.from(crest)
      ..lineTo(_point(inner, end).dx, _point(inner, end).dy)
      ..arcTo(
        Rect.fromCircle(center: _center, radius: inner),
        end - math.pi / 2,
        -(end - _gap),
        false,
      )
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = ui.Gradient.radial(
          _center,
          outer,
          [
            color.withValues(alpha: .05),
            color.withValues(alpha: .14),
            color.withValues(alpha: .95),
          ],
          [0, inner / outer, 1],
        ),
    );
    canvas.drawPath(
      crest,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = color.withValues(alpha: .65)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      crest,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.drawPath(
      crest,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .65
        ..color = Color.lerp(color, Colors.white, .28)!,
    );
  }

  @override
  bool shouldRepaint(TrafficRingPainter oldDelegate) =>
      oldDelegate.history != history;
}
