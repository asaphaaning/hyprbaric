import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import 'power_console.dart';
import 'power_formatting.dart';
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
  static const double width = 600;
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
      child: HyprGlassSurface(
        color: Colors.white,
        borderRadius: borderRadius,
        inset: false,
        frame: HyprSurfaceFrame.popover,
        borderColor: const Color(0x887E86B4),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xD01A1D26), Color(0xC0101219), Color(0xD012141C)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(status: snapshot, loading: status.isLoading),
            _BatteryStage(status: snapshot, loading: status.isLoading),
            PowerBay(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
              child: Row(
                children: [
                  Expanded(
                    child: PowerMetric(
                      icon: Icons.bolt_outlined,
                      value: formatPowerRate(snapshot?.powerRateWatts),
                      label: 'POWER',
                    ),
                  ),
                  const _Separator(),
                  Expanded(
                    child: PowerMetric(
                      icon: Icons.waves,
                      value: formatVoltage(snapshot?.voltage),
                      label: 'VOLTAGE',
                    ),
                  ),
                  const _Separator(),
                  Expanded(
                    child: PowerMetric(
                      icon: Icons.thermostat_outlined,
                      value: formatTemperature(snapshot?.temperatureCelsius),
                      label: 'TEMP',
                    ),
                  ),
                  const _Separator(),
                  Expanded(
                    child: PowerMetric(
                      icon: Icons.battery_4_bar_outlined,
                      value: batteryStateLabel(
                        snapshot?.state ?? PowerBatteryState.unknown,
                      ),
                      label: 'STATUS',
                    ),
                  ),
                ],
              ),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Row(
        children: [
          const Icon(
            Icons.battery_2_bar_outlined,
            color: PowerConsole.pink,
            size: 38,
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BATTERY',
                  style: PowerConsole.value.copyWith(
                    fontSize: 20,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: 3),
                const Text('System Power', style: PowerConsole.label),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0x80080B12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x3046516D)),
            ),
            child: Row(
              children: [
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: status?.state == PowerBatteryState.charging
                        ? const Color(0xFF36DFCC)
                        : const Color(0xFFFF4387),
                    boxShadow: const [
                      BoxShadow(color: Color(0x88FF4387), blurRadius: 12),
                    ],
                  ),
                ),
                const SizedBox(width: 13),
                Text(
                  label,
                  style: PowerConsole.label.copyWith(
                    color: PowerConsole.pink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
    height: 142,
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
          left: 62,
          bottom: 9,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF0D8FF), PowerConsole.pink],
                ).createShader(bounds),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: status?.batteryPresent == true
                            ? '${status?.percentage?.clamp(0, 100) ?? '--'}'
                            : loading
                            ? '--'
                            : 'N/A',
                      ),
                      if (status?.batteryPresent == true)
                        TextSpan(
                          text: '%',
                          style: PowerConsole.value.copyWith(fontSize: 29),
                        ),
                    ],
                  ),
                  style: PowerConsole.value.copyWith(fontSize: 45, height: 1),
                ),
              ),
              const SizedBox(height: 4),
              const Text('CHARGE', style: PowerConsole.label),
            ],
          ),
        ),
        Positioned(
          right: 35,
          bottom: 9,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TIME REMAINING', style: PowerConsole.label),
              const SizedBox(height: 2),
              Text(
                formatRemaining(status),
                style: PowerConsole.value.copyWith(
                  fontSize: 43,
                  height: 1.1,
                  color: PowerConsole.pink,
                ),
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
    margin: const EdgeInsets.symmetric(horizontal: 12),
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
    for (var index = 0; index < count; index++) {
      final lit =
          percentage != null &&
          index < (percentage!.clamp(0, 100) * count / 100).ceil();
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
                      index / count,
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
