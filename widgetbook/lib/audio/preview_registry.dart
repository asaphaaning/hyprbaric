import 'package:flutter/widgets.dart';
import 'package:hyprbaric/widget_catalog.dart';

import 'audio_mixer_preview.dart';
import 'controls_panel_preview.dart';
import 'docs_bar_preview.dart';
import 'network_panel_preview.dart';
import 'notification_panel_preview.dart';
import 'power_panel_preview.dart';
import 'workspace_strip_preview.dart';

/// The previews the landing page may embed, keyed by the name it passes.
///
/// This is the only list of preview names on the Dart side. The web component
/// keeps the matching list of skeletons, and `preview_registry_test.dart`
/// asserts the two agree, so a rename cannot silently fall back to the mixer.
enum LandingPreview {
  mixer(name: 'mixer', width: AudioPanel.width),
  controls(name: 'controls', width: 432),
  network(name: 'network', width: 340),
  power(name: 'power', width: 320),
  notifications(name: 'notifications', width: 380),
  workspaces(name: 'workspaces', width: 340),
  bar(name: 'bar', width: 1280);

  const LandingPreview({required this.name, required this.width});

  /// The identifier the host page passes through `initialData`.
  final String name;

  /// The panel's production layout width.
  ///
  /// These mirror the `BoxConstraints` each panel pins itself to, so a panel
  /// that changes width needs this updated in step. `preview_registry_test`
  /// measures the real widgets and fails when they drift apart. The bar is
  /// fluid instead: it fills its host the way it fills a monitor, so [width]
  /// is only its design width and the width test skips it.
  final double width;

  /// Whether this preview fills its host rather than pinning [width].
  bool get isFluid => this == LandingPreview.bar;

  /// The preview for [name], or null when the host asked for something absent.
  static LandingPreview? byName(String? name) {
    for (final LandingPreview preview in values) {
      if (preview.name == name) {
        return preview;
      }
    }
    return null;
  }

  /// Builds the preview.
  ///
  /// Only [bar] reads [baseUrl] and [onNavigate]: the docs bar joins menu
  /// targets onto the site root and reports absolute URLs back through
  /// [onNavigate]. Every other preview ignores both.
  Widget build({String baseUrl = '/', ValueChanged<String>? onNavigate}) {
    return switch (this) {
      LandingPreview.mixer => const AudioMixerPreview(),
      LandingPreview.controls => const ControlsPanelPreview.landing(),
      LandingPreview.network => const NetworkPanelPreview(),
      LandingPreview.power => const PowerPanelPreview(),
      LandingPreview.notifications => const NotificationPanelPreview(),
      LandingPreview.workspaces => const WorkspaceStripPreview(),
      LandingPreview.bar => DocsBarPreview(
        baseUrl: baseUrl,
        onNavigate: onNavigate,
      ),
    };
  }
}
