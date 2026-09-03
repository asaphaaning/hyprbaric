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
      actionLabel: count > 0 ? 'clear all' : null,
      onAction: count > 0 ? onClearAll : null,
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
        color: HyprColors.accentSoft.withValues(alpha: 0.34),
        borderColor: HyprColors.popupStroke,
        borderRadius: BorderRadius.circular(4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        textColor: HyprColors.accent,
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

  final List<NotificationEntry> entries;
  final ValueChanged<int> onDismiss;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (BuildContext context, int index) {
        final NotificationEntry entry = entries[index];
        return NotificationRow(
          entry: entry,
          onDismiss: () => onDismiss(entry.id),
        );
      },
    );
  }
}

class NotificationEmptyState extends StatelessWidget {
  const NotificationEmptyState({
    super.key,
    required this.available,
    this.message,
  });

  final bool available;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final String label = available
        ? 'No notifications'
        : 'Notifications unavailable';
    final String? subtitle = available
        ? null
        : (message ?? 'notification service is offline');

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Colors.black.withValues(alpha: 0.40),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.55)),
        ),
        shadows: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: HyprTypography.compactMonoStrong.copyWith(
                color: NotificationPalette.fg2,
                fontSize: HyprTypography.size(11),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.44,
              ),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: HyprTypography.compactMono.copyWith(
                  color: NotificationPalette.fg3,
                  fontSize: HyprTypography.size(10),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
