import 'package:hyprbaric/widget_catalog.dart';

/// Deterministic first-run snapshots for the setup guide stories.
abstract final class SetupFixtures {
  /// The appearance the guide starts from on a fresh install.
  static const AppearanceStatus appearanceDefault = AppearanceStatus(
    position: AppearancePosition.top,
    opacity: 77,
    cornerRadius: 12,
    accentHue: 197,
  );

  /// A guide run that has already committed a translucent, magenta bar.
  static const AppearanceStatus appearanceTuned = AppearanceStatus(
    position: AppearancePosition.bottom,
    opacity: 46,
    cornerRadius: 18,
    accentHue: 310,
  );

  static const WorkspaceSettingsStatus workspacesRoman =
      WorkspaceSettingsStatus(
        indicatorStyle: WorkspaceIndicatorStyle.roman,
        clickable: true,
        visibleRange: WorkspaceVisibleRange.medium,
        visibleCount: 7,
      );

  static const WorkspaceSettingsStatus workspacesNumeric =
      WorkspaceSettingsStatus(
        indicatorStyle: WorkspaceIndicatorStyle.numeric,
        clickable: true,
        visibleRange: WorkspaceVisibleRange.small,
        visibleCount: 5,
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
