import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';
import '../../audio/notification_panel_preview.dart';
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
  return const CatalogCanvas(child: NotificationPanelPreview());
}

class _NotificationPanelStory extends StatelessWidget {
  const _NotificationPanelStory({required this.status});

  final NotificationStatus status;

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: NotificationPanel(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        status: AsyncValue.data(status),
        onDismiss: (_) {},
        onClearAll: _noop,
      ),
    );
  }
}

void _noop() {}
