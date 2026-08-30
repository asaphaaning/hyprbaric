import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/bindings/bindings.dart';
import 'package:hyprbaric/src/state/monitor_workspace.dart';

/// Stands in for `ui.Display`, which cannot be constructed directly in tests.
class _FakeDisplay implements ui.Display {
  const _FakeDisplay({
    required this.size,
    required this.refreshRate,
    this.devicePixelRatio = 1.0,
  });

  @override
  final int id = 0;
  @override
  final double devicePixelRatio;
  @override
  final ui.Size size;
  @override
  final double refreshRate;
}

MonitorWorkspaceStatus _monitor(
  String name,
  int workspace, {
  bool focused = false,
  int width = 3840,
  int height = 2160,
  int refreshHz = 240,
  double scale = 1.0,
}) {
  return MonitorWorkspaceStatus(
    name: name,
    activeWorkspaceId: workspace,
    isFocused: focused,
    width: width,
    height: height,
    refreshHz: refreshHz,
    scale: scale,
  );
}

WorkspaceStatus _status({
  required int focusedId,
  bool isSpecial = false,
  List<MonitorWorkspaceStatus> monitors = const <MonitorWorkspaceStatus>[],
}) {
  return WorkspaceStatus(
    id: focusedId,
    name: '$focusedId',
    isSpecial: isSpecial,
    occupiedWorkspaceIds: const <int>[],
    monitors: monitors,
  );
}

void main() {
  test('unfocused output reports its own workspace, not the focused one', () {
    // Focus sits on workspace 4 (MACBOOK) while DP-2 still displays 3.
    final WorkspaceStatus status = _status(
      focusedId: 4,
      monitors: <MonitorWorkspaceStatus>[
        _monitor('DP-2', 3),
        _monitor('MACBOOK', 4,
            focused: true, width: 2560, height: 1600, refreshHz: 60),
      ],
    );

    final MonitorWorkspaceResolution resolution = resolveMonitorWorkspace(
      status,
      const _FakeDisplay(size: ui.Size(3840, 2160), refreshRate: 240),
    );

    expect(resolution.activeWorkspaceId, 3);
    expect(resolution.monitorName, 'DP-2');
    expect(resolution.isFallback, isFalse);
  });

  test('focused output reports the focused workspace', () {
    final WorkspaceStatus status = _status(
      focusedId: 4,
      monitors: <MonitorWorkspaceStatus>[
        _monitor('DP-2', 3),
        _monitor('MACBOOK', 4,
            focused: true, width: 2560, height: 1600, refreshHz: 60),
      ],
    );

    final MonitorWorkspaceResolution resolution = resolveMonitorWorkspace(
      status,
      const _FakeDisplay(size: ui.Size(2560, 1600), refreshRate: 60),
    );

    expect(resolution.activeWorkspaceId, 4);
    expect(resolution.monitorName, 'MACBOOK');
  });

  test('a scaled output matches on logical display size', () {
    // A 3840x2160 output at scale 1.2 reaches Flutter as 3200x1800 logical.
    final WorkspaceStatus status = _status(
      focusedId: 4,
      monitors: <MonitorWorkspaceStatus>[
        _monitor('DP-2', 3, scale: 1.2),
        _monitor('MACBOOK', 4,
            focused: true, width: 2560, height: 1600, refreshHz: 60),
      ],
    );

    final MonitorWorkspaceResolution resolution = resolveMonitorWorkspace(
      status,
      // The embedder reports logical pixels and an unrelated ratio of 2.0.
      const _FakeDisplay(
        size: ui.Size(3200, 1800),
        refreshRate: 240,
        devicePixelRatio: 2.0,
      ),
    );

    expect(resolution.activeWorkspaceId, 3);
    expect(resolution.monitorName, 'DP-2');
  });

  test('a single output needs no display metrics', () {
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

  test('identical resolutions are separated by refresh rate', () {
    final WorkspaceStatus status = _status(
      focusedId: 1,
      monitors: <MonitorWorkspaceStatus>[
        _monitor('DP-1', 5, refreshHz: 60),
        _monitor('DP-2', 1, focused: true, refreshHz: 240),
      ],
    );

    final MonitorWorkspaceResolution resolution = resolveMonitorWorkspace(
      status,
      const _FakeDisplay(size: ui.Size(3840, 2160), refreshRate: 60),
    );

    expect(resolution.activeWorkspaceId, 5);
    expect(resolution.monitorName, 'DP-1');
  });

  test('indistinguishable outputs fall back to compositor focus', () {
    // Same size and refresh rate: nothing left to tell them apart.
    final WorkspaceStatus status = _status(
      focusedId: 7,
      monitors: <MonitorWorkspaceStatus>[
        _monitor('DP-1', 5),
        _monitor('DP-2', 7, focused: true),
      ],
    );

    final MonitorWorkspaceResolution resolution = resolveMonitorWorkspace(
      status,
      const _FakeDisplay(size: ui.Size(3840, 2160), refreshRate: 240),
    );

    expect(resolution.activeWorkspaceId, 7);
    expect(resolution.isFallback, isTrue);
  });

  test('an unmatched display falls back to compositor focus', () {
    final WorkspaceStatus status = _status(
      focusedId: 9,
      monitors: <MonitorWorkspaceStatus>[
        _monitor('DP-1', 5),
        _monitor('DP-2', 9, focused: true, width: 2560, height: 1600),
      ],
    );

    final MonitorWorkspaceResolution resolution = resolveMonitorWorkspace(
      status,
      const _FakeDisplay(size: ui.Size(1920, 1080), refreshRate: 60),
    );

    expect(resolution.activeWorkspaceId, 9);
    expect(resolution.isFallback, isTrue);
  });

  test('an empty monitor list preserves the previous global behaviour', () {
    final MonitorWorkspaceResolution resolution = resolveMonitorWorkspace(
      _status(focusedId: 3, isSpecial: true),
      const _FakeDisplay(size: ui.Size(3840, 2160), refreshRate: 240),
    );

    expect(resolution.activeWorkspaceId, 3);
    expect(resolution.isSpecial, isTrue);
    expect(resolution.isFallback, isTrue);
  });

  test('special state applies only to the focused output', () {
    final WorkspaceStatus status = _status(
      focusedId: -99,
      isSpecial: true,
      monitors: <MonitorWorkspaceStatus>[
        _monitor('DP-1', 5, width: 2560, height: 1600, refreshHz: 60),
        _monitor('DP-2', -99, focused: true),
      ],
    );

    final MonitorWorkspaceResolution unfocused = resolveMonitorWorkspace(
      status,
      const _FakeDisplay(size: ui.Size(2560, 1600), refreshRate: 60),
    );
    final MonitorWorkspaceResolution focused = resolveMonitorWorkspace(
      status,
      const _FakeDisplay(size: ui.Size(3840, 2160), refreshRate: 240),
    );

    expect(unfocused.isSpecial, isFalse);
    expect(focused.isSpecial, isTrue);
  });
}
