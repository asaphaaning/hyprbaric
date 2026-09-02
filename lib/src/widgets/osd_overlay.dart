import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../features/audio/audio_chrome.dart';
import '../state/transient_overlays.dart';
import 'hypr_surface.dart';

class OsdPanel extends StatefulWidget {
  const OsdPanel({super.key, required this.event});

  final OsdEvent event;

  @override
  State<OsdPanel> createState() => OsdPanelState();
}

class OsdPanelState extends State<OsdPanel> {
  static const int _segments = 32;

  Timer? _peakTimer;
  int _peak = 0;
  int _peakHold = 0;

  @override
  void initState() {
    super.initState();
    _peak = _filled;
    _startPeakTimer();
  }

  @override
  void didUpdateWidget(covariant OsdPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int filled = _filled;
    if (filled >= _peak) {
      _peak = filled;
      _peakHold = 16;
    }
  }

  @override
  void dispose() {
    _peakTimer?.cancel();
    super.dispose();
  }

  int get _filled {
    if (widget.event.muted) {
      return 0;
    }
    return ((widget.event.value.clamp(0, 100) / 100) * _segments).round().clamp(
      0,
      _segments,
    );
  }

  void _startPeakTimer() {
    _peakTimer = Timer.periodic(HyprDurations.osdPeakTick, (_) {
      if (!mounted) {
        return;
      }
      final int filled = _filled;
      if (_peak <= filled) {
        return;
      }
      if (_peakHold > 0) {
        setState(() => _peakHold -= 1);
        return;
      }
      setState(() => _peak = math.max(filled, _peak - 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final OsdEvent event = widget.event;
    final OsdReadout readout = OsdReadout.fromEvent(event);
    return HyprSurface(
      borderRadius: BorderRadius.circular(6),
      color: Colors.transparent,
      borderColor: const Color(0x80454D57),
      blur: 36,
      shadow: false,
      inset: false,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 380, maxWidth: 380),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xF20F1720), Color(0xF2090E15)],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.72),
                blurRadius: 42,
                spreadRadius: -18,
                offset: const Offset(0, 22),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.58),
                blurRadius: 0,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.08),
                blurRadius: 0,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0x0DFFFFFF)),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: <Widget>[
                            Expanded(child: OsdHeader(event: event)),
                            OsdReadoutView(readout: readout),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OsdMeter(kind: event.kind, filled: _filled, peak: _peak),
                    const SizedBox(height: 4),
                    OsdScale(kind: event.kind),
                  ],
                ),
              ),
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: OsdFramePainter()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OsdHeader extends StatelessWidget {
  const OsdHeader({super.key, required this.event});

  final OsdEvent event;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                event.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HyprTypography.compactMonoStrong.copyWith(
                  color: HyprColors.textMuted,
                  fontSize: HyprTypography.size(10),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _subLabel(event),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HyprTypography.compactMono.copyWith(
                  color: HyprColors.textFaint.withValues(alpha: 0.75),
                  fontSize: HyprTypography.size(9),
                  letterSpacing: 0.54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _subLabel(OsdEvent event) {
    if (event.muted) {
      return 'Muted';
    }
    return switch (event.kind) {
      OsdKind.volume => 'Output level',
      OsdKind.brightness => 'Display · backlight',
    };
  }
}

class OsdReadout {
  const OsdReadout({required this.value, required this.unit});

  final String value;
  final String unit;

  factory OsdReadout.fromEvent(OsdEvent event) {
    if (event.kind == OsdKind.brightness) {
      return OsdReadout(value: event.value.toString(), unit: '%');
    }
    return OsdReadout(
      value: audioDecibelReadout(event.value, muted: event.muted),
      unit: 'dB',
    );
  }
}

class OsdReadoutView extends StatelessWidget {
  const OsdReadoutView({super.key, required this.readout});

  final OsdReadout readout;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: readout.value,
        children: <InlineSpan>[
          TextSpan(
            text: ' ${readout.unit}',
            style: HyprTypography.compactMono.copyWith(
              color: HyprColors.textFaint,
              fontSize: HyprTypography.size(10),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      style: HyprTypography.compactMonoStrong.copyWith(
        color: HyprColors.text,
        fontSize: HyprTypography.size(22),
        fontWeight: FontWeight.w600,
        height: 1,
        letterSpacing: -0.44,
      ),
    );
  }
}

class OsdMeter extends StatelessWidget {
  const OsdMeter({
    super.key,
    required this.kind,
    required this.filled,
    required this.peak,
  });

  static const int _segments = 32;

  final OsdKind kind;
  final int filled;
  final int peak;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.black.withValues(alpha: 0.6)),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x66000000), blurRadius: 2),
        ],
      ),
      child: SizedBox(
        height: 14,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Row(
            children: <Widget>[
              for (int index = 0; index < _segments; index += 1) ...<Widget>[
                Expanded(
                  child: OsdSegment(
                    color: _segmentColor(kind, index),
                    active: index < filled,
                    peak: index == peak - 1 && peak > filled,
                  ),
                ),
                if (index != _segments - 1) const SizedBox(width: 2),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _segmentColor(OsdKind kind, int index) {
    final HyprLevelRamp ramp = switch (kind) {
      OsdKind.volume => HyprLevelRamp.audio,
      OsdKind.brightness => HyprLevelRamp.brightness,
    };
    return ramp.colorAt(index / _segments);
  }
}

class OsdSegment extends StatelessWidget {
  const OsdSegment({
    super.key,
    required this.color,
    required this.active,
    required this.peak,
  });

  final Color color;
  final bool active;
  final bool peak;

  @override
  Widget build(BuildContext context) {
    final Color fill = active || peak
        ? color
        : HyprColors.levelSlot;
    return AnimatedContainer(
      duration: HyprDurations.osdPeakTick,
      curve: Curves.linear,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(1),
        border: peak
            ? Border.all(color: Colors.white.withValues(alpha: 0.3))
            : null,
        boxShadow: active || peak
            ? <BoxShadow>[
                BoxShadow(
                  color: color.withValues(alpha: peak ? 0.8 : 0.7),
                  blurRadius: peak ? 5 : 4,
                ),
              ]
            : null,
      ),
    );
  }
}

class OsdScale extends StatelessWidget {
  const OsdScale({super.key, required this.kind});

  final OsdKind kind;

  @override
  Widget build(BuildContext context) {
    final List<String> labels = switch (kind) {
      // Even positions on a cubic volume curve, matching the readout.
      OsdKind.volume => <String>['-∞', '-47', '-29', '-18', '-11', '-5', '0'],
      OsdKind.brightness => <String>['0', '15', '30', '50', '70', '85', '100'],
    };
    return Row(
      children: <Widget>[
        for (int index = 0; index < labels.length; index += 1)
          Expanded(
            child: Text(
              labels[index],
              textAlign: index == 0
                  ? TextAlign.left
                  : index == labels.length - 1
                  ? TextAlign.right
                  : TextAlign.center,
              style: HyprTypography.compactMono.copyWith(
                color: index == labels.length - 1 && kind == OsdKind.volume
                    ? HyprColors.danger
                    : HyprColors.textFaint.withValues(alpha: 0.72),
                fontSize: HyprTypography.size(8.5),
                letterSpacing: 0.425,
              ),
            ),
          ),
      ],
    );
  }
}

class OsdFramePainter extends CustomPainter {
  const OsdFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x664D5963);
    const double inset = 4;
    const double length = 8;

    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset + length, inset),
      paint,
    );
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset, inset + length),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset - length, size.height - inset),
      Offset(size.width - inset, size.height - inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset - length),
      Offset(size.width - inset, size.height - inset),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant OsdFramePainter oldDelegate) => false;
}
