import 'package:hyprbaric/widget_catalog.dart';

import '../settings/settings_fixtures.dart';

/// Deterministic first-run snapshots for the setup guide stories.
abstract final class SetupFixtures {
  /// The appearance a fresh install starts from.
  ///
  /// Shared with the settings stories rather than restated, so the two cannot
  /// disagree about what "default" means.
  static const AppearanceStatus appearanceDefault =
      SettingsFixtures.appearanceDefault;

  static const WorkspaceSettingsStatus workspacesRoman =
      SettingsFixtures.workspacesRoman;

  /// The guide's own narrower default, distinct from the settings story's.
  static const WorkspaceSettingsStatus workspacesNumeric =
      WorkspaceSettingsStatus(
        indicatorStyle: WorkspaceIndicatorStyle.numeric,
        clickable: true,
        visibleRange: WorkspaceVisibleRange.small,
        visibleCount: 5,
      );

  /// A guide run that has already committed a translucent, magenta bar.
  static const AppearanceStatus appearanceTuned = AppearanceStatus(
    position: AppearancePosition.bottom,
    opacity: 46,
    cornerRadius: 18,
    accentHue: 310,
  );

  /// The accent wheel the guide offers, mirroring the production overlay.
  static const List<int> accentPresets = <int>[
    197,
    238,
    275,
    310,
    345,
    25,
    70,
    145,
  ];
}
