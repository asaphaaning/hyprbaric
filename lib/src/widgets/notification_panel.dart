import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bindings/bindings.dart';
import 'hypr_surface.dart';
import 'notification_panel_parts.dart';
import 'notification_panel_style.dart';
import 'primitives/primitives.dart';

/// Width of the notification centre.
///
/// The dropdown that hosts this panel sizes its overlay slot from the same
/// constant. Keeping one number here stops the panel from declaring a width
/// the layer-shell slot silently clamps away.
const double kNotificationPanelWidth = 380;

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
  /// show. [AudioPanel] and [NetworkPanel] take the same shape.
  final AsyncValue<NotificationStatus> status;
  final ValueChanged<int> onDismiss;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final NotificationStatus? snapshot = status.asData?.value;
    final List<NotificationEntry> entries = snapshot?.entries ?? const [];

    return HyprPopoverPanel(
      borderRadius: borderRadius,
      borderColor: HyprColors.popupStroke,
      constraints: const BoxConstraints(
        minWidth: kNotificationPanelWidth,
        maxWidth: kNotificationPanelWidth,
        maxHeight: 388,
      ),
      padding: HyprSpacing.panelAll,
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          NotificationPalette.chassisTop,
          NotificationPalette.chassisBottom,
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          NotificationHeader(
            // Deliberately the length of the list this pill labels, not
            // snapshot.unreadCount, which Rust documents as the bell's
            // number and zeroes under do-not-disturb.
            count: entries.length,
            onClearAll: onClearAll,
          ),
          const SizedBox(height: 10),
          _body(snapshot, entries),
        ],
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
