import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';
import 'notification_fixtures.dart';

@UseCase(
  name: 'Empty',
  type: NotificationPanel,
  path: '[Widgets]/Notifications',
)
Widget buildEmptyNotificationPanel(BuildContext context) {
  return const _NotificationPanelStory(status: NotificationFixtures.empty);
}

@UseCase(
  name: 'Populated',
  type: NotificationPanel,
  path: '[Widgets]/Notifications',
)
Widget buildPopulatedNotificationPanel(BuildContext context) {
  return _NotificationPanelStory(status: NotificationFixtures.populated());
}

@UseCase(
  name: 'Do not disturb',
  type: NotificationPanel,
  path: '[Widgets]/Notifications',
)
Widget buildDoNotDisturbNotificationPanel(BuildContext context) {
  return const _NotificationPanelStory(
    status: NotificationFixtures.doNotDisturb,
  );
}

@UseCase(
  name: 'Service unavailable',
  type: NotificationPanel,
  path: '[Widgets]/Notifications',
)
Widget buildUnavailableNotificationPanel(BuildContext context) {
  return const _NotificationPanelStory(
    status: NotificationFixtures.unavailable,
  );
}

@UseCase(
  name: 'Overflow',
  type: NotificationPanel,
  path: '[Widgets]/Notifications',
)
Widget buildOverflowNotificationPanel(BuildContext context) {
  return _NotificationPanelStory(status: NotificationFixtures.overflow());
}

@UseCase(
  name: 'Interactive inbox',
  type: NotificationPanel,
  path: '[Widgets]/Notifications',
)
Widget buildInteractiveNotificationPanel(BuildContext context) {
  return const _InteractiveNotificationPanelStory();
}

class _NotificationPanelStory extends StatelessWidget {
  const _NotificationPanelStory({required this.status});

  final NotificationStatus status;

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: NotificationPanel(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        status: status,
        onDismiss: (_) {},
        onClearAll: _noop,
      ),
    );
  }
}

class _InteractiveNotificationPanelStory extends StatefulWidget {
  const _InteractiveNotificationPanelStory();

  @override
  State<_InteractiveNotificationPanelStory> createState() =>
      _InteractiveNotificationPanelStoryState();
}

class _InteractiveNotificationPanelStoryState
    extends State<_InteractiveNotificationPanelStory> {
  late List<NotificationEntry> entries;

  @override
  void initState() {
    super.initState();
    entries = List<NotificationEntry>.of(
      NotificationFixtures.populated().entries,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: NotificationPanel(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        status: NotificationStatus(
          available: true,
          entries: entries,
          unreadCount: entries.length,
          dndEnabled: false,
        ),
        onDismiss: (int id) {
          setState(() {
            entries = entries
                .where((NotificationEntry entry) => entry.id != id)
                .toList();
          });
        },
        onClearAll: () {
          setState(() {
            entries = <NotificationEntry>[];
          });
        },
      ),
    );
  }
}

void _noop() {}
