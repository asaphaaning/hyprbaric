import 'dart:ui' as ui;

import '../bindings/bindings.dart';

/// The workspace a single bar should present.
///
/// Hyprland tracks one focused workspace, but every connected output displays
/// a workspace of its own. A bar rendered on an unfocused output must show what
/// that output is displaying, not what currently holds focus.
class MonitorWorkspaceResolution {
  const MonitorWorkspaceResolution({
    required this.activeWorkspaceId,
    required this.isSpecial,
    required this.monitorName,
  });

  /// Workspace displayed on this bar's output.
  final int activeWorkspaceId;

  /// Whether [activeWorkspaceId] refers to a special workspace.
  final bool isSpecial;

  /// Hyprland connector name, or null when the output could not be matched.
  final String? monitorName;

  /// Whether the resolution fell back to compositor-wide focus.
  bool get isFallback => monitorName == null;
}

/// Resolves which workspace the bar on [display] should present.
///
/// GTK reports monitor models (`PG32UCDM`) while Hyprland reports connector
/// names (`DP-2`), so the two cannot be matched by name. Resolution instead
/// matches the Flutter display's physical geometry and refresh rate against the
/// outputs Hyprland reported. When that is ambiguous or finds nothing, the
/// compositor-wide focused workspace is used, which is the previous behaviour.
MonitorWorkspaceResolution resolveMonitorWorkspace(
  WorkspaceStatus status,
  ui.Display? display,
) {
  final MonitorWorkspaceStatus? monitor = _matchMonitor(status, display);
  if (monitor == null) {
    return MonitorWorkspaceResolution(
      activeWorkspaceId: status.id,
      isSpecial: status.isSpecial,
      monitorName: null,
    );
  }
  return MonitorWorkspaceResolution(
    activeWorkspaceId: monitor.activeWorkspaceId,
    // `isSpecial` on the status describes the focused workspace, so it only
    // applies to the focused output. Elsewhere a negative id marks a special
    // workspace.
    isSpecial: monitor.isFocused ? status.isSpecial : monitor.activeWorkspaceId < 0,
    monitorName: monitor.name,
  );
}

MonitorWorkspaceStatus? _matchMonitor(
  WorkspaceStatus status,
  ui.Display? display,
) {
  final List<MonitorWorkspaceStatus> monitors = status.monitors;
  if (monitors.isEmpty) {
    return null;
  }
  // A single output cannot be ambiguous, and this keeps single-monitor setups
  // working even if the display metrics are unavailable.
  if (monitors.length == 1) {
    return monitors.first;
  }
  if (display == null) {
    return null;
  }

  final List<MonitorWorkspaceStatus> bySize = monitors
      .where((MonitorWorkspaceStatus monitor) => _sizeMatches(monitor, display))
      .toList(growable: false);
  if (bySize.length == 1) {
    return bySize.first;
  }
  if (bySize.isEmpty) {
    return null;
  }

  // Identical resolutions are common with matched monitor pairs; the refresh
  // rate usually separates them.
  final List<MonitorWorkspaceStatus> byRefresh = bySize
      .where(
        (MonitorWorkspaceStatus monitor) => _refreshMatches(monitor, display),
      )
      .toList(growable: false);
  return byRefresh.length == 1 ? byRefresh.first : null;
}

bool _sizeMatches(MonitorWorkspaceStatus monitor, ui.Display display) {
  // Hyprland reports physical pixels, while the Linux embedder reports the
  // logical size (a 3840x2160 output at scale 1.2 arrives as 3200x1800). The
  // embedder's own devicePixelRatio cannot bridge the two - it reports 2.0 for
  // that same output - so the compositor's scale is used instead. Both
  // readings are accepted in case an embedder does report physical pixels.
  final double scale = monitor.scale > 0 ? monitor.scale : 1.0;
  final bool logical =
      (monitor.width / scale).round() == display.size.width.round() &&
      (monitor.height / scale).round() == display.size.height.round();
  final bool physical =
      monitor.width == display.size.width.round() &&
      monitor.height == display.size.height.round();
  return logical || physical;
}

bool _refreshMatches(MonitorWorkspaceStatus monitor, ui.Display display) {
  return monitor.refreshHz == display.refreshRate.round();
}
