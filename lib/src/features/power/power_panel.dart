import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import 'power_console.dart';
import 'power_formatting.dart';
import 'power_icon.dart';
import 'power_profile_pad.dart';

/// Live battery instrument shared by the bar, Widgetbook and landing preview.
class PowerPanel extends StatelessWidget {
  const PowerPanel({
    super.key,
    required this.borderRadius,
    required this.status,
    required this.latestResult,
    required this.onSetProfile,
  });
  static const double width = 450;
  final BorderRadius borderRadius;
  final AsyncValue<PowerStatus> status;
  final PowerCommandResult? latestResult;
  final ValueChanged<PowerProfile> onSetProfile;

  @override
  Widget build(BuildContext context) {
    final snapshot = status.asData?.value;
    final message = switch (latestResult) {
      PowerCommandResultFailed(:final message) => message,
      _ => snapshot?.profileMessage ?? snapshot?.batteryMessage,
    };
    return SizedBox(
      width: width,
      child: HyprInstrumentSurface(
        borderRadius: borderRadius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(status: snapshot, loading: status.isLoading),
            if (snapshot?.batteryPresent == true) ...[
              _BatteryStage(status: snapshot, loading: status.isLoading),
              PowerBay(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: PowerMetric(
                        icon: PowerSymbol.power,
                        value: formatPowerRate(snapshot?.powerRateWatts),
                        label: 'POWER',
                      ),
                    ),
                    const _Separator(),
                    Expanded(
                      child: PowerMetric(
                        icon: PowerSymbol.voltage,
                        value: formatVoltage(snapshot?.voltage),
                        label: 'VOLTAGE',
                      ),
                    ),
                    const _Separator(),
                    Expanded(
                      child: PowerMetric(
                        icon: PowerSymbol.temperature,
                        value: formatTemperature(snapshot?.temperatureCelsius),
                        label: 'TEMP',
                      ),
                    ),
                    const _Separator(),
                    Expanded(
                      child: PowerMetric(
                        icon: PowerSymbol.battery,
                        value: batteryStateLabel(
                          snapshot?.state ?? PowerBatteryState.unknown,
                        ),
                        label: 'STATUS',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(6),
              child: PowerBay(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'POWER PROFILE',
                      style: PowerConsole.label.copyWith(
                        color: PowerConsole.text,
                        fontSize: 15,
                        letterSpacing: 3.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final profile in PowerProfile.values) ...[
                          Expanded(
                            child: PowerProfilePad(
                              profile: profile,
                              active: snapshot?.activeProfile == profile,
                              enabled:
                                  snapshot?.availableProfiles.contains(
                                    profile,
                                  ) ??
                                  false,
                              onPressed: onSetProfile,
                            ),
                          ),
                          if (profile != PowerProfile.values.last)
                            const SizedBox(width: 10),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (message != null || status.hasError)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  message ?? 'Power status unavailable',
                  style: PowerConsole.label.copyWith(letterSpacing: .2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.status, required this.loading});
  final PowerStatus? status;
  final bool loading;
  @override
  Widget build(BuildContext context) {
    final label = loading
        ? 'LOADING'
        : status?.batteryPresent != true
        ? 'SYSTEM POWER'
        : switch (status!.state) {
            PowerBatteryState.charging => 'CHARGING',
            PowerBatteryState.discharging => 'DISCHARGING',
            PowerBatteryState.full => 'FULL',
            PowerBatteryState.empty => 'EMPTY',
            PowerBatteryState.pendingCharge ||
            PowerBatteryState.pendingDischarge => 'WAITING',
            PowerBatteryState.unknown => 'UNKNOWN',
          };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          PowerIcon(
            status?.batteryPresent == true
                ? PowerSymbol.battery
                : PowerSymbol.power,
            color: PowerConsole.pink,
            size: 38,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status?.batteryPresent == true ? 'BATTERY' : 'SYSTEM POWER',
                  style: PowerConsole.value.copyWith(
                    fontFamily: 'Inter',
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  status?.batteryPresent == true
                      ? 'System Power'
                      : 'Power profiles',
                  style: PowerConsole.label,
                ),
              ],
            ),
          ),
          if (status?.batteryPresent == true || loading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0x80080B12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x3046516D)),
              ),
              child: Text(
                label,
                style: PowerConsole.label.copyWith(
                  color: PowerConsole.pink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BatteryStage extends StatelessWidget {
  const _BatteryStage({required this.status, required this.loading});
  final PowerStatus? status;
  final bool loading;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 152,
    child: Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _StagePainter())),
        Positioned(
          left: 28,
          right: 28,
          top: 16,
          height: 47,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xB0080B13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CustomPaint(
              key: const ValueKey<String>('battery-charge-meter'),
              painter: _ChargePainter(
                status?.batteryPresent == true ? status?.percentage : null,
              ),
            ),
          ),
        ),
        Positioned(
          left: 32,
          bottom: 9,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PowerReadout(
                value: status?.batteryPresent == true
                    ? '${status?.percentage?.clamp(0, 100) ?? '--'}'
                    : loading
                    ? '--'
                    : 'N/A',
                unit: status?.batteryPresent == true ? '%' : '',
              ),
              const SizedBox(height: 4),
              const Text('CHARGE', style: PowerConsole.label),
            ],
          ),
        ),
        Positioned(
          right: 24,
          bottom: 9,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TIME REMAINING', style: PowerConsole.label),
              const SizedBox(height: 2),
              PowerReadout(
                value: switch (status?.remainingSeconds?.toInt()) {
                  final seconds? when seconds > 0 && seconds < 3600 =>
                    '${seconds ~/ 60}',
                  _ => formatRemaining(status),
                },
                unit: switch (status?.remainingSeconds?.toInt()) {
                  final seconds? when seconds > 0 && seconds < 3600 => 'm',
                  _ => '',
                },
                size: 43,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Separator extends StatelessWidget {
  const _Separator();
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 46,
    margin: const EdgeInsets.symmetric(horizontal: 6),
    color: const Color(0x3046516D),
  );
}

class _StagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final path = Path()
      ..moveTo(0, 20)
      ..quadraticBezierTo(0, 0, 20, 0)
      ..lineTo(width - 20, 0)
      ..quadraticBezierTo(width, 0, width, 20)
      ..lineTo(width, 66)
      ..lineTo(width * .77, 66)
      ..cubicTo(width * .70, 66, width * .70, 100, width * .62, 100)
      ..lineTo(width * .38, 100)
      ..cubicTo(width * .30, 100, width * .30, 66, width * .23, 66)
      ..lineTo(0, 66)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x55463B60), Color(0x45374152), Color(0x30303C4F)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x253F4961),
    );
  }

  @override
  bool shouldRepaint(_StagePainter oldDelegate) => false;
}

class _ChargePainter extends CustomPainter {
  const _ChargePainter(this.percentage);
  final int? percentage;
  @override
  void paint(Canvas canvas, Size size) {
    const count = 29;
    const gap = 5.0;
    final width = (size.width - gap * (count - 1)) / count;
    if (width <= 0) return;
    final litCount = ((percentage ?? 0).clamp(0, 100) * count / 100).ceil();
    for (var index = 0; index < count; index++) {
      final lit = index < litCount;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(index * (width + gap), 0, width, size.height),
        const Radius.circular(3),
      );
      if (lit) {
        canvas.drawRRect(
          rect,
          Paint()
            ..color = const Color(0xAAED54FF)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
      }
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: lit
                ? [
                    const Color(0xFFFF8DF6),
                    Color.lerp(
                      const Color(0xFFEB62F2),
                      const Color(0xFFAD4AEF),
                      litCount > 1 ? index / (litCount - 1) : 0,
                    )!,
                  ]
                : [const Color(0xFF293044), const Color(0xFF222A3B)],
          ).createShader(rect.outerRect),
      );
    }
  }

  @override
  bool shouldRepaint(_ChargePainter oldDelegate) =>
      percentage != oldDelegate.percentage;
}
