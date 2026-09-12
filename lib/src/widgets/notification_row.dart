import 'package:flutter/material.dart';
import '../bindings/bindings.dart';
import 'hypr_surface.dart';
import 'notification_panel_style.dart';
import 'primitives/primitives.dart';

/// An application, message and relative age, with explicit dismissal.
class NotificationRow extends StatelessWidget {
  const NotificationRow({
    super.key,
    required this.entry,
    required this.onDismiss,
    this.now,
  });
  final NotificationEntry entry;
  final DateTime? now;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final accent = notificationAccent(entry);
    return RepaintBoundary(
      child: HyprInteractionRegion(
        builder: (context, state) => AnimatedContainer(
          duration: HyprMotion.hover,
          decoration: BoxDecoration(
            color: state.hovered
                ? NotificationPalette.tileHovered
                : NotificationPalette.tile,
            border: Border.all(color: NotificationPalette.tileBorder),
            borderRadius: BorderRadius.circular(11),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: .5)),
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: .18),
                      const Color(0x99070B14),
                    ],
                  ),
                ),
                child: Icon(
                  NotificationSource.fromName(entry.app).icon,
                  size: 27,
                  color: accent,
                ),
              ),
              Container(
                width: 1,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: const Color(0x50445270),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.app.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HyprInstrumentText.meta.copyWith(
                        color: accent,
                        letterSpacing: .9,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HyprInstrumentText.body.copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                notificationAgeLabel(entry.createdAtMs, now: now).toUpperCase(),
                style: HyprInstrumentText.meta.copyWith(fontSize: 10.5),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: onDismiss,
                style: hyprCompactIconButtonStyle(
                  size: const Size.square(24),
                  foregroundColor: HyprInstrumentColors.secondary,
                ),
                icon: const Icon(Icons.close_rounded, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
