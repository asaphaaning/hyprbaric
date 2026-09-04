import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';
import 'notification_fixtures.dart';

@UseCase(
  name: 'States',
  type: NotificationButton,
  path: '[Building blocks]/Notifications',
)
Widget buildNotificationButtonStates(BuildContext context) {
  return CatalogFrame(
    width: 360,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        const _LabeledAtom(
          label: 'QUIET',
          child: NotificationButton(
            unreadCount: 0,
            isOpen: false,
            onPressed: _noop,
          ),
        ),
        const _LabeledAtom(
          label: 'UNREAD',
          child: NotificationButton(
            unreadCount: 3,
            isOpen: false,
            onPressed: _noop,
          ),
        ),
        const _LabeledAtom(
          label: 'OPEN',
          child: NotificationButton(
            unreadCount: 3,
            isOpen: true,
            onPressed: _noop,
          ),
        ),
      ],
    ),
  );
}

@UseCase(
  name: 'Counts',
  type: NotificationCountPill,
  path: '[Building blocks]/Notifications',
)
Widget buildNotificationCountPillStates(BuildContext context) {
  return const CatalogFrame(
    width: 300,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        NotificationCountPill(count: 1),
        NotificationCountPill(count: 3),
        NotificationCountPill(count: 99),
      ],
    ),
  );
}

@UseCase(
  name: 'Empty and populated',
  type: NotificationHeader,
  path: '[Building blocks]/Notifications',
)
Widget buildNotificationHeaderStates(BuildContext context) {
  return const CatalogFrame(
    width: 400,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        NotificationHeader(count: 0, onClearAll: _noop),
        SizedBox(height: HyprSpacing.loose),
        NotificationHeader(count: 3, onClearAll: _noop),
      ],
    ),
  );
}

@UseCase(
  name: 'Urgencies',
  type: NotificationRow,
  path: '[Building blocks]/Notifications',
)
Widget buildNotificationRowUrgencies(BuildContext context) {
  final List<NotificationEntry> entries =
      NotificationFixtures.populated().entries;

  return CatalogFrame(
    width: 400,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int index = 0; index < entries.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(height: 14),
          NotificationRow(entry: entries[index], onDismiss: _noop),
        ],
      ],
    ),
  );
}

@UseCase(
  name: 'Available and unavailable',
  type: NotificationPlaceholder,
  path: '[Building blocks]/Notifications',
)
Widget buildNotificationEmptyStates(BuildContext context) {
  return const CatalogFrame(
    width: 400,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        NotificationPlaceholder(label: 'No notifications'),
        SizedBox(height: HyprSpacing.loose),
        NotificationPlaceholder(
          label: 'Notifications unavailable',
          subtitle: 'notification service is offline',
        ),
      ],
    ),
  );
}

@UseCase(
  name: 'Populated',
  type: NotificationList,
  path: '[Building blocks]/Notifications',
)
Widget buildNotificationList(BuildContext context) {
  return CatalogFrame(
    width: 400,
    child: NotificationList(
      entries: NotificationFixtures.populated().entries,
      onDismiss: (_) {},
    ),
  );
}

class _LabeledAtom extends StatelessWidget {
  const _LabeledAtom({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        child,
        const SizedBox(height: HyprSpacing.xl),
        Text(label, style: HyprTypography.metricLabel),
      ],
    );
  }
}

void _noop() {}
