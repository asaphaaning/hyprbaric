import 'package:flutter/material.dart';

import '../bindings/bindings.dart';
import 'hypr_surface.dart';
import 'notification_panel_style.dart';
import 'notification_row.dart';
import 'primitives/primitives.dart';

class NotificationHeader extends StatelessWidget {
  const NotificationHeader({
    super.key,
    required this.count,
    required this.onClearAll,
    this.unreadCount,
  });

  final int count;
  final int? unreadCount;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return HyprInstrumentHeader(
      title: 'Notifications',
      icon: const Icon(Icons.notifications_none_rounded),
      subtitle: '${unreadCount ?? count} UNREAD',
      trailing: OutlinedButton(
        key: const ValueKey<String>('notifications-clear-all'),
        onPressed: count > 0 ? onClearAll : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: HyprInstrumentColors.secondary,
          side: const BorderSide(color: Color(0x60566889)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          textStyle: HyprInstrumentText.meta,
        ),
        child: const Text('CLEAR ALL'),
      ),
    );
  }
}

class NotificationCountPill extends StatelessWidget {
  const NotificationCountPill({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey<String>('notifications-count-pill'),
      child: HyprBadge.text(
        label: '$count',
        color: context.hyprPalette.accentSoft.withValues(alpha: 0.34),
        borderColor: HyprColors.popupStroke,
        borderRadius: BorderRadius.circular(4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        textColor: context.hyprPalette.accent,
        style: HyprTypography.compactMonoStrong.copyWith(
          fontSize: HyprTypography.size(10),
          height: 1,
        ),
      ),
    );
  }
}

class NotificationList extends StatelessWidget {
  const NotificationList({
    super.key,
    required this.entries,
    required this.onDismiss,
  });

  /// How often mounted rows re-stamp their age label.
  ///
  /// The list is only built while the dropdown is open, so the timer lives
  /// exactly as long as the panel is on screen.
  static const Duration ageTick = Duration(seconds: 30);

  final List<NotificationEntry> entries;
  final ValueChanged<int> onDismiss;

  @override
  Widget build(BuildContext context) {
    // Rows render a relative age, so the list rebuilds on an interval while
    // the panel is open or every timestamp freezes at whatever it read when
    // the popover opened.
    return HyprIntervalRebuild(
      interval: ageTick,
      builder: (BuildContext context) {
        final DateTime now = DateTime.now();

        return ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (BuildContext context, int index) {
            final NotificationEntry entry = entries[index];

            return NotificationRow(
              // Identity hygiene. Lazy slivers rebuild state per index slot either
              // way, so this buys correctness only if the list stops being lazy.
              key: ValueKey<int>(entry.id),
              entry: entry,
              now: now,
              onDismiss: () => onDismiss(entry.id),
            );
          },
        );
      },
    );
  }
}

class NotificationPlaceholder extends StatelessWidget {
  const NotificationPlaceholder({
    super.key,
    required this.label,
    this.subtitle,
  });

  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return HyprEmptyState(
      message: label,
      subtitle: subtitle,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      color: NotificationPalette.tile,
      borderColor: NotificationPalette.tileBorder,
      borderRadius: BorderRadius.circular(11),
      messageStyle: HyprInstrumentText.body.copyWith(fontSize: 14),
      subtitleStyle: HyprInstrumentText.meta,
    );
  }
}
