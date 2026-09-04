import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/right_cluster_buttons.dart';
import 'power_colors.dart';
import 'power_formatting.dart';

class BatteryChip extends StatelessWidget {
  const BatteryChip({
    super.key,
    required this.status,
    required this.isOpen,
    required this.onPressed,
  });

  final PowerStatus? status;
  final bool isOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool batteryPresent = status?.batteryPresent ?? false;
    final int percentage = status?.percentage?.clamp(0, 100) ?? 0;
    return Semantics(
      button: true,
      label: batteryPresent
          ? 'Battery ${formatBatteryPercent(status)}'
          : 'Power profile',
      child: Material(
        color: isOpen ? HyprColors.hoverStrong : Colors.transparent,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(HyprRadii.row),
          side: isOpen
              ? const BorderSide(color: HyprColors.border, width: 1.1)
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
              padding: EdgeInsets.symmetric(horizontal: batteryPresent ? 7 : 0),
              child: batteryPresent
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        BatteryIcon(
                          percentage: percentage,
                          present: true,
                          fillColor: batteryFillColor(percentage),
                        ),
                        const SizedBox(width: HyprSpacing.lg),
                        Text(
                          formatBatteryPercent(status),
                          style: HyprTypography.barMono.copyWith(
                            color: HyprColors.textMuted,
                            fontSize: HyprTypography.size(11.5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: HyprIconSizes.barButton.width,
                      child: const IconTheme(
                        data: IconThemeData(color: HyprColors.textMuted),
                        child: Center(
                          child: BarGlyphIcon(
                            icon: Iconsax.flash_circle_copy,
                            size: HyprIconSizes.bar,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class BatteryIcon extends StatelessWidget {
  const BatteryIcon({
    super.key,
    required this.percentage,
    required this.present,
    required this.fillColor,
  });

  final int percentage;
  final bool present;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 15,
      child: CustomPaint(
        painter: _BatteryIconPainter(
          percentage: percentage,
          present: present,
          fillColor: fillColor,
        ),
      ),
    );
  }
}

Color batteryFillColor(int percentage) {
  if (percentage < 20) {
    return PowerColors.critical;
  }
  if (percentage < 40) {
    return PowerColors.low;
  }
  return PowerColors.healthy;
}

class _BatteryIconPainter extends CustomPainter {
  const _BatteryIconPainter({
    required this.percentage,
    required this.present,
    required this.fillColor,
  });

  final int percentage;
  final bool present;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bodyRect = Rect.fromLTWH(
      0.9,
      1.8,
      size.width - 5.2,
      size.height - 3.6,
    );
    final RRect body = RRect.fromRectAndRadius(
      bodyRect,
      const Radius.circular(4.2),
    );
    final RRect nub = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width - 4.1, size.height / 2 - 3.8, 3.2, 7.6),
      const Radius.circular(1.8),
    );
    final Paint stroke = Paint()
      ..color = HyprColors.textMuted.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;
    final Paint capStroke = Paint()
      ..color = HyprColors.textMuted.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final Paint fill = Paint()
      ..color = present
          ? fillColor
          : HyprColors.textFaint.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final double fillWidth = ((bodyRect.width - 4) * (percentage / 100)).clamp(
      1.4,
      bodyRect.width - 4,
    );
    final RRect fillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        bodyRect.left + 2,
        bodyRect.top + 2,
        fillWidth,
        bodyRect.height - 4,
      ),
      const Radius.circular(2.6),
    );

    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRRect(fillRect, fill);
    canvas.restore();

    canvas.drawRRect(body, stroke);
    canvas.drawRRect(nub, capStroke);
  }

  @override
  bool shouldRepaint(covariant _BatteryIconPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.present != present ||
        oldDelegate.fillColor != fillColor;
  }
}
