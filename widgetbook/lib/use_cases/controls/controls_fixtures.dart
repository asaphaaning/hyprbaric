import 'package:hyprbaric/widget_catalog.dart';

/// Typed, catalog-only inputs for the production quick-controls panel.
abstract final class ControlsFixtures {
  static const ControlsScenario ready = ControlsScenario(
    dndEnabled: false,
    nightLightStatus: NightLightStatusAvailable(
      enabled: false,
      temperature: 3500,
    ),
    caffeineStatus: CaffeineStatusAvailable(enabled: false),
    recordingStatus: RecordingStatusIdle(),
  );

  static const ControlsScenario active = ControlsScenario(
    dndEnabled: true,
    nightLightStatus: NightLightStatusAvailable(
      enabled: true,
      temperature: 3500,
    ),
    caffeineStatus: CaffeineStatusAvailable(enabled: true),
    recordingStatus: RecordingStatusIdle(),
  );

  static const ControlsScenario landing = ControlsScenario(
    dndEnabled: false,
    nightLightStatus: NightLightStatusAvailable(
      enabled: true,
      temperature: 3500,
    ),
    caffeineStatus: CaffeineStatusAvailable(enabled: false),
    recordingStatus: RecordingStatusIdle(),
  );

  static const ControlsScenario selectingRecording = ControlsScenario(
    dndEnabled: false,
    nightLightStatus: NightLightStatusAvailable(
      enabled: false,
      temperature: 3500,
    ),
    caffeineStatus: CaffeineStatusAvailable(enabled: false),
    recordingStatus: RecordingStatusSelecting(mode: RecordingMode.region),
  );

  static const ControlsScenario unavailable = ControlsScenario(
    dndEnabled: false,
    nightLightStatus: NightLightStatusUnavailable(
      enabled: false,
      temperature: 3500,
      message: 'hyprsunset is unavailable',
    ),
    caffeineStatus: CaffeineStatusUnavailable(message: 'login1 is unavailable'),
    recordingStatus: RecordingStatusUnavailable(
      message: 'wf-recorder is unavailable',
    ),
  );
}

/// A complete, immutable controls state used to exercise [ControlsPanel].
class ControlsScenario {
  const ControlsScenario({
    required this.dndEnabled,
    required this.nightLightStatus,
    required this.caffeineStatus,
    required this.recordingStatus,
  });

  /// Whether notification delivery is paused.
  final bool dndEnabled;

  /// The observed Night Light capability and selected state.
  final NightLightStatus? nightLightStatus;

  /// The observed Caffeine capability and selected state.
  final CaffeineStatus? caffeineStatus;

  /// The current screen-recording lifecycle state.
  final RecordingStatus? recordingStatus;

  /// Returns this scenario with the supplied state projections replaced.
  ControlsScenario copyWith({
    bool? dndEnabled,
    NightLightStatus? nightLightStatus,
    CaffeineStatus? caffeineStatus,
    RecordingStatus? recordingStatus,
  }) {
    return ControlsScenario(
      dndEnabled: dndEnabled ?? this.dndEnabled,
      nightLightStatus: nightLightStatus ?? this.nightLightStatus,
      caffeineStatus: caffeineStatus ?? this.caffeineStatus,
      recordingStatus: recordingStatus ?? this.recordingStatus,
    );
  }
}
