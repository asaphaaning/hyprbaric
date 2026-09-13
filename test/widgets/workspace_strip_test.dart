import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/bindings/bindings.dart';
import 'package:hyprbaric/src/state/monitor_workspace.dart';
import 'package:hyprbaric/src/widgets/workspace_strip.dart';

void main() {
  for (final style in WorkspaceIndicatorStyle.values) {
    for (final reduced in [false, true]) {
      testWidgets('range shifts pop $style labels (reduced: $reduced)', (
        tester,
      ) async {
        int? selected;
        Future<void> render(int active) => tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: WorkspaceStrip(
                status: WorkspaceStatus(
                  id: active,
                  name: '$active',
                  isSpecial: false,
                  occupiedWorkspaceIds: const [],
                  monitors: const [],
                ),
                settings: WorkspaceSettingsStatus(
                  indicatorStyle: style,
                  clickable: true,
                  visibleRange: WorkspaceVisibleRange.small,
                  visibleCount: 5,
                ),
                resolution: MonitorWorkspaceResolution(
                  activeWorkspaceId: active,
                  activeWorkspaceName: '$active',
                  isSpecial: false,
                  monitorName: null,
                ),
                onPrevious: () {},
                onNext: () {},
                onSelect: (id) => selected = id,
              ),
            ),
          ),
        );
        Finder slot() => find.byKey(const ValueKey('workspace-slot-0'));
        int labelCount() => find
            .descendant(of: slot(), matching: find.byType(Text))
            .evaluate()
            .length;
        await render(1);
        await render(2);
        await tester.pump(const Duration(milliseconds: 30));
        expect(
          labelCount(),
          1,
          reason: 'Selection inside the same range does not pop',
        );
        await tester.pumpAndSettle();
        final originalSize = tester.getSize(slot());
        await render(4);
        await tester.pump(const Duration(milliseconds: 30));
        expect(labelCount(), reduced ? 1 : 2);
        expect(tester.getSize(slot()), originalSize);
        await tester.tap(slot());
        expect(
          selected,
          2,
          reason: 'The slot targets its new workspace during motion',
        );
        await render(3);
        await tester.pumpAndSettle();
        expect(labelCount(), 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

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
              activeWorkspaceName: '2',
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
    find.byWidgetPredicate(
      (widget) => widget is WorkspaceButton && widget.workspaceId == id,
    ),
  );
}

Finder _plate(String label) {
  return find
      .ancestor(of: find.text(label), matching: find.byType(AnimatedContainer))
      .first;
}
