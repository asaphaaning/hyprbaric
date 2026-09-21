import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'system_console.dart';
import 'system_formatting.dart';
import 'system_gauge.dart';
import 'system_icon.dart';
import 'system_meter.dart';

/// Live occupancy instrument shared by the bar, Widgetbook and landing preview.
class SystemPanel extends StatelessWidget {
  const SystemPanel({
    super.key,
    required this.borderRadius,
    required this.status,
  });

  static const double width = 480;
  static const BorderRadius radius = HyprRadii.chassisRadius;

  final BorderRadius borderRadius;
  final AsyncValue<SystemStatus> status;

  @override
  Widget build(BuildContext context) {
    final SystemStatus? snapshot = status.asData?.value;
    final bool unavailable =
        status.hasError || (snapshot?.message?.isNotEmpty ?? false);
    return SizedBox(
      width: width,
      child: HyprInstrumentSurface(
        borderRadius: borderRadius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: HyprInstrumentHeader(
                title: 'System',
                icon: SystemIcon(
                  SystemSymbol.cpu,
                  color: HyprInstrumentColors.secondary,
                ),
              ),
            ),
            if (unavailable)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: HyprEmptyState(
                  message:
                      snapshot?.message ?? 'System occupancy is unavailable',
                  symbol: 'SYSTEM',
                ),
              )
            else ...<Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: SystemGauge(ratio: cpuRatio(snapshot))),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 168,
                      child: Column(
                        children: <Widget>[
                          SystemMeterRow(
                            symbol: SystemSymbol.cpu,
                            label: 'CPU',
                            value: formatCpuPercent(snapshot),
                            ratio: cpuRatio(snapshot),
                          ),
                          const SizedBox(height: 16),
                          SystemMeterRow(
                            symbol: SystemSymbol.memory,
                            label: 'Memory',
                            value: formatMemoryPanel(snapshot),
                            ratio: memoryRatio(snapshot),
                          ),
                          const SizedBox(height: 16),
                          SystemMeterRow(
                            symbol: SystemSymbol.disk,
                            label: 'Disk',
                            value: formatDiskPercent(snapshot),
                            ratio: diskRatio(snapshot),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: HyprPanelDivider(color: SystemConsole.divider),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: SystemBay(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: SystemStat(
                          symbol: SystemSymbol.uptime,
                          value: formatUptime(snapshot),
                          label: 'UPTIME',
                        ),
                      ),
                      const _Separator(),
                      Expanded(
                        child: SystemStat(
                          symbol: SystemSymbol.temperature,
                          value: formatTemperature(snapshot),
                          label: 'CPU TEMP',
                        ),
                      ),
                      const _Separator(),
                      Expanded(
                        child: SystemStat(
                          symbol: SystemSymbol.processes,
                          value: formatProcesses(snapshot),
                          label: 'PROCESSES',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 46,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: SystemConsole.divider,
    );
  }
}
