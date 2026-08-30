import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/bindings/bindings.dart';
import 'package:hyprbaric/src/state/monitor_workspace.dart';
import 'package:hyprbaric/src/widgets/workspace_strip.dart';

void main() {
  testWidgets('WorkspaceStrip marks visible workspaces that contain windows', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkspaceStrip(
            status: const WorkspaceStatus(
              id: 2,
              name: '2',
              isSpecial: false,
              occupiedWorkspaceIds: <int>[1, 3],
              monitors: <MonitorWorkspaceStatus>[],
            ),
            settings: const WorkspaceSettingsStatus(
              indicatorStyle: WorkspaceIndicatorStyle.roman,
              clickable: true,
              visibleRange: WorkspaceVisibleRange.medium,
              visibleCount: 7,
            ),
            resolution: const MonitorWorkspaceResolution(
              activeWorkspaceId: 2,
              isSpecial: false,
              monitorName: null,
            ),
            onPrevious: () {},
            onNext: () {},
            onSelect: (_) {},
          ),
        ),
      ),
    );

    expect(_indicator(tester, 1).occupied, isTrue);
    expect(_indicator(tester, 2).occupied, isFalse);
    expect(_indicator(tester, 3).occupied, isTrue);
    expect(
      find.byKey(const ValueKey<String>('workspace-occupancy-dot-I')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('workspace-occupancy-dot-III')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('workspace-occupancy-dot-II')),
      findsNothing,
    );
    final Positioned occupancyDot = tester.widget<Positioned>(
      find
          .ancestor(
            of: find.byKey(
              const ValueKey<String>('workspace-occupancy-dot-III'),
            ),
            matching: find.byType(Positioned),
          )
          .first,
    );

    final Text selected = tester.widget<Text>(find.text('II'));
    final Text occupied = tester.widget<Text>(find.text('III'));
    final Text idle = tester.widget<Text>(find.text('IV'));

    expect(occupied.style?.color, idle.style?.color);
    expect(occupied.style?.fontSize, selected.style?.fontSize);
    expect(tester.getSize(_plate('III')), tester.getSize(_plate('II')));
    expect(occupancyDot.bottom, -3);
  });
}

WorkspaceButton _indicator(WidgetTester tester, int id) {
  return tester.widget<WorkspaceButton>(
    find.byKey(ValueKey<String>('workspace-indicator-$id')),
  );
}

Finder _plate(String label) {
  return find
      .ancestor(of: find.text(label), matching: find.byType(AnimatedContainer))
      .first;
}
