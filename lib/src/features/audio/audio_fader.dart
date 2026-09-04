import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'audio_chrome.dart';

/// Fixed geometry of one fader, shared by its painter and its hit testing.
///
/// [handleCenterY] and [valueForY] are exact inverses. Deriving one without the
/// other is what let a plain press on the handle move the value.
abstract final class AudioFaderMetrics {
  static const double width = 41;
  static const double height = 152;
  static const double meterWidth = 6;
  static const double trackLeft = 15;
  static const double trackWidth = width - trackLeft;
  static const double handleHeight = 15;
  static const double slotWidth = 6;
  static const int meterSegments = 24;

  static double _travel(double height) =>
      math.max(0, height - handleHeight);

  static double handleCenterY(double value, double height) =>
      handleHeight / 2 + (1 - value.clamp(0, 1)) * _travel(height);

  static double valueForY(double y, double height) {
    final double travel = _travel(height);
    if (travel <= 0) {
      return 1;
    }
    return (1 - (y - handleHeight / 2) / travel).clamp(0, 1).toDouble();
  }
}

class AudioFader extends StatefulWidget {
  const AudioFader({
    super.key,
    required this.endpoint,
    required this.accent,
    required this.onPreviewVolume,
    required this.onSetVolume,

    /// Live signal level for the meter ladder, independent of the fader
    /// position. The landing page animates demonstration levels through
    /// this; the bar leaves it null so the ladder follows the volume.
    this.meterLevel,
  });

  final AudioEndpoint endpoint;
  final Color accent;
  final ValueChanged<int> onPreviewVolume;
  final void Function(AudioEndpointKind kind, int volume) onSetVolume;
  final double? meterLevel;

  @override
  State<AudioFader> createState() => AudioFaderState();
}

