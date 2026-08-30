import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'power_formatting.dart';
import 'power_profile_pad.dart';

class PowerPanel extends StatelessWidget {
  const PowerPanel({
    super.key,
    required this.borderRadius,
    required this.status,
    required this.latestResult,
    required this.onSetProfile,
  });

  final BorderRadius borderRadius;
  final AsyncValue<PowerStatus> status;
  final PowerCommandResult? latestResult;
  final ValueChanged<PowerProfile> onSetProfile;

  @override
  Widget build(BuildContext context) {
    final PowerStatus? snapshot = status.asData?.value;
    return HyprPopoverPanel(
      borderRadius: borderRadius,
      constraints: const BoxConstraints(minWidth: 320, maxWidth: 320),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const HyprSectionLabel('Battery', trailingLine: true),
          const SizedBox(height: HyprSpacing.xxl),
          _BatteryMeter(status: snapshot, loading: status.isLoading),
          const SizedBox(height: HyprSpacing.section),
          const HyprSectionLabel('Power profile', trailingLine: true),
          const SizedBox(height: HyprSpacing.xxl),
          _ProfileGrid(status: snapshot, onSetProfile: onSetProfile),
          if (_message(snapshot, latestResult)
              case final String message) ...<Widget>[
            const SizedBox(height: HyprSpacing.section),
            Text(
              message,
              style: HyprTypography.popMeta.copyWith(
                color: HyprColors.textFaint,
                fontSize: HyprTypography.size(10),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BatteryMeter extends StatelessWidget {
  const _BatteryMeter({required this.status, required this.loading});

  final PowerStatus? status;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final bool batteryPresent = status?.batteryPresent ?? false;
    final int percentage = status?.percentage?.clamp(0, 100) ?? 0;
    return HyprGlassFrame(
      fill: const Color(0xEB07080A),
      vignette: true,
      child: Padding(
        padding: const EdgeInsets.all(HyprSpacing.section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _LedBar(percentage: percentage, active: batteryPresent),
            const SizedBox(height: HyprSpacing.xxl),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Readout(
                    value: batteryPresent
                        ? '${percentage.clamp(0, 100)}'
                        : loading
                        ? '--'
                        : 'N/A',
                    unit: batteryPresent ? '%' : '',
                    label: 'Charge',
                  ),
                ),
                const SizedBox(width: HyprSpacing.xl),
                Expanded(
                  child: _Readout(
                    value: batteryPresent ? formatRemaining(status) : '--',
                    unit: '',
                    label: 'Remaining',
                  ),
                ),
              ],
            ),
            const SizedBox(height: HyprSpacing.xxl),
            _TelemetryStrip(status: status),
          ],
        ),
      ),
    );
  }
}

class _LedBar extends StatelessWidget {
  const _LedBar({required this.percentage, required this.active});

  final int percentage;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF070B10), Color(0xFF0B1117)],
        ),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(3),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.6)),
        ),
        shadows: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.72),
            blurRadius: 2,
            offset: const Offset(0, 1),
            blurStyle: BlurStyle.inner,
          ),
        ],
      ),
      child: SizedBox(
        height: 18,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Row(
            children: List<Widget>.generate(20, (int index) {
              final double threshold = (index + 1) / 20 * 100;
              final bool lit = active && threshold <= percentage;
              final Color color = !lit
                  ? const Color(0xFF202A33)
                  : threshold < 30
                  ? const Color(0xFFE05F55)
                  : threshold < 60
                  ? const Color(0xFFE7C34A)
                  : const Color(0xFF55D982);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: index == 0 ? 0 : 2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(1),
                      boxShadow: lit
                          ? <BoxShadow>[
                              BoxShadow(
                                color: color.withValues(alpha: 0.72),
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({
    required this.value,
    required this.unit,
    required this.label,
  });

  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF0B1118), Color(0xFF101821)],
        ),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.60)),
        ),
        shadows: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.60),
            blurRadius: 3,
            offset: const Offset(0, 1),
            blurStyle: BlurStyle.inner,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            RichText(
              text: TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: value,
                    style: HyprTypography.compactMonoStrong.copyWith(
                      color: const Color(0xFFE7C34A),
                      fontSize: HyprTypography.size(19),
                      fontWeight: FontWeight.w600,
                      height: 1,
                      shadows: <Shadow>[
                        Shadow(
                          color: const Color(
                            0xFFE7C34A,
                          ).withValues(alpha: 0.45),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  TextSpan(
                    text: unit,
                    style: HyprTypography.compactMono.copyWith(
                      color: const Color(0x99D8BC76),
                      fontSize: HyprTypography.size(11),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.44,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: HyprSpacing.sm),
            Text(
              label.toUpperCase(),
              style: HyprTypography.compactMonoStrong.copyWith(
                color: HyprColors.textFaint,
                fontSize: HyprTypography.size(8.5),
                letterSpacing: 1.19,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TelemetryStrip extends StatelessWidget {
  const _TelemetryStrip({required this.status});

  final PowerStatus? status;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _TelemetryValue(formatPowerRate(status?.powerRateWatts)),
          const _TelemetrySep(),
          _TelemetryValue(formatVoltage(status?.voltage)),
          const _TelemetrySep(),
          _TelemetryValue(formatTemperature(status?.temperatureCelsius)),
          const SizedBox(width: HyprSpacing.xxl),
          DecoratedBox(
            decoration: ShapeDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(3),
                side: const BorderSide(color: HyprColors.borderSoft),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                batteryStateLabel(status?.state ?? PowerBatteryState.unknown),
                style: HyprTypography.compactMono.copyWith(
                  color: HyprColors.textFaint,
                  fontSize: HyprTypography.size(9),
                  letterSpacing: 0.9,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryValue extends StatelessWidget {
  const _TelemetryValue(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: HyprTypography.compactMono.copyWith(
        color: HyprColors.text,
        fontSize: HyprTypography.size(10),
        letterSpacing: 0.2,
      ),
    );
  }
}

class _TelemetrySep extends StatelessWidget {
  const _TelemetrySep();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HyprSpacing.xl),
      child: Text(
        '·',
        style: HyprTypography.compactMono.copyWith(
          color: HyprColors.textFaint.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _ProfileGrid extends StatelessWidget {
  const _ProfileGrid({required this.status, required this.onSetProfile});

  final PowerStatus? status;
  final ValueChanged<PowerProfile> onSetProfile;

  @override
  Widget build(BuildContext context) {
    final List<PowerProfile> available =
        status?.availableProfiles ?? const <PowerProfile>[];
    final PowerProfile? active = status?.activeProfile;
    return Row(
      children: <Widget>[
        for (final PowerProfile profile in PowerProfile.values) ...<Widget>[
          Expanded(
            child: PowerProfilePad(
              profile: profile,
              active: active == profile,
              enabled: available.contains(profile),
              onPressed: onSetProfile,
            ),
          ),
          if (profile != PowerProfile.values.last)
            const SizedBox(width: HyprSpacing.lg),
        ],
      ],
    );
  }
}

String? _message(PowerStatus? status, PowerCommandResult? latestResult) {
  if (latestResult case PowerCommandResultFailed(:final message)) {
    return message;
  }
  return status?.profileMessage ?? status?.batteryMessage;
}
