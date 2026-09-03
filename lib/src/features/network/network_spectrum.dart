import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../bindings/bindings.dart' hide listEquals;
import '../../widgets/hypr_surface.dart';
import 'network_chrome.dart';
import 'network_formatting.dart';

class NetworkSpectrumPanel extends StatelessWidget {
  const NetworkSpectrumPanel({
    super.key,
    required this.uploadHistory,
    required this.downloadHistory,
    this.window,
  });

  final List<double> uploadHistory;
  final List<double> downloadHistory;

  /// The real time the samples span, measured by the panel that collects them.
  ///
  /// The poll cadence is configurable, so the axis cannot be labelled from the
  /// sample count alone.
  final Duration? window;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: HyprGlassFrame(
        fill: const Color(0xEB07080A),
        vignette: true,
        child: SizedBox.expand(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: CustomPaint(
                  painter: NetworkSpectrumPainter(
                    uploadHistory: uploadHistory,
                    downloadHistory: downloadHistory,
                  ),
                ),
              ),
              const Positioned(
                left: 9,
                top: 7,
                child: _ScopeLabel('TX', color: NetworkMenuColors.tx),
              ),
              const Positioned(
                left: 9,
                bottom: 7,
                child: _ScopeLabel('RX', color: NetworkMenuColors.rx),
              ),
              Positioned(
                right: 9,
                bottom: 7,
                child: Text(
                  _windowLabel(window),
                  style: HyprTypography.compactMono.copyWith(
                    color: NetworkMenuColors.fg3.withValues(alpha: 0.62),
                    fontSize: HyprTypography.size(7.5),
                    letterSpacing: 0.9,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formats the scope's time base, or a placeholder until it can be measured.
String _windowLabel(Duration? window) {
  if (window == null || window.inSeconds < 1) {
    return '--';
  }
  if (window.inSeconds < 90) {
    return '${window.inSeconds} s';
  }
  return '${window.inMinutes} min';
}

class _ScopeLabel extends StatelessWidget {
  const _ScopeLabel(this.label, {required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: HyprTypography.compactMonoStrong.copyWith(
        color: color,
        fontSize: HyprTypography.size(7.5),
        fontWeight: FontWeight.w700,
        letterSpacing: 1.35,
        height: 1,
      ),
    );
  }
}

class NetworkParameterBank extends StatelessWidget {
  const NetworkParameterBank({
    super.key,
    required this.traffic,
    required this.interface,
  });

  final NetworkTraffic traffic;
  final NetworkInterface? interface;

  @override
  Widget build(BuildContext context) {
    final double upload = megabytesPerSecond(traffic.upload.bytesPerSecond);
    final double download = megabytesPerSecond(traffic.download.bytesPerSecond);
    final int? latency = traffic.pingMs;

    return Column(
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: NetworkParameter(
                label: 'Upstream',
                value: '${upload.toStringAsFixed(2)} MB/s',
                detail: '${formatBytes(traffic.upload.totalBytes)} sent',
                progress: (upload / 32).clamp(0, 1),
                tone: NetworkParameterTone.tx,
              ),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: NetworkParameter(
                label: 'Downstream',
                value: '${download.toStringAsFixed(2)} MB/s',
                detail: '${formatBytes(traffic.download.totalBytes)} received',
                progress: (download / 32).clamp(0, 1),
                tone: NetworkParameterTone.rx,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: NetworkParameter(
                label: 'Latency',
                value: latency == null ? '—' : '$latency ms',
                detail: 'round trip',
                progress: latency == null ? 0 : (latency * 0.014).clamp(0, 1),
                tone: NetworkParameterTone.rx,
              ),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: NetworkParameter(
                label: 'Interface',
                value: interface?.name ?? '—',
                detail: interface?.address ?? 'link unavailable',
                tone: NetworkParameterTone.rx,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum NetworkParameterTone { tx, rx }

class NetworkParameter extends StatelessWidget {
  const NetworkParameter({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
    required this.tone,
    this.progress,
  });

  final String label;
  final String value;
  final String detail;
  final NetworkParameterTone tone;
  final double? progress;

  Color get _tone => switch (tone) {
    NetworkParameterTone.tx => NetworkMenuColors.tx,
    NetworkParameterTone.rx => NetworkMenuColors.rx,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 7, 0, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x0DFFFFFF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                label,
                style: HyprTypography.popRow.copyWith(
                  color: NetworkMenuColors.fg1,
                  fontSize: HyprTypography.size(11),
                  letterSpacing: 0.11,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: HyprTypography.compactMonoStrong.copyWith(
                    color: _tone,
                    fontSize: HyprTypography.size(11),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                    height: 1.12,
                    fontFeatures: HyprTypography.tabularNumbers,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          if (progress != null)
            _ParameterRail(progress: progress!, color: _tone)
          else
            const SizedBox(height: 2),
          const SizedBox(height: 5),
          Text(
            detail.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HyprTypography.compactMono.copyWith(
              color: NetworkMenuColors.fg3.withValues(alpha: 0.68),
              fontSize: HyprTypography.size(8),
              letterSpacing: 0.64,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParameterRail extends StatelessWidget {
  const _ParameterRail({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: color.withValues(alpha: 0.50),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: constraints.maxWidth * progress.clamp(0, 1),
                    height: 2,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class NetworkSpectrumPainter extends CustomPainter {
  const NetworkSpectrumPainter({
    required this.uploadHistory,
    required this.downloadHistory,
  });

  final List<double> uploadHistory;
  final List<double> downloadHistory;

  @override
  void paint(Canvas canvas, Size size) {
    // No base fill: the glass frame behind supplies the surface, and an
    // opaque rect here would bury its sheen and rim light.
    final Paint grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 17) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final double midY = size.height / 2;
    final Paint center = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 6) {
      canvas.drawLine(
        Offset(x, midY),
        Offset(math.min(x + 3, size.width), midY),
        center,
      );
    }

    _drawHistory(
      canvas,
      size,
      samples: uploadHistory,
      maximum: 6,
      color: NetworkMenuColors.tx,
      up: true,
    );
    _drawHistory(
      canvas,
      size,
      samples: downloadHistory,
      maximum: 16,
      color: NetworkMenuColors.rx,
      up: false,
    );
  }

  void _drawHistory(
    Canvas canvas,
    Size size, {
    required List<double> samples,
    required double maximum,
    required Color color,
    required bool up,
  }) {
    if (samples.length < 2) {
      return;
    }
    const double pad = 6;
    final double midY = size.height / 2;
    final double height = midY - pad - 2;
    final List<Offset> points = <Offset>[
      for (int index = 0; index < samples.length; index += 1)
        Offset(
          pad + (size.width - pad * 2) * index / (samples.length - 1),
          midY +
              (up ? -1 : 1) * (samples[index] / maximum).clamp(0, 1) * height,
        ),
    ];
    final Path line = _spline(points);
    final Path fill = Path()
      ..moveTo(points.first.dx, midY)
      ..lineTo(points.first.dx, points.first.dy);
    _appendSpline(fill, points);
    fill
      ..lineTo(points.last.dx, midY)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: up ? Alignment.topCenter : Alignment.bottomCenter,
          end: Alignment.center,
          colors: <Color>[
            color.withValues(alpha: 0.35),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color.withValues(alpha: 0.46)
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  Path _spline(List<Offset> points) {
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    _appendSpline(path, points);
    return path;
  }

  void _appendSpline(Path path, List<Offset> points) {
    for (int index = 0; index < points.length - 1; index += 1) {
      final Offset current = points[index];
      final Offset next = points[index + 1];
      final double midpoint = (current.dx + next.dx) / 2;
      path.quadraticBezierTo(
        current.dx,
        current.dy,
        midpoint,
        (current.dy + next.dy) / 2,
      );
    }
    path.lineTo(points.last.dx, points.last.dy);
  }

  @override
  bool shouldRepaint(covariant NetworkSpectrumPainter oldDelegate) {
    // Compared by value. `!=` on a List is identity, which was always false
    // while the panel handed the painter the same buffer every frame.
    return !listEquals(oldDelegate.uploadHistory, uploadHistory) ||
        !listEquals(oldDelegate.downloadHistory, downloadHistory);
  }
}
