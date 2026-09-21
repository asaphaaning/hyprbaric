import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import 'system_formatting.dart';
import 'system_icon.dart';

/// Compact CPU and memory readout that opens the system instrument.
class SystemChip extends StatelessWidget {
  const SystemChip({
    super.key,
    required this.status,
    required this.isOpen,
    required this.onPressed,
  });

  final SystemStatus? status;
  final bool isOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          'System, CPU ${formatCpuPercent(status)}, memory ${formatMemoryChip(status)}',
      child: Material(
        color: isOpen ? HyprColors.hoverStrong : Colors.transparent,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(HyprRadii.row),
          side: isOpen
              ? const BorderSide(color: HyprColors.border, width: 1.1)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          hoverColor: HyprColors.hover,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          customBorder: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(HyprRadii.row),
          ),
          child: SizedBox(
            height: HyprIconSizes.compactButton.height + HyprSpacing.xxs,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _Readout(
                    symbol: SystemSymbol.cpu,
                    label: 'CPU',
                    value: formatCpuPercent(status),
                  ),
                  const HyprDivider(
                    height: 18,
                    margin: EdgeInsets.symmetric(horizontal: 6),
                  ),
                  _Readout(
                    symbol: SystemSymbol.memory,
                    label: 'MEM',
                    value: formatMemoryChip(status),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({
    required this.symbol,
    required this.label,
    required this.value,
  });

  final SystemSymbol symbol;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SystemIcon(
          symbol,
          color: HyprColors.textMuted,
          size: HyprIconSizes.bar,
        ),
        const SizedBox(width: HyprSpacing.lg),
        Text(
          label,
          style: HyprTypography.barMono.copyWith(
            color: HyprColors.textFaint,
            fontSize: HyprTypography.size(11.5),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: HyprSpacing.lg),
        Text(
          value,
          style: HyprTypography.barMono.copyWith(
            color: HyprColors.textMuted,
            fontSize: HyprTypography.size(11.5),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
