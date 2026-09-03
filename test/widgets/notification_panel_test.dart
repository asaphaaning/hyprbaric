import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/bindings/bindings.dart';
import 'package:hyprbaric/src/widgets/notification_panel.dart';
import 'package:hyprbaric/src/widgets/notification_panel_parts.dart';
import 'package:hyprbaric/src/widgets/notification_panel_style.dart';
import 'package:hyprbaric/src/widgets/notification_row.dart';

void main() {
  test('notification age labels match the reference timecode vocabulary', () {
    final DateTime now = DateTime(2026, 8, 30, 12);

    expect(notificationAgeLabel(_timestamp(now), now: now), 'now');
    expect(
      notificationAgeLabel(
        _timestamp(now.subtract(const Duration(minutes: 12))),
        now: now,
      ),
      '12m ago',
    );
    expect(
      notificationAgeLabel(
        _timestamp(now.subtract(const Duration(hours: 1))),
        now: now,
      ),
      '1h ago',
    );
  });

  testWidgets('notification panel uses the v3 chassis and row dimensions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          // Mirrors AnchoredMenuOverlay, which hands the panel a tight slot.
          child: SizedBox(
            width: kNotificationPanelWidth,
            child: NotificationPanel(
            borderRadius: BorderRadius.circular(16),
            status: NotificationStatus(
              available: true,
              unreadCount: 2,
              dndEnabled: false,
              entries: <NotificationEntry>[
                _entry('github', 'New PR merged'),
                _entry('discord', 'Three new messages'),
              ],
            ),
            onDismiss: (_) {},
            onClearAll: () {},
          ),
          ),
        ),
      ),
    );

    final List<NotificationRow> rows = tester
        .widgetList<NotificationRow>(find.byType(NotificationRow))
        .toList();

    expect(
      tester.getSize(find.byType(NotificationPanel)).width,
      kNotificationPanelWidth,
    );
    expect(rows, hasLength(2));
    expect(find.text('GITHUB'), findsOneWidget);
    expect(find.text('DISCORD'), findsOneWidget);
    expect(find.byType(NotificationCountPill), findsOneWidget);
  });

  testWidgets('empty notification panel renders only the empty label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: NotificationPanel(
            borderRadius: BorderRadius.circular(16),
            status: const NotificationStatus(
              available: true,
              unreadCount: 0,
              dndEnabled: false,
              entries: <NotificationEntry>[],
            ),
            onDismiss: (_) {},
            onClearAll: () {},
          ),
        ),
      ),
    );

    expect(find.text('No notifications'), findsOneWidget);
    expect(find.text("you're all caught up"), findsNothing);
    expect(find.text('clear all'), findsNothing);
    expect(find.byType(NotificationCountPill), findsNothing);
  });
}

NotificationEntry _entry(String app, String message) {
  return NotificationEntry(
    id: app.hashCode,
    app: app,
    message: message,
    createdAtMs: _timestamp(
      DateTime.now().subtract(const Duration(minutes: 2)),
    ),
    urgency: NotificationUrgency.normal,
  );
}

Uint64 _timestamp(DateTime time) {
  return Uint64.fromBigInt(BigInt.from(time.millisecondsSinceEpoch));
}
