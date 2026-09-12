import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bindings/bindings.dart';
import 'hypr_surface.dart';
import 'notification_panel_parts.dart';

/// Width of the notification centre.
///
/// The dropdown that hosts this panel sizes its overlay slot from the same
/// constant. Keeping one number here stops the panel from declaring a width
/// the layer-shell slot silently clamps away.
const double kNotificationPanelWidth = 450;

class NotificationPanel extends StatelessWidget {
  const NotificationPanel({
    super.key,
    required this.borderRadius,
    required this.status,
    required this.onDismiss,
    required this.onClearAll,
  });

  final BorderRadius borderRadius;

  /// The raw snapshot stream, kept as an [AsyncValue] so the panel can tell a
  /// pending first frame apart from a daemon that genuinely has nothing to
  /// show. AudioPanel and NetworkPanel take the same shape.
  final AsyncValue<NotificationStatus> status;
  final ValueChanged<int> onDismiss;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final NotificationStatus? snapshot = status.asData?.value;
    final List<NotificationEntry> entries = snapshot?.entries ?? const [];

    return HyprInstrumentSurface(
      borderRadius: borderRadius,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: kNotificationPanelWidth,
          maxWidth: kNotificationPanelWidth,
          maxHeight: 420,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              NotificationHeader(
                // Clearing depends on retained entries, even when DND zeroes
                // the backend's unread badge.
                count: entries.length,
                unreadCount: snapshot?.unreadCount ?? 0,
                onClearAll: onClearAll,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: Color(0x404D5974)),
              ),
              _body(snapshot, entries),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(NotificationStatus? snapshot, List<NotificationEntry> entries) {
    if (snapshot == null) {
      return NotificationPlaceholder(
        label: status.hasError ? 'Notifications unavailable' : 'Loading',
        subtitle: status.hasError ? 'could not reach the bar service' : null,
      );
    }
    // Availability outranks the entry list. A lost daemon leaves whatever it
    // last sent behind, and that copy is stale rather than current.
    if (!snapshot.available) {
      return NotificationPlaceholder(
        label: 'Notifications unavailable',
        subtitle: snapshot.message ?? 'notification service is offline',
      );
    }
    if (entries.isEmpty) {
      return NotificationPlaceholder(
        label: snapshot.dndEnabled ? 'Do not disturb' : 'No notifications',
        subtitle: snapshot.dndEnabled
            ? 'notifications are being suppressed'
            : snapshot.message,
      );
    }
    return Flexible(
      child: NotificationList(entries: entries, onDismiss: onDismiss),
    );
  }
}
