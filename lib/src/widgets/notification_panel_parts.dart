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
        color: HyprColors.accentSoft,
        borderColor: Colors.white.withValues(alpha: 0.08),
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
    final String subtitle = available
        ? "you're all caught up"
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const _PatchJack(),
            const SizedBox(height: 12),
            Text(
              label,
              style: HyprTypography.compactMonoStrong.copyWith(
                color: NotificationPalette.fg2,
                fontSize: HyprTypography.size(11),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.44,
              ),
            ),
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
        ),
      ),
    );
  }
}

class _PatchJack extends StatelessWidget {
  const _PatchJack();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.30, -0.44),
          radius: 0.90,
          colors: <Color>[
            Color(0xFF34383E),
            Color(0xFF080B10),
            Color(0xFF010203),
          ],
          stops: <double>[0, 0.60, 1],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(7),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: Alignment(-0.30, -0.40),
            radius: 0.90,
            colors: <Color>[Color(0xFF04060A), Color(0xFF000001)],
            stops: <double>[0, 0.80],
          ),
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF000000),
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Color(0xE6000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
