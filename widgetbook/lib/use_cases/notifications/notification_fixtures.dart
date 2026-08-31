import 'package:hyprbaric/widget_catalog.dart';

abstract final class NotificationFixtures {
  static const NotificationStatus empty = NotificationStatus(
    available: true,
    entries: <NotificationEntry>[],
    unreadCount: 0,
    dndEnabled: false,
  );

  static const NotificationStatus unavailable = NotificationStatus(
    available: false,
    entries: <NotificationEntry>[],
    unreadCount: 0,
    dndEnabled: false,
    message: 'notification service is offline',
  );

  static const NotificationStatus doNotDisturb = NotificationStatus(
    available: true,
    entries: <NotificationEntry>[],
    unreadCount: 0,
    dndEnabled: true,
  );

  static NotificationStatus populated() {
    final List<NotificationEntry> entries = <NotificationEntry>[
      entry(
        id: 1,
        app: 'GitHub',
        message: 'New PR merged: feat/bar-glass',
        age: const Duration(minutes: 2),
        urgency: NotificationUrgency.low,
      ),
      entry(
        id: 2,
        app: 'Discord',
        message: 'hyprwm: 3 new messages in #general',
        age: const Duration(minutes: 12),
      ),
      entry(
        id: 3,
        app: 'System',
        message: 'Update available: hyprland 0.51.1',
        age: const Duration(hours: 1),
        urgency: NotificationUrgency.critical,
      ),
    ];

    return NotificationStatus(
      available: true,
      entries: entries,
      unreadCount: entries.length,
      dndEnabled: false,
    );
  }

  static NotificationStatus overflow() {
    final List<NotificationEntry> entries = List<NotificationEntry>.generate(
      8,
      (int index) => entry(
        id: index + 1,
        app: switch (index % 3) {
          0 => 'GitHub',
          1 => 'Discord',
          _ => 'System',
        },
        message: 'Notification ${index + 1} demonstrates the scrolling list',
        age: Duration(minutes: (index + 1) * 4),
        urgency: NotificationUrgency.values[index % 3],
      ),
    );

    return NotificationStatus(
      available: true,
      entries: entries,
      unreadCount: entries.length,
      dndEnabled: false,
    );
  }

  static NotificationEntry entry({
    required int id,
    required String app,
    required String message,
    required Duration age,
    NotificationUrgency urgency = NotificationUrgency.normal,
  }) {
    final DateTime createdAt = DateTime.now().subtract(age);

    return NotificationEntry(
      id: id,
      app: app,
      message: message,
      createdAtMs: Uint64.fromBigInt(
        BigInt.from(createdAt.millisecondsSinceEpoch),
      ),
      urgency: urgency,
    );
  }
}
