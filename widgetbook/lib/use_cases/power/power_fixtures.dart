import 'package:hyprbaric/widget_catalog.dart';

abstract final class PowerFixtures {
  static const PowerStatus desktop = PowerStatus(
    batteryPresent: false,
    state: PowerBatteryState.unknown,
    availableProfiles: <PowerProfile>[
      PowerProfile.saver,
      PowerProfile.balanced,
      PowerProfile.performance,
    ],
    activeProfile: PowerProfile.balanced,
  );

  static PowerStatus battery({
    required int percentage,
    required PowerBatteryState state,
  }) {
    return PowerStatus(
      batteryPresent: true,
      percentage: percentage,
      state: state,
      availableProfiles: const <PowerProfile>[
        PowerProfile.saver,
        PowerProfile.balanced,
        PowerProfile.performance,
      ],
      activeProfile: PowerProfile.balanced,
    );
  }
}
