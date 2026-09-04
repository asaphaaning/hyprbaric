import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/bindings/bindings.dart';
import 'package:hyprbaric/src/layer_shell_controller.dart';
import 'package:hyprbaric/src/state/bar_config.dart';
import 'package:hyprbaric/src/state/monitor_workspace.dart';

MonitorWorkspaceStatus _monitor(
  String name,
  int workspace, {
  String? workspaceName,
  bool special = false,
  bool focused = false,
  int x = 0,
  int y = 0,
  int width = 3840,
  int height = 2160,
  int refreshRateMillihertz = 240000,
}) {
  return MonitorWorkspaceStatus(
    name: name,
    activeWorkspaceId: workspace,
    activeWorkspaceName: workspaceName ?? '$workspace',
    isSpecial: special,
    isFocused: focused,
    x: x,
    y: y,
    width: width,
    height: height,
    refreshRateMillihertz: refreshRateMillihertz,
  );
}

LayerShellMonitor _output({
  String name = 'GTK output',
  int x = 0,
  int y = 0,
  int width = 3840,
  int height = 2160,
  int refreshRateMillihertz = 240000,
}) {
  return LayerShellMonitor(
    name: name,
    label: name,
    isPrimary: false,
    geometry: Rect.fromLTWH(
      x.toDouble(),
      y.toDouble(),
      width.toDouble(),
      height.toDouble(),
    ),
    refreshRateMillihertz: refreshRateMillihertz,
  );
}

WorkspaceStatus _status({
  required int focusedId,
  String? focusedName,
  bool isSpecial = false,
  List<MonitorWorkspaceStatus> monitors = const <MonitorWorkspaceStatus>[],
}) {
  return WorkspaceStatus(
    id: focusedId,
    name: focusedName ?? '$focusedId',
    isSpecial: isSpecial,
    occupiedWorkspaceIds: const <int>[],
    monitors: monitors,
  );
}

