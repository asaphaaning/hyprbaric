import '../bindings/bindings.dart';
import '../layer_shell_controller.dart';

/// The workspace a single bar should present.
class MonitorWorkspaceResolution {
  const MonitorWorkspaceResolution({
    required this.activeWorkspaceId,
    required this.activeWorkspaceName,
    required this.isSpecial,
    required this.monitorName,
  });

  /// Workspace displayed on this bar's output.
  final int activeWorkspaceId;

  /// User-visible name of [activeWorkspaceId].
  final String activeWorkspaceName;

  /// Whether [activeWorkspaceId] refers to a special workspace.
  final bool isSpecial;

  /// Hyprland connector name, or null when the output could not be matched.
  final String? monitorName;

  /// Whether the resolution fell back to compositor-wide focus.
  bool get isFallback => monitorName == null;
}

/// Resolves which workspace the bar on [output] should present.
///
/// The native runner reports the exact logical GDK rectangle occupied by this
/// Flutter view. Hyprland output facts are projected into the same logical
/// coordinate space before crossing the RINF boundary, allowing position to
/// distinguish outputs that share a mode. Ambiguous or unavailable geometry
/// conservatively preserves compositor-wide focus.
MonitorWorkspaceResolution resolveMonitorWorkspace(
  WorkspaceStatus status,
  LayerShellMonitor? output,
) {
  final MonitorWorkspaceStatus? monitor = _matchMonitor(status, output);
  if (monitor == null) {
    return MonitorWorkspaceResolution(
      activeWorkspaceId: status.id,
      activeWorkspaceName: status.name,
      isSpecial: status.isSpecial,
      monitorName: null,
    );
  }

  return MonitorWorkspaceResolution(
    activeWorkspaceId: monitor.activeWorkspaceId,
    activeWorkspaceName: monitor.activeWorkspaceName,
    isSpecial: monitor.isSpecial,
    monitorName: monitor.name,
  );
}

MonitorWorkspaceStatus? _matchMonitor(
  WorkspaceStatus status,
  LayerShellMonitor? output,
) {
  final List<MonitorWorkspaceStatus> monitors = status.monitors;
  if (monitors.isEmpty) {
    return null;
  }
  if (monitors.length == 1) {
    return monitors.first;
  }
  if (output == null) {
    return null;
  }

  final List<MonitorWorkspaceStatus> byRectangle = monitors
      .where(
        (MonitorWorkspaceStatus monitor) => _rectangleMatches(monitor, output),
      )
      .toList(growable: false);
  if (byRectangle.length == 1) {
    return byRectangle.first;
  }
  if (byRectangle.length > 1) {
    return _uniqueRefreshMatch(byRectangle, output);
  }

  // A unique compositor position is still authoritative if an embedder rounds
  // a transformed or fractionally scaled extent differently by one pixel.
  final List<MonitorWorkspaceStatus> byOrigin = monitors
      .where(
        (MonitorWorkspaceStatus monitor) => _originMatches(monitor, output),
      )
      .toList(growable: false);
  if (byOrigin.length == 1) {
    return byOrigin.first;
  }
  if (byOrigin.length > 1) {
    return _uniqueRefreshMatch(byOrigin, output);
  }

  // Keep a size/refresh fallback for embedders that cannot expose global
  // monitor coordinates. It never guesses when matched outputs remain alike.
  final List<MonitorWorkspaceStatus> bySize = monitors
      .where((MonitorWorkspaceStatus monitor) => _sizeMatches(monitor, output))
      .toList(growable: false);
  if (bySize.length == 1) {
    return bySize.first;
  }
  return _uniqueRefreshMatch(bySize, output);
}

MonitorWorkspaceStatus? _uniqueRefreshMatch(
  List<MonitorWorkspaceStatus> monitors,
  LayerShellMonitor output,
) {
  final List<MonitorWorkspaceStatus> matches = monitors
      .where(
        (MonitorWorkspaceStatus monitor) =>
            (monitor.refreshRateMillihertz - output.refreshRateMillihertz)
                .abs() <=
            1000,
      )
      .toList(growable: false);
  return matches.length == 1 ? matches.first : null;
}

bool _rectangleMatches(
  MonitorWorkspaceStatus monitor,
  LayerShellMonitor output,
) {
  return _originMatches(monitor, output) && _sizeMatches(monitor, output);
}

bool _originMatches(MonitorWorkspaceStatus monitor, LayerShellMonitor output) {
  return _near(monitor.x, output.geometry.left) &&
      _near(monitor.y, output.geometry.top);
}

bool _sizeMatches(MonitorWorkspaceStatus monitor, LayerShellMonitor output) {
  return _near(monitor.width, output.geometry.width) &&
      _near(monitor.height, output.geometry.height);
}

bool _near(int compositorValue, double nativeValue) {
  return (compositorValue - nativeValue).abs() <= 1;
}
