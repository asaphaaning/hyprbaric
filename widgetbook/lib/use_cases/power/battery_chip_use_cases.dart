import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';
import 'power_fixtures.dart';

@UseCase(
  name: 'Desktop — no battery',
  type: BatteryChip,
  path: '[Widgets]/Power',
)
Widget buildDesktopBatteryChip(BuildContext context) {
  return _batteryPreview(status: PowerFixtures.desktop);
}

@UseCase(
  name: 'Laptop — discharging',
  type: BatteryChip,
  path: '[Widgets]/Power',
)
Widget buildDischargingBatteryChip(BuildContext context) {
  return _batteryPreview(
    status: PowerFixtures.battery(
      percentage: 72,
      state: PowerBatteryState.discharging,
    ),
  );
}

@UseCase(name: 'Laptop — charging', type: BatteryChip, path: '[Widgets]/Power')
Widget buildChargingBatteryChip(BuildContext context) {
  return _batteryPreview(
    status: PowerFixtures.battery(
      percentage: 64,
      state: PowerBatteryState.charging,
    ),
  );
}

@UseCase(
  name: 'Laptop — low battery',
  type: BatteryChip,
  path: '[Widgets]/Power',
)
Widget buildLowBatteryChip(BuildContext context) {
  return _batteryPreview(
    status: PowerFixtures.battery(
      percentage: 12,
      state: PowerBatteryState.discharging,
    ),
  );
}

@UseCase(name: 'Laptop — full', type: BatteryChip, path: '[Widgets]/Power')
Widget buildFullBatteryChip(BuildContext context) {
  return _batteryPreview(
    status: PowerFixtures.battery(
      percentage: 100,
      state: PowerBatteryState.full,
    ),
  );
}

@UseCase(name: 'State matrix', type: BatteryChip, path: '[Widgets]/Power')
Widget buildBatteryStateMatrix(BuildContext context) {
  return CatalogFrame(
    width: 420,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const _BatteryStateRow(label: 'DESKTOP', status: PowerFixtures.desktop),
        for (final PowerBatteryState state
            in PowerBatteryState.values) ...<Widget>[
          const SizedBox(height: HyprSpacing.xl),
          _BatteryStateRow(
            label: _stateLabel(state),
            status: PowerFixtures.battery(
              percentage: _statePercentage(state),
              state: state,
            ),
          ),
        ],
      ],
    ),
  );
}

@UseCase(name: 'Interactive', type: BatteryChip, path: '[Widgets]/Power')
Widget buildInteractiveBatteryChip(BuildContext context) {
  final int percentage = context.knobs.int.slider(
    label: 'Percentage',
    initialValue: 72,
    min: 0,
    max: 100,
    divisions: 100,
  );
  final bool isOpen = context.knobs.boolean(label: 'Open', initialValue: false);

  return _batteryPreview(
    status: PowerFixtures.battery(
      percentage: percentage,
      state: PowerBatteryState.discharging,
    ),
    isOpen: isOpen,
  );
}

class _BatteryStateRow extends StatelessWidget {
  const _BatteryStateRow({required this.label, required this.status});

  final String label;
  final PowerStatus status;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: HyprTypography.compactMonoStrong)),
        BatteryChip(status: status, isOpen: false, onPressed: _noop),
      ],
    );
  }
}

String _stateLabel(PowerBatteryState state) {
  return switch (state) {
    PowerBatteryState.unknown => 'UNKNOWN',
    PowerBatteryState.charging => 'CHARGING',
    PowerBatteryState.discharging => 'DISCHARGING',
    PowerBatteryState.empty => 'EMPTY',
    PowerBatteryState.full => 'FULL',
    PowerBatteryState.pendingCharge => 'PENDING CHARGE',
    PowerBatteryState.pendingDischarge => 'PENDING DISCHARGE',
  };
}

int _statePercentage(PowerBatteryState state) {
  return switch (state) {
    PowerBatteryState.unknown => 50,
    PowerBatteryState.charging => 64,
    PowerBatteryState.discharging => 72,
    PowerBatteryState.empty => 0,
    PowerBatteryState.full => 100,
    PowerBatteryState.pendingCharge => 28,
    PowerBatteryState.pendingDischarge => 45,
  };
}

void _noop() {}

Widget _batteryPreview({required PowerStatus status, bool isOpen = false}) {
  return CatalogFrame(
    width: 280,
    child: Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0B1017),
          border: Border.all(color: HyprColors.border),
          borderRadius: const BorderRadius.all(Radius.circular(HyprRadii.bar)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HyprSpacing.lg,
            vertical: HyprSpacing.xs,
          ),
          child: BatteryChip(status: status, isOpen: isOpen, onPressed: () {}),
        ),
      ),
    ),
  );
}
