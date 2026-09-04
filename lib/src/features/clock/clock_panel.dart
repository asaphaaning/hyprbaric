import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'clock_controller.dart';

class ClockPanel extends StatelessWidget {
  const ClockPanel({
    super.key,
    required this.status,
    required this.onCommand,
    required this.borderRadius,
  });

  final ClockViewState status;
  final ValueChanged<CalendarCommand> onCommand;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return HyprPopoverSurface(
      borderRadius: borderRadius,
      borderColor: HyprColors.popupStroke,
      child: SizedBox(
        width: 260,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _CalendarHeader(
                monthLabel: status.monthLabel,
                onPrevious: () => onCommand(CalendarCommand.previousMonth),
                onToday: () => onCommand(CalendarCommand.today),
                onNext: () => onCommand(CalendarCommand.nextMonth),
              ),
              const SizedBox(height: 10),
              _CalendarGrid(days: status.days),
              const SizedBox(height: 8),
              const _ClockDivider(),
              const SizedBox(height: 8),
              _CalendarFooter(
                weekNumber: status.weekNumber,
                utcOffset: status.utcOffset,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.monthLabel,
    required this.onPrevious,
    required this.onToday,
    required this.onNext,
  });

  final String monthLabel;
  final VoidCallback onPrevious;
  final VoidCallback onToday;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return HyprPanelHeader(
      title: monthLabel,
      titleStyle: HyprTypography.compactMonoStrong.copyWith(
        fontSize: HyprTypography.size(13),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _CalendarNavButton(
            icon: Icons.chevron_left_rounded,
            label: 'Previous month',
            onPressed: onPrevious,
          ),
          _CalendarNavButton(
            icon: Icons.circle_rounded,
            label: 'Today',
            iconSize: 7,
            onPressed: onToday,
          ),
          _CalendarNavButton(
            icon: Icons.chevron_right_rounded,
            label: 'Next month',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _CalendarNavButton extends StatelessWidget {
  const _CalendarNavButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.iconSize = 17,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        onPressed: onPressed,
        style: hyprCompactIconButtonStyle(
          size: const Size.square(24),
          radius: 5,
          foregroundColor: _ClockColors.fg2,
        ),
        icon: Icon(icon, size: iconSize),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({required this.days});

  final List<CalendarDay> days;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      children: <Widget>[
        for (final String label in const <String>[
          'M',
          'T',
          'W',
          'T',
          'F',
          'S',
          'S',
        ])
          _CalendarDowCell(label: label),
        for (final CalendarDay day in days) _CalendarDayCell(day: day),
      ],
    );
  }
}

class _CalendarDowCell extends StatelessWidget {
  const _CalendarDowCell({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: HyprTypography.metricLabel.copyWith(
          color: _ClockColors.fg3,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({required this.day});

  final CalendarDay day;

  @override
  Widget build(BuildContext context) {
    final bool isToday = day.today;
    final Color textColor = isToday
        ? const Color(0xFF071018)
        : day.currentMonth
        ? _ClockColors.fg1
        : _ClockColors.fg3;

    return Material(
      color: isToday ? HyprColors.accentSoft : Colors.transparent,
      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(6)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {},
        hoverColor: isToday ? Colors.transparent : HyprColors.hover,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        customBorder: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: isToday
                ? const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x5522BFFF),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              '${day.day}',
              style: HyprTypography.compactMonoStrong.copyWith(
                color: textColor,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarFooter extends StatelessWidget {
  const _CalendarFooter({required this.weekNumber, required this.utcOffset});

  final int weekNumber;
  final String utcOffset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text.rich(
            TextSpan(
              text: 'Week ',
              children: <InlineSpan>[
                TextSpan(
                  text: '$weekNumber',
                  style: HyprTypography.compactMonoStrong.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HyprTypography.popRow.copyWith(
              color: _ClockColors.fg2,
              fontSize: HyprTypography.size(11.5),
            ),
          ),
        ),
        Text(
          utcOffset,
          style: HyprTypography.compactMonoStrong.copyWith(
            color: _ClockColors.fg2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ClockDivider extends StatelessWidget {
  const _ClockDivider();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Colors.transparent,
            HyprColors.borderSoft.withValues(alpha: 0.90),
            Colors.transparent,
          ],
        ),
      ),
      child: const SizedBox(height: 1),
    );
  }
}

abstract final class _ClockColors {
  static const Color fg1 = Color(0xECCBD2DA);
  static const Color fg2 = Color(0xC8BEC7D0);
  static const Color fg3 = Color(0xA0929DA8);
}
