import 'package:flutter/widgets.dart';

import 'audio_mixer_preview.dart';
import 'controls_panel_preview.dart';
import 'network_panel_preview.dart';
import 'notification_panel_preview.dart';
import 'power_panel_preview.dart';

/// The previews the landing page may embed, keyed by the name it passes.
///
/// This is the only list of preview names on the Dart side. The web component
/// keeps the matching list of skeletons, and `preview_registry_test.dart`
/// asserts the two agree, so a rename cannot silently fall back to the mixer.
enum LandingPreview {
  mixer(name: 'mixer', width: 336),
  controls(name: 'controls', width: 432),
  network(name: 'network', width: 340),
  power(name: 'power', width: 320),
  notifications(name: 'notifications', width: 380);

  const LandingPreview({required this.name, required this.width});

  /// The identifier the host page passes through `initialData`.
  final String name;

  /// The panel's production layout width.
  ///
  /// These mirror the `BoxConstraints` each panel pins itself to, so a panel
  /// that changes width needs this updated in step. `preview_registry_test`
  /// measures the real widgets and fails when they drift apart.
  final double width;

  /// The preview for [name], or null when the host asked for something absent.
  static LandingPreview? byName(String? name) {
    for (final LandingPreview preview in values) {
      if (preview.name == name) {
        return preview;
      }
    }
    return null;
  }

  Widget build() {
    return switch (this) {
      LandingPreview.mixer => const AudioMixerPreview(),
      LandingPreview.controls => const ControlsPanelPreview.landing(),
      LandingPreview.network => const NetworkPanelPreview(),
      LandingPreview.power => const PowerPanelPreview(),
      LandingPreview.notifications => const NotificationPanelPreview(),
    };
  }
}
