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
    int? remainingSeconds,
    double? powerRateWatts,
    double? voltage,
    double? temperatureCelsius,
    PowerProfile activeProfile = PowerProfile.balanced,
    List<PowerProfile> availableProfiles = const <PowerProfile>[
      PowerProfile.saver,
      PowerProfile.balanced,
      PowerProfile.performance,
    ],
    String? batteryMessage,
    String? profileMessage,
  }) {
    return PowerStatus(
      batteryPresent: true,
      percentage: percentage,
      state: state,
      remainingSeconds: remainingSeconds == null
          ? null
          : Uint64.fromBigInt(BigInt.from(remainingSeconds)),
      powerRateWatts: powerRateWatts,
      voltage: voltage,
      temperatureCelsius: temperatureCelsius,
      availableProfiles: availableProfiles,
      activeProfile: activeProfile,
      batteryMessage: batteryMessage,
      profileMessage: profileMessage,
    );
  }

  static PowerStatus laptop({
    int percentage = 72,
    PowerBatteryState state = PowerBatteryState.discharging,
    PowerProfile activeProfile = PowerProfile.balanced,
  }) {
    return battery(
      percentage: percentage,
      state: state,
      remainingSeconds: state == PowerBatteryState.charging ? 4320 : 10080,
      powerRateWatts: state == PowerBatteryState.charging ? 45.5 : -8.2,
      voltage: 12.45,
      temperatureCelsius: 41,
      activeProfile: activeProfile,
    );
  }
}
