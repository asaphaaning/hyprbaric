import 'package:flutter/material.dart';
import 'package:hyprbaric/src/features/system/system_formatting.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';
import 'system_fixtures.dart';

@UseCase(
  name: 'Needle positions',
  type: SystemGauge,
  path: '[Building blocks]/System',
)
Widget buildSystemGaugeStates(BuildContext context) {
  return CatalogFrame(
    width: 780,
    child: Row(
      children: <Widget>[
        for (final double ratio in <double>[0.12, 0.34, 0.91]) ...<Widget>[
          Expanded(child: SystemGauge(ratio: ratio)),
          if (ratio != 0.91) const SizedBox(width: 12),
        ],
      ],
    ),
  );
}

@UseCase(
  name: 'Interactive needle',
  type: SystemGauge,
  path: '[Building blocks]/System',
)
Widget buildInteractiveSystemGauge(BuildContext context) {
  final int cpu = context.knobs.int.slider(
    label: 'CPU %',
    initialValue: 12,
    min: 0,
    max: 100,
    divisions: 100,
  );
  return CatalogFrame(
    width: 320,
    child: Center(child: SystemGauge(ratio: cpu / 100)),
  );
}

@UseCase(
  name: 'Meter rows',
  type: SystemMeterRow,
  path: '[Building blocks]/System',
)
Widget buildSystemMeterRows(BuildContext context) {
  final SystemStatus status = SystemFixtures.reference();
  return CatalogFrame(
    width: 280,
    child: Column(
      children: <Widget>[
        SystemMeterRow(
          symbol: SystemSymbol.cpu,
          label: 'CPU',
          value: formatCpuPercent(status),
          ratio: cpuRatio(status),
        ),
        const SizedBox(height: 16),
        SystemMeterRow(
          symbol: SystemSymbol.memory,
          label: 'Memory',
          value: formatMemoryPanel(status),
          ratio: memoryRatio(status),
        ),
        const SizedBox(height: 16),
        SystemMeterRow(
          symbol: SystemSymbol.disk,
          label: 'Disk',
          value: formatDiskPercent(status),
          ratio: diskRatio(status),
        ),
      ],
    ),
  );
}

@UseCase(
  name: 'Sparklines',
  type: SystemSparkline,
  path: '[Building blocks]/System',
)
Widget buildSystemSparklines(BuildContext context) {
  return CatalogFrame(
    width: 280,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('CPU'),
        const SizedBox(height: 8),
        SystemSparkline(
          samples: cpuHistory(SystemFixtures.barReadout()),
          width: 120,
          height: 22,
          bars: 16,
        ),
        const SizedBox(height: 18),
        const Text('Memory'),
        const SizedBox(height: 8),
        SystemSparkline(
          samples: memoryHistory(SystemFixtures.barReadout()),
          width: 120,
          height: 22,
          bars: 16,
        ),
      ],
    ),
  );
}

@UseCase(name: 'Symbols', type: SystemIcon, path: '[Building blocks]/System')
Widget buildSystemSymbols(BuildContext context) {
  return CatalogFrame(
    width: 360,
    child: Wrap(
      spacing: 18,
      runSpacing: 18,
      children: <Widget>[
        for (final SystemSymbol symbol in SystemSymbol.values)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SystemIcon(
                symbol,
                color: HyprInstrumentColors.secondary,
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(symbol.name, style: HyprInstrumentText.meta),
            ],
          ),
      ],
    ),
  );
}
