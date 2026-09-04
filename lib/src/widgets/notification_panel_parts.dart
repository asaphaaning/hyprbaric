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
  });

  final int count;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return HyprPanelHeader(
      title: 'Notifications',
      uppercaseTitle: true,
      titleTrailing: count > 0 ? NotificationCountPill(count: count) : null,
      actionKey: const ValueKey<String>('notifications-clear-all'),
      actionLabel: 'clear all',
      actionEnabled: count > 0,
      onAction: onClearAll,
      titleTrailingGap: 8,
      titleStyle: HyprTypography.popTitle.copyWith(
        color: NotificationPalette.fg3,
        fontSize: HyprTypography.size(10.5),
        letterSpacing: 0.84,
        fontWeight: FontWeight.w600,
      ),
      actionColor: NotificationPalette.fg3,
      actionStyle: HyprTypography.compactMono.copyWith(
        fontSize: HyprTypography.size(11),
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
          separatorBuilder: (_, _) => const SizedBox(height: 14),
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
      color: NotificationPalette.placeholderFill,
      borderColor: NotificationPalette.placeholderStroke,
      borderRadius: HyprRadii.controlRadius,
      messageStyle: HyprTypography.compactMonoStrong.copyWith(
        color: NotificationPalette.fg2,
        fontSize: HyprTypography.size(11),
        fontWeight: FontWeight.w600,
        letterSpacing: 0.44,
      ),
      subtitleStyle: HyprTypography.compactMono.copyWith(
        color: NotificationPalette.fg3,
        fontSize: HyprTypography.size(10),
        letterSpacing: 0.2,
      ),
    );
  }
}
