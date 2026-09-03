import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/bindings/bindings.dart';
import 'package:hyprbaric/src/widgets/notification_panel.dart';
import 'package:hyprbaric/src/widgets/notification_panel_parts.dart';
import 'package:hyprbaric/src/widgets/notification_panel_style.dart';
import 'package:hyprbaric/src/widgets/notification_row.dart';

void main() {
  group('notificationAgeLabel', () {
    final DateTime now = DateTime(2026, 8, 30, 12);

    test('speaks the reference timecode vocabulary', () {
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

    test('survives timestamps outside the DateTime range', () {
      // Uint64.toInt() clamps rather than throwing, and the clamped value is
      // far outside what DateTime.fromMillisecondsSinceEpoch accepts.
      final Uint64 overflowing = Uint64.fromBigInt(
        BigInt.two.pow(64) - BigInt.one,
      );
      expect(notificationAgeLabel(overflowing, now: now), 'now');
    });

    test('does not report a future timestamp as aged', () {
      final Uint64 skewed = _timestamp(now.add(const Duration(hours: 2)));
      expect(notificationAgeLabel(skewed, now: now), 'now');
    });
  });

  group('NotificationPanel', () {
    testWidgets('fills the dropdown slot it is given', (tester) async {
      await tester.pumpWidget(
        _host(
          AsyncValue<NotificationStatus>.data(
            _status(
              entries: <NotificationEntry>[
                _entry(1, 'github', 'New PR merged'),
                _entry(2, 'discord', 'Three new messages'),
              ],
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(NotificationPanel)).width,
        kNotificationPanelWidth,
      );
      expect(find.byType(NotificationRow), findsNWidgets(2));
      expect(find.text('GITHUB'), findsOneWidget);
      expect(find.text('DISCORD'), findsOneWidget);
      expect(find.byType(NotificationCountPill), findsOneWidget);
    });

    testWidgets('separates a pending first frame from an empty daemon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const AsyncValue<NotificationStatus>.loading()),
      );

      expect(find.text('Loading'), findsOneWidget);
      expect(find.text('No notifications'), findsNothing);
    });

    testWidgets('says when the daemon is gone, even holding stale entries', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          AsyncValue<NotificationStatus>.data(
            _status(
              available: false,
              message: 'daemon lost',
              entries: <NotificationEntry>[_entry(3, 'slack', 'stale')],
            ),
          ),
        ),
      );

      expect(find.text('Notifications unavailable'), findsOneWidget);
      expect(find.text('daemon lost'), findsOneWidget);
      expect(find.byType(NotificationRow), findsNothing);
    });

    testWidgets('surfaces do-not-disturb rather than reading as empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          AsyncValue<NotificationStatus>.data(_status(dndEnabled: true)),
        ),
      );

      expect(find.text('Do not disturb'), findsOneWidget);
      expect(find.text('No notifications'), findsNothing);
    });

    testWidgets('keeps clear all mounted but disabled when empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(AsyncValue<NotificationStatus>.data(_status())),
      );

      expect(find.text('No notifications'), findsOneWidget);
      expect(find.byType(NotificationCountPill), findsNothing);
      // The slot stays in the tree so the header does not reflow as the last
      // notification drains away.
      expect(find.text('clear all'), findsOneWidget);
    });
  });
}

Widget _host(AsyncValue<NotificationStatus> status) {
  return MaterialApp(
    home: Center(
      // Mirrors AnchoredMenuOverlay, which hands the panel a tight slot.
      child: SizedBox(
        width: kNotificationPanelWidth,
        child: NotificationPanel(
          borderRadius: BorderRadius.circular(16),
          status: status,
          onDismiss: (_) {},
          onClearAll: () {},
        ),
      ),
    ),
  );
}

NotificationStatus _status({
  bool available = true,
  bool dndEnabled = false,
  String? message,
  List<NotificationEntry> entries = const <NotificationEntry>[],
}) {
  return NotificationStatus(
    available: available,
    unreadCount: entries.length,
    dndEnabled: dndEnabled,
    message: message,
    entries: entries,
  );
}

NotificationEntry _entry(int id, String app, String message) {
  return NotificationEntry(
    id: id,
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
