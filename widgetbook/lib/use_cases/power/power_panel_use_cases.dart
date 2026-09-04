import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';
import '../../audio/power_panel_preview.dart';
import 'power_fixtures.dart';

@UseCase(
  name: 'Desktop — no battery',
  type: PowerPanel,
  path: '[Widgets]/Power',
)
Widget buildDesktopPowerPanel(BuildContext context) {
  return const _PowerPanelStory(
    status: AsyncValue<PowerStatus>.data(PowerFixtures.desktop),
  );
}

@UseCase(
  name: 'Laptop — discharging',
  type: PowerPanel,
  path: '[Widgets]/Power',
)
Widget buildDischargingPowerPanel(BuildContext context) {
  return _PowerPanelStory(
    status: AsyncValue<PowerStatus>.data(PowerFixtures.laptop()),
  );
}

@UseCase(name: 'Laptop — charging', type: PowerPanel, path: '[Widgets]/Power')
Widget buildChargingPowerPanel(BuildContext context) {
  return _PowerPanelStory(
    status: AsyncValue<PowerStatus>.data(
      PowerFixtures.laptop(percentage: 64, state: PowerBatteryState.charging),
    ),
  );
}

@UseCase(
  name: 'Laptop — low battery',
  type: PowerPanel,
  path: '[Widgets]/Power',
)
Widget buildLowBatteryPowerPanel(BuildContext context) {
  return _PowerPanelStory(
    status: AsyncValue<PowerStatus>.data(
      PowerFixtures.battery(
        percentage: 12,
        state: PowerBatteryState.discharging,
        remainingSeconds: 2100,
        powerRateWatts: -12.4,
        voltage: 11.86,
        temperatureCelsius: 43,
        batteryMessage: 'Connect a charger soon',
      ),
    ),
  );
}

@UseCase(name: 'Laptop — full', type: PowerPanel, path: '[Widgets]/Power')
Widget buildFullPowerPanel(BuildContext context) {
  return _PowerPanelStory(
    status: AsyncValue<PowerStatus>.data(
      PowerFixtures.battery(
        percentage: 100,
        state: PowerBatteryState.full,
        powerRateWatts: 0,
        voltage: 12.78,
        temperatureCelsius: 36,
      ),
    ),
  );
}

@UseCase(name: 'Loading', type: PowerPanel, path: '[Widgets]/Power')
Widget buildLoadingPowerPanel(BuildContext context) {
  return const _PowerPanelStory(status: AsyncValue<PowerStatus>.loading());
}

@UseCase(
  name: 'Profile command failed',
  type: PowerPanel,
  path: '[Widgets]/Power',
)
Widget buildFailedPowerPanel(BuildContext context) {
  return _PowerPanelStory(
    status: AsyncValue<PowerStatus>.data(PowerFixtures.laptop()),
    latestResult: const PowerCommandResultFailed(
      command: PowerCommandSetProfile(profile: PowerProfile.performance),
      message: 'Performance profile is unavailable on this system',
    ),
  );
}

@UseCase(
  name: 'Interactive profiles',
  type: PowerPanel,
  path: '[Widgets]/Power',
)
Widget buildInteractivePowerPanel(BuildContext context) {
  return const CatalogCanvas(child: PowerPanelPreview());
}

class _PowerPanelStory extends StatelessWidget {
  const _PowerPanelStory({required this.status, this.latestResult});

  final AsyncValue<PowerStatus> status;
  final PowerCommandResult? latestResult;

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: PowerPanel(
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        status: status,
        latestResult: latestResult,
        onSetProfile: (_) {},
      ),
    );
  }
}
