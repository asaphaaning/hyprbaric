import 'package:flutter/material.dart';

import '../bindings/bindings.dart';
import 'hypr_surface.dart';
import 'notification_panel_style.dart';
import 'primitives/primitives.dart';

class NotificationRow extends StatelessWidget {
  const NotificationRow({
    super.key,
    required this.entry,
    required this.onDismiss,
    this.now,
  });

  final NotificationEntry entry;

  /// Observation time for the age label, re-stamped by [NotificationList] so
  /// the shipped path is the one the tests exercise.
  final DateTime? now;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final Color accent = notificationAccent(entry);

    return HyprInteractionRegion(
      builder: (BuildContext context, HyprInteractionState state) {
        // HyprInteractionRegion only reports pressed when a tap handler is
        // wired, and this row has none, so hover is the only live phase.
        final NotificationTilePhase phase = state.hovered
            ? NotificationTilePhase.hovered
            : NotificationTilePhase.idle;
        final NotificationTileStyle style = NotificationTileStyle.forPhase(
          phase,
        );

        return AnimatedContainer(
          duration: HyprMotion.hover,
          curve: HyprMotion.hoverCurve,
          constraints: const BoxConstraints(minHeight: 40),
          decoration: ShapeDecoration(
            color: style.base,
            shape: RoundedSuperellipseBorder(
              borderRadius: HyprRadii.tileRadius,
              side: BorderSide(color: style.border),
            ),
            shadows: <BoxShadow>[
              BoxShadow(
                color: style.shadow,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const <double>[0, 0.42, 1],
                        colors: <Color>[
                          style.topLight,
                          style.topLight.withValues(
                            alpha: style.topLight.a * 0.22,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 62,
                      child: _NotificationAppLabel(
                        app: entry.app,
                        accent: accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HyprTypography.notificationText.copyWith(
                          color: NotificationPalette.fg1,
                          fontSize: HyprTypography.size(12),
                          height: 1.15,
                          letterSpacing: -0.06,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _NotificationTimeLabel(
                      label: notificationAgeLabel(entry.createdAtMs, now: now),
                    ),
                    const SizedBox(width: 10),
                    IgnorePointer(
                      ignoring: !state.hovered,
                      child: AnimatedOpacity(
                        duration: HyprMotion.hover,
                        opacity: state.hovered ? 0.8 : 0,
                        child: _NotificationDismissButton(onPressed: onDismiss),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationAppLabel extends StatelessWidget {
  const _NotificationAppLabel({required this.app, required this.accent});

  final String app;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Text(
      app.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: HyprTypography.compactMonoStrong.copyWith(
        color: accent,
        fontSize: HyprTypography.size(9),
        fontWeight: FontWeight.w700,
        letterSpacing: 1.26,
        height: 1,
        shadows: <Shadow>[
          Shadow(color: accent.withValues(alpha: 0.42), blurRadius: 4),
        ],
      ),
    );
  }
}

class _NotificationTimeLabel extends StatelessWidget {
  const _NotificationTimeLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      maxLines: 1,
      style: HyprTypography.compactMono.copyWith(
        color: NotificationPalette.warmTime,
        fontSize: HyprTypography.size(9),
        letterSpacing: 0.54,
        height: 1,
        fontFeatures: HyprTypography.tabularNumbers,
        shadows: const <Shadow>[
          Shadow(color: Color(0x668F765E), blurRadius: 4),
        ],
      ),
    );
  }
}

class _NotificationDismissButton extends StatelessWidget {
  const _NotificationDismissButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Dismiss',
      onPressed: onPressed,
      // The shared style already carries sizing, shape, overlay suppression
      // and, unlike the open-coded version this replaces, a focused state.
      style:
          hyprCompactIconButtonStyle(
            size: const Size.square(22),
            radius: HyprRadii.control,
            foregroundColor: NotificationPalette.fg3,
            hoverForegroundColor: const Color(0xFFE19A8E),
            hoverBackgroundColor: HyprColors.danger.withValues(alpha: 0.15),
          ).copyWith(
            side: WidgetStateProperty.resolveWith<BorderSide>((
              Set<WidgetState> states,
            ) {
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.pressed) ||
                  states.contains(WidgetState.focused)) {
                return BorderSide(
                  color: HyprColors.danger.withValues(alpha: 0.45),
                );
              }
              return BorderSide.none;
            }),
          ),
      icon: const _CloseSquareIcon(),
    );
  }
}

class _CloseSquareIcon extends StatelessWidget {
  const _CloseSquareIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(11),
      painter: _CloseSquarePainter(
        color: IconTheme.of(context).color ?? NotificationPalette.fg3,
      ),
    );
  }
}

class _CloseSquarePainter extends CustomPainter {
  const _CloseSquarePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final RRect frame = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(2.25),
    );
    canvas.drawRRect(frame, paint);
    canvas.drawLine(
      Offset(size.width * 0.32, size.height * 0.32),
      Offset(size.width * 0.68, size.height * 0.68),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.68, size.height * 0.32),
      Offset(size.width * 0.32, size.height * 0.68),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CloseSquarePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
