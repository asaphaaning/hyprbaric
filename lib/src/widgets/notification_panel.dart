import 'package:flutter/material.dart';

import '../bindings/bindings.dart';
import 'hypr_surface.dart';
import 'notification_panel_parts.dart';
import 'notification_panel_style.dart';

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
  final NotificationStatus? status;
  final ValueChanged<int> onDismiss;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final NotificationStatus? snapshot = status;
    final List<NotificationEntry> entries = snapshot?.entries ?? const [];
    final bool available = snapshot?.available ?? true;

    return HyprPopoverSurface(
      borderRadius: borderRadius,
      color: const Color(0xE6070E17),
      borderColor: HyprColors.popupStroke,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              NotificationPalette.chassisTop,
              NotificationPalette.chassisBottom,
            ],
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: kNotificationPanelWidth,
            maxWidth: kNotificationPanelWidth,
            maxHeight: 388,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                NotificationHeader(
                  count: entries.length,
                  onClearAll: onClearAll,
                ),
                const SizedBox(height: 10),
                if (entries.isEmpty)
                  NotificationEmptyState(
                    available: available,
                    message: snapshot?.message,
                  )
                else
                  Flexible(
                    child: NotificationList(
                      entries: entries,
                      onDismiss: onDismiss,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