void main() {
  test('named connector is visible only on its matched view', () {
    final WorkspaceStatus status = _status(
      focusedId: 2,
      monitors: <MonitorWorkspaceStatus>[
        _monitor('DP-1', 1),
        _monitor('DP-2', 2, focused: true, x: 3840),
      ],
    );

    expect(
      resolveViewMonitorTarget(
        const AppearanceMonitorTargetNamed(name: 'DP-2'),
        status,
        _output(x: 3840),
      ),
      isA<LayerShellAllMonitorTarget>(),
    );
    expect(
      resolveViewMonitorTarget(
        const AppearanceMonitorTargetNamed(name: 'DP-2'),
        status,
        _output(),
      ),
      isA<LayerShellHiddenMonitorTarget>(),
    );
  });

  test('missing named connector falls back to the primary view', () {
    final WorkspaceStatus status = _status(
      focusedId: 1,
      monitors: <MonitorWorkspaceStatus>[_monitor('DP-1', 1, focused: true)],
    );

    expect(
      resolveViewMonitorTarget(
        const AppearanceMonitorTargetNamed(name: 'DP-9'),
        status,
        _output(),
      ),
      isA<LayerShellPrimaryMonitorTarget>(),
    );
  });

  test('unfocused output reports its own workspace', () {
    final WorkspaceStatus status = _status(
      focusedId: 4,
      monitors: <MonitorWorkspaceStatus>[
        _monitor('DP-2', 3),
        _monitor(
          'MACBOOK',
          4,
          focused: true,
          x: 3840,
          width: 1920,
          height: 1200,
          refreshRateMillihertz: 60000,
        ),
      ],
    );

    final MonitorWorkspaceResolution resolution = resolveMonitorWorkspace(
      status,
      _output(),
    );

    expect(resolution.activeWorkspaceId, 3);
    expect(resolution.monitorName, 'DP-2');
    expect(resolution.isFallback, isFalse);
  });

  test('position distinguishes identical output modes', () {
    final WorkspaceStatus status = _status(
      focusedId: 7,
      monitors: <MonitorWorkspaceStatus>[
        _monitor('DP-1', 5),
        _monitor('DP-2', 7, focused: true, x: 3840),
      ],
    );

    final MonitorWorkspaceResolution resolution = resolveMonitorWorkspace(
      status,
      _output(x: 0),
    );

    expect(resolution.activeWorkspaceId, 5);
    expect(resolution.monitorName, 'DP-1');
  });

  test('focused output reports the focused workspace', () {
    final WorkspaceStatus status = _status(
      focusedId: 4,
      monitors: <MonitorWorkspaceStatus>[
        _monitor('DP-2', 3),
        _monitor(
          'MACBOOK',
          4,
          focused: true,
          x: 3840,
          width: 1920,
          height: 1200,
          refreshRateMillihertz: 60000,
        ),
      ],
    );

    final MonitorWorkspaceResolution resolution = resolveMonitorWorkspace(
      status,
      _output(x: 3840, width: 1920, height: 1200, refreshRateMillihertz: 60000),
    );

    expect(resolution.activeWorkspaceId, 4);
    expect(resolution.monitorName, 'MACBOOK');
  });

  test('logical geometry matches a fractionally scaled output', () {
    final WorkspaceStatus status = _status(
      focusedId: 4,
      monitors: <MonitorWorkspaceStatus>[
        _monitor('DP-2', 3, width: 3200, height: 1800),
        _monitor(
          'MACBOOK',
          4,
          focused: true,
          x: 3200,
          width: 1920,
          height: 1200,
          refreshRateMillihertz: 60000,
        ),
      ],
    );

    final MonitorWorkspaceResolution resolution = resolveMonitorWorkspace(
      status,
      _output(width: 3200, height: 1800),
    );

    expect(resolution.activeWorkspaceId, 3);
    expect(resolution.monitorName, 'DP-2');
  });

  test(
    'rotated logical geometry matches without physical-axis assumptions',
    () {
      final WorkspaceStatus status = _status(
        focusedId: 2,
        monitors: <MonitorWorkspaceStatus>[
          _monitor('DP-1', 6, x: -1080, width: 1080, height: 1920),
          _monitor('DP-2', 2, focused: true),
        ],
      );

      final MonitorWorkspaceResolution resolution = resolveMonitorWorkspace(
        status,
        _output(x: -1080, width: 1080, height: 1920),
      );

      expect(resolution.activeWorkspaceId, 6);
      expect(resolution.monitorName, 'DP-1');
    },
  );

  test('one-pixel geometry rounding still matches a unique origin', () {
    final WorkspaceStatus status = _status(
      focusedId: 2,
      monitors: <MonitorWorkspaceStatus>[
        _monitor('DP-1', 6, width: 2560, height: 1440),
        _monitor('DP-2', 2, focused: true, x: 2560),
      ],
    );

    final MonitorWorkspaceResolution resolution = resolveMonitorWorkspace(
      status,
      _output(width: 2559, height: 1441),
    );

    expect(resolution.activeWorkspaceId, 6);
    expect(resolution.monitorName, 'DP-1');
  });

  test('a single output needs no native monitor facts', () {
    final WorkspaceStatus status = _status(
      focusedId: 2,
      monitors: <MonitorWorkspaceStatus>[_monitor('DP-2', 2, focused: true)],
    );

    final MonitorWorkspaceResolution resolution = resolveMonitorWorkspace(
      status,
      null,
    );

    expect(resolution.activeWorkspaceId, 2);
    expect(resolution.monitorName, 'DP-2');
  });

  test('refresh rate separates size-only fallback candidates', () {
    final WorkspaceStatus status = _status(
      focusedId: 1,
      monitors: <MonitorWorkspaceStatus>[
        _monitor('DP-1', 5, x: 100, refreshRateMillihertz: 60000),
        _monitor('DP-2', 1, focused: true, x: 200),
      ],
    );

    final MonitorWorkspaceResolution resolution = resolveMonitorWorkspace(
      status,
      _output(x: 999, refreshRateMillihertz: 59940),
    );

    expect(resolution.activeWorkspaceId, 5);
    expect(resolution.monitorName, 'DP-1');
  });

  test('mirrored indistinguishable outputs fall back to compositor focus', () {
    final WorkspaceStatus status = _status(
      focusedId: 7,
      monitors: <MonitorWorkspaceStatus>[
        _monitor('DP-1', 5),
        _monitor('DP-2', 7, focused: true),
      ],
    );

    final MonitorWorkspaceResolution resolution = resolveMonitorWorkspace(
      status,
      _output(),
    );

    expect(resolution.activeWorkspaceId, 7);
    expect(resolution.isFallback, isTrue);
  });

  test('an unmatched output falls back to compositor focus', () {
    final WorkspaceStatus status = _status(
      focusedId: 9,
      monitors: <MonitorWorkspaceStatus>[
        _monitor('DP-1', 5),
        _monitor('DP-2', 9, focused: true, x: 3840),
      ],
    );

    final MonitorWorkspaceResolution resolution = resolveMonitorWorkspace(
      status,
      _output(x: 999, width: 1920, height: 1080),
    );

    expect(resolution.activeWorkspaceId, 9);
    expect(resolution.isFallback, isTrue);
  });

  test('an empty monitor list preserves compositor focus', () {
    final MonitorWorkspaceResolution resolution = resolveMonitorWorkspace(
      _status(focusedId: -3, focusedName: 'special:notes', isSpecial: true),
      _output(),
    );

    expect(resolution.activeWorkspaceId, -3);
    expect(resolution.activeWorkspaceName, 'special:notes');
    expect(resolution.isSpecial, isTrue);
    expect(resolution.isFallback, isTrue);
  });

  test('an unfocused output carries its own special workspace', () {
    final WorkspaceStatus status = _status(
      focusedId: 4,
      monitors: <MonitorWorkspaceStatus>[
        _monitor('DP-1', -99, workspaceName: 'special:notes', special: true),
        _monitor('DP-2', 4, focused: true, x: 3840),
      ],
    );

    final MonitorWorkspaceResolution resolution = resolveMonitorWorkspace(
      status,
      _output(),
    );

    expect(resolution.activeWorkspaceId, -99);
    expect(resolution.activeWorkspaceName, 'special:notes');
    expect(resolution.isSpecial, isTrue);
    expect(resolution.monitorName, 'DP-1');
  });
}
