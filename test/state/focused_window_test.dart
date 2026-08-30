import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/bindings/bindings.dart';
import 'package:hyprbaric/src/state/focused_window.dart';

void main() {
  group('focusedWindowDisplay', () {
    const FocusedWindowStatus status = FocusedWindowStatus(
      appName: 'Zed',
      title: 'focused.rs',
      hostname: 'workstation',
      monitors: <MonitorFocusedWindowStatus>[
        MonitorFocusedWindowStatus(
          monitorName: 'DP-2',
          appName: 'foot',
          title: 'cargo test',
        ),
        MonitorFocusedWindowStatus(
          monitorName: 'MACBOOK',
          appName: 'firefox',
          title: 'Hyprbaric',
        ),
      ],
    );

    test('uses the focused client visible on the resolved output', () {
      final FocusedWindowDisplay display = focusedWindowDisplay(
        status,
        monitorName: 'MACBOOK',
      );

      expect(display.appName, 'Firefox');
      expect(display.title, 'Hyprbaric');
      expect(display.isFallback, isFalse);
    });

    test('keeps compositor-wide focus when the output is unresolved', () {
      final FocusedWindowDisplay display = focusedWindowDisplay(status);

      expect(display.appName, 'Zed');
      expect(display.title, 'focused.rs');
    });

    test('hides the label when the resolved output has no client', () {
      const FocusedWindowStatus emptyMonitor = FocusedWindowStatus(
        appName: 'Zed',
        title: 'focused.rs',
        hostname: 'workstation',
        monitors: <MonitorFocusedWindowStatus>[
          MonitorFocusedWindowStatus(monitorName: 'HDMI-A-1'),
        ],
      );

      final FocusedWindowDisplay display = focusedWindowDisplay(
        emptyMonitor,
        monitorName: 'HDMI-A-1',
      );

      expect(display.isHidden, isTrue);
    });

    test('does not borrow missing fields from another output', () {
      const FocusedWindowStatus titleOnly = FocusedWindowStatus(
        appName: 'Zed',
        title: 'focused.rs',
        hostname: 'workstation',
        monitors: <MonitorFocusedWindowStatus>[
          MonitorFocusedWindowStatus(monitorName: 'DP-3', title: 'Untitled'),
        ],
      );

      final FocusedWindowDisplay display = focusedWindowDisplay(
        titleOnly,
        monitorName: 'DP-3',
      );

      expect(display.appName, isNull);
      expect(display.title, 'Untitled');
    });
  });
}
