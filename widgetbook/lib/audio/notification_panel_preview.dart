import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';

import '../use_cases/notifications/notification_fixtures.dart';

/// Interactive notification inbox shared by Widgetbook and the website.
class NotificationPanelPreview extends StatefulWidget {
  const NotificationPanelPreview({super.key, this.initialStatus});

  final NotificationStatus? initialStatus;

  @override
  State<NotificationPanelPreview> createState() =>
      _NotificationPanelPreviewState();
}

class _NotificationPanelPreviewState extends State<NotificationPanelPreview> {
  late List<NotificationEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = _seed();
  }

  @override
  void didUpdateWidget(NotificationPanelPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Widgetbook swaps the seed when a knob changes, so the local copy has to
    // follow it rather than stay pinned to whatever initState first saw.
    if (widget.initialStatus != oldWidget.initialStatus) {
      _entries = _seed();
    }
  }

  List<NotificationEntry> _seed() {
    return List<NotificationEntry>.of(
      (widget.initialStatus ?? NotificationFixtures.populated()).entries,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationPanel(
      borderRadius: HyprRadii.popoverRadius,
      status: AsyncValue.data(
        NotificationStatus(
          available: true,
          entries: _entries,
          unreadCount: _entries.length,
          dndEnabled: false,
        ),
      ),
      onDismiss: _dismiss,
      onClearAll: _clearAll,
    );
  }

  void _dismiss(int id) {
    setState(() {
      _entries = _entries
          .where((NotificationEntry entry) => entry.id != id)
          .toList(growable: false);
    });
  }

  void _clearAll() => setState(() => _entries = const <NotificationEntry>[]);
}