class AudioFaderState extends State<AudioFader> {
  late double _volume;
  late final HyprLiveValue _commits;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _volume = widget.endpoint.volume.toDouble();
    _commits = HyprLiveValue(
      initialValue: widget.endpoint.volume,
      commitInterval: HyprDurations.commit,
    );
  }

  @override
  void didUpdateWidget(covariant AudioFader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_commits.active &&
        (oldWidget.endpoint.volume != widget.endpoint.volume ||
            oldWidget.endpoint.id != widget.endpoint.id)) {
      _volume = widget.endpoint.volume.toDouble();
      _commits.sync(widget.endpoint.volume);
    }
  }

  void _setFromLocalPosition(
    Offset position,
    Size size, {
    bool send = false,
    bool force = false,
  }) {
    final double next = AudioFaderMetrics.valueForY(
      position.dy,
      size.height,
    );
    final int volume = (next * 100).round();
    setState(() => _volume = volume.toDouble());
    widget.onPreviewVolume(volume);
    if (send) {
      _sendVolume(force: force);
    }
  }

  void _sendVolume({bool force = false}) {
    final int volume = _volume.round();
    _commits.preview(volume);
    final int? next = _commits.commit(force: force);
    if (next != null) {
      widget.onSetVolume(widget.endpoint.kind, next);
    }
  }

  void _nudge(int delta) {
    setState(
      () => _volume = (_volume + delta).clamp(0, 100).toDouble(),
    );
    widget.onPreviewVolume(_volume.round());
    _sendVolume(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final AudioEndpoint endpoint = widget.endpoint;
    final HyprLevelRamp ramp = HyprLevelRamp.audio.withNominal(widget.accent);
    return Semantics(
      slider: true,
      label: '${endpoint.name} volume',
      value: _volume.round().toString(),
      increasedValue: math.min(100, _volume.round() + 5).toString(),
      decreasedValue: math.max(0, _volume.round() - 5).toString(),
      onIncrease: () => _nudge(5),
      onDecrease: () => _nudge(-5),
      child: SizedBox(
        width: AudioFaderMetrics.width,
        height: AudioFaderMetrics.height,
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: AudioFaderMetrics.meterWidth,
              child: CustomPaint(
                painter: HyprSegmentedMeterPainter(
                  value: endpoint.muted ? 0 : (widget.meterLevel ?? _volume / 100),
                  ramp: ramp,
                  segments: AudioFaderMetrics.meterSegments,
                  direction: HyprMeterDirection.bottomToTop,
                  segmentRadius: 1.5,
                  trackColor: AudioMixerColors.rail,
                  trackBorderColor: AudioMixerColors.railBorder,
                ),
              ),
            ),
            Positioned(
              left: AudioFaderMetrics.trackLeft,
              top: 0,
              right: 0,
              bottom: 0,
              child: _FaderTrack(
                value: _volume / 100,
                ramp: ramp,
                emphasized: _hovered || _commits.active,
                muted: endpoint.muted,
                onHoverChanged: (bool hovered) =>
                    setState(() => _hovered = hovered),
                onPreview: _setFromLocalPosition,
                onBegin: () => setState(() => _commits.begin(_volume.round())),
                onEnd: () {
                  setState(() => _commits.end());
                  _sendVolume(force: true);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The grabbable part of a fader. Hit testing stops at the track edge so the
/// level ladder beside it stays a readout rather than a control.
class _FaderTrack extends StatelessWidget {
  const _FaderTrack({
    required this.value,
    required this.ramp,
    required this.emphasized,
    required this.muted,
    required this.onHoverChanged,
    required this.onPreview,
    required this.onBegin,
    required this.onEnd,
  });

  final double value;
  final HyprLevelRamp ramp;
  final bool emphasized;
  final bool muted;
  final ValueChanged<bool> onHoverChanged;
  final void Function(Offset position, Size size, {bool send, bool force})
  onPreview;
  final VoidCallback onBegin;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size size = constraints.biggest;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (TapDownDetails details) => onPreview(
              details.localPosition,
              size,
              send: true,
              force: true,
            ),
            onVerticalDragStart: (DragStartDetails details) {
              onBegin();
              onPreview(
                details.localPosition,
                size,
                send: true,
                force: true,
              );
            },
            onVerticalDragUpdate: (DragUpdateDetails details) =>
                onPreview(details.localPosition, size, send: true),
            onVerticalDragEnd: (_) => onEnd(),
            onVerticalDragCancel: onEnd,
            child: CustomPaint(
              painter: AudioFaderPainter(
                value: value,
                ramp: ramp,
                emphasized: emphasized,
                highlight: context.hyprPalette.accentSoft,
                muted: muted,
              ),
            ),
          );
        },
      ),
    );
  }
}

class AudioDisabledFader extends StatelessWidget {
  const AudioDisabledFader({super.key, required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final HyprLevelRamp ramp = HyprLevelRamp.audio.withNominal(accent);
    return SizedBox(
      width: AudioFaderMetrics.width,
      height: AudioFaderMetrics.height,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: AudioFaderMetrics.meterWidth,
            child: CustomPaint(
              painter: HyprSegmentedMeterPainter(
                value: 0,
                ramp: ramp,
                segments: AudioFaderMetrics.meterSegments,
                direction: HyprMeterDirection.bottomToTop,
                segmentRadius: 1.5,
                trackColor: AudioMixerColors.rail,
                trackBorderColor: AudioMixerColors.railBorder,
              ),
            ),
          ),
          Positioned(
            left: AudioFaderMetrics.trackLeft,
            top: 0,
            right: 0,
            bottom: 0,
            child: CustomPaint(
              painter: AudioFaderPainter(
                value: 0,
                ramp: ramp,
                emphasized: false,
                highlight: context.hyprPalette.accentSoft,
                muted: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the slot, level fill and handle of one fader.
class AudioFaderPainter extends CustomPainter {
  const AudioFaderPainter({
    required this.value,
    required this.ramp,
    required this.emphasized,
    required this.highlight,
    required this.muted,
  });

  final double value;
  final HyprLevelRamp ramp;
  final bool emphasized;

  /// The UI accent, distinct from [accent], which identifies the channel.
  /// Taken from the palette so it follows the configured hue.
  final Color highlight;
  final bool muted;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect track = Offset.zero & size;
    final Rect slot = Rect.fromCenter(
      center: track.center,
      width: AudioFaderMetrics.slotWidth,
      height: track.height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(slot, const Radius.circular(3)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF15161A), Color(0xFF222329)],
        ).createShader(slot),
    );

    final double handleCenterY = AudioFaderMetrics.handleCenterY(
      value,
      track.height,
    );
    final Color levelColor = ramp.colorAt(value.clamp(0, 1));
    if (!muted) {
      final Rect fill = Rect.fromLTRB(
        slot.center.dx - 1,
        handleCenterY,
        slot.center.dx + 1,
        slot.bottom,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(fill, const Radius.circular(1)),
        Paint()..color = levelColor,
      );
    }

    final Rect handleRect = Rect.fromCenter(
      center: Offset(track.center.dx, handleCenterY),
      width: AudioFaderMetrics.trackWidth,
      height: AudioFaderMetrics.handleHeight,
    );
    final RRect handle = RRect.fromRectAndRadius(
      handleRect,
      const Radius.circular(3.5),
    );
    canvas.drawRRect(
      handle,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.42)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRRect(handle, Paint()..color = AudioMixerColors.handle);
    canvas.drawRRect(
      handle.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = emphasized ? 1 : 0.75
        ..color = emphasized ? highlight : AudioMixerColors.handleBorder,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: handleRect.center, width: 20, height: 1),
        const Radius.circular(1.5),
      ),
      Paint()..color = muted ? HyprColors.textFaint : levelColor,
    );
  }

  @override
  bool shouldRepaint(covariant AudioFaderPainter oldDelegate) {
    return value != oldDelegate.value ||
        ramp != oldDelegate.ramp ||
        emphasized != oldDelegate.emphasized ||
        highlight != oldDelegate.highlight ||
        muted != oldDelegate.muted;
  }
}
