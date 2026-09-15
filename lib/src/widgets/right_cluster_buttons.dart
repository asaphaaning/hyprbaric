import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../features/clock/clock_controller.dart';
import 'hypr_surface.dart';
import 'primitives/primitives.dart';

ButtonStyle barIconActionButtonStyle({required bool isOpen}) {
  return hyprCompactIconButtonStyle(
    active: isOpen,
    size: HyprIconSizes.barButton,
    radius: HyprRadii.panel,
  );
}

ButtonStyle barPowerButtonStyle({required bool isOpen}) {
  return hyprCompactIconButtonStyle(
    active: isOpen,
    danger: true,
    size: HyprIconSizes.compactButton,
    radius: HyprRadii.compact,
  );
}

class BarIconActionButton extends StatelessWidget {
  const BarIconActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isOpen,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        onPressed: onPressed,
        style: barIconActionButtonStyle(isOpen: isOpen),
        icon: BarGlyphIcon(icon: icon, size: HyprIconSizes.bar),
      ),
    );
  }
}

class BarGlyphIcon extends StatelessWidget {
  const BarGlyphIcon({super.key, required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!_isIconsaxIcon(icon)) {
      return Icon(icon, size: size);
    }

    final Color glyphColor =
        IconTheme.of(context).color ?? HyprColors.textMuted;
    final TextStyle glyphStyle = TextStyle(
      inherit: false,
      color: glyphColor,
      fontFamily: icon.fontFamily,
      package: icon.fontPackage,
      fontSize: size,
      height: 1,
    );
    final Paint strokePaint = Paint()
      ..color = glyphColor.withValues(alpha: glyphColor.a * 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.58;
    return SizedBox.square(
      key: _iconsaxGlyphKey(icon),
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          ExcludeSemantics(
            child: Text(
              String.fromCharCode(icon.codePoint),
              style: glyphStyle.copyWith(foreground: strokePaint),
              textAlign: TextAlign.center,
            ),
          ),
          Text(
            String.fromCharCode(icon.codePoint),
            style: glyphStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class AudioDisplayButton extends StatelessWidget {
  const AudioDisplayButton({
    super.key,
    required this.isOpen,
    required this.onPressed,
  });

  final bool isOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Audio and display controls',
      child: IconButton(
        onPressed: onPressed,
        style: barIconActionButtonStyle(isOpen: isOpen),
        icon: Builder(
          builder: (BuildContext context) {
            final Color glyphColor =
                IconTheme.of(context).color ?? HyprColors.textMuted;
            return BarVolumeKnobIcon(color: glyphColor);
          },
        ),
      ),
    );
  }
}

class BarVolumeKnobIcon extends StatelessWidget {
  const BarVolumeKnobIcon({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      key: const ValueKey<String>('bar-volume-knob-icon'),
      dimension: HyprIconSizes.bar,
      child: CustomPaint(painter: _BarVolumeKnobPainter(color)),
    );
  }
}

class NotificationButton extends StatelessWidget {
  const NotificationButton({
    super.key,
    required this.unreadCount,
    required this.isOpen,
    required this.onPressed,
  });

  final int unreadCount;
  final bool isOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool showBadge = unreadCount > 0;
    return Semantics(
      button: true,
      label: unreadCount > 0
          ? 'Notifications, $unreadCount unread'
          : 'Notifications',
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          IconButton(
            key: const ValueKey<String>('notifications-button'),
            onPressed: onPressed,
            style: barIconActionButtonStyle(isOpen: isOpen),
            icon: BarGlyphIcon(
              icon: showBadge
                  ? Iconsax.notification_bing_copy
                  : Iconsax.notification_copy,
              size: HyprIconSizes.bar,
            ),
          ),
          if (showBadge)
            Positioned(
              right: 5,
              top: 5,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.hyprPalette.accentSoft,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: context.hyprPalette.accentSoft.withValues(
                          alpha: .4,
                        ),
                        blurRadius: 8,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                  child: const SizedBox.square(dimension: 6),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ClockButton extends StatelessWidget {
  const ClockButton({
    super.key,
    required this.status,
    required this.isOpen,
    required this.onPressed,
  });

  final ClockViewState status;
  final bool isOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final String timeLabel = status.timeLabel;
    final String dateLabel = status.dateLabel;
    return Semantics(
      button: true,
      label: '$dateLabel, $timeLabel',
      child: Material(
        color: isOpen ? HyprColors.hoverStrong : Colors.transparent,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(HyprRadii.row),
          side: isOpen
              ? const BorderSide(color: HyprColors.border, width: 1.2)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          hoverColor: HyprColors.hover,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          customBorder: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(HyprRadii.row),
          ),
          child: SizedBox(
            height: HyprIconSizes.compactButton.height + HyprSpacing.xxs,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HyprSpacing.panel,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(dateLabel, style: HyprTypography.clockDate),
                  const SizedBox(width: HyprSpacing.xxl),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      color: HyprColors.textFaint,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(dimension: HyprSpacing.xs),
                  ),
                  const SizedBox(width: HyprSpacing.xxl),
                  Text(timeLabel, style: HyprTypography.clockTime),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PowerButton extends StatelessWidget {
  const PowerButton({super.key, required this.isOpen, required this.onPressed});

  final bool isOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Session actions',
      child: IconButton(
        key: const ValueKey<String>('session-actions-button'),
        onPressed: onPressed,
        style: barPowerButtonStyle(isOpen: isOpen),
        icon: const Icon(
          Icons.power_settings_new_rounded,
          size: HyprIconSizes.compact,
        ),
      ),
    );
  }
}

bool _isIconsaxIcon(IconData icon) => icon.fontPackage == 'iconsax_flutter';

ValueKey<String> _iconsaxGlyphKey(IconData icon) =>
    ValueKey<String>('iconsax-glyph-${icon.codePoint}');

class _BarVolumeKnobPainter extends CustomPainter {
  const _BarVolumeKnobPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double scale = size.shortestSide / 17;
    final Paint marker = Paint()
      ..color = color.withValues(alpha: color.a * 0.9)
      ..style = PaintingStyle.fill;
    final Paint centerFill = Paint()
      ..color = color.withValues(alpha: color.a * 0.86)
      ..style = PaintingStyle.fill;
    final Paint hand = Paint()
      ..color = HyprColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale
      ..strokeCap = StrokeCap.round;

    for (int index = 0; index < 8; index += 1) {
      final double angle = (math.pi * 2 * index / 8) - math.pi / 2;
      final Offset dot =
          center + Offset(math.cos(angle), math.sin(angle)) * 6.4 * scale;
      canvas.drawCircle(dot, 1.35 * scale, marker);
    }

    canvas.drawCircle(center, 4.85 * scale, centerFill);
    canvas.drawLine(
      center + Offset(-1.4 * scale, 1.6 * scale),
      center + Offset(1.8 * scale, -1.6 * scale),
      hand,
    );
  }

  @override
  bool shouldRepaint(covariant _BarVolumeKnobPainter oldDelegate) =>
      oldDelegate.color != color;
}
