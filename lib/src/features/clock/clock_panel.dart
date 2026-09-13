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
    return HyprPopoverPanel(
      borderRadius: borderRadius,
      constraints: const BoxConstraints.tightFor(width: 288),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const HyprInstrumentHeader(
            title: 'Calendar',
            icon: Icon(Icons.calendar_month_outlined),
          ),
          const HyprSectionBreak(before: 14, after: 12),
          _CalendarHeader(
            monthLabel: status.monthLabel,
            onPrevious: () => onCommand(CalendarCommand.previousMonth),
            onToday: () => onCommand(CalendarCommand.today),
            onNext: () => onCommand(CalendarCommand.nextMonth),
          ),
          const SizedBox(height: 10),
          _CalendarGrid(days: status.days),
          const HyprSectionBreak(before: 12, after: 12),
          _CalendarFooter(
            weekNumber: status.weekNumber,
            utcOffset: status.utcOffset,
          ),
        ],
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
      titleStyle: HyprInstrumentText.body.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
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
            icon: Icons.today_outlined,
            label: 'Today',
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
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      style: hyprCompactIconButtonStyle(
        size: const Size.square(28),
        radius: 7,
        foregroundColor: HyprInstrumentColors.secondary,
      ),
      icon: Icon(icon, size: 17),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({required this.days});

  final List<CalendarDay> days;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (final String label in const <String>[
              'Mon',
              'Tue',
              'Wed',
              'Thu',
              'Fri',
              'Sat',
              'Sun',
            ])
              Expanded(child: _CalendarDowCell(label: label)),
          ],
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: <Widget>[
            for (final CalendarDay day in days) _CalendarDayCell(day: day),
          ],
        ),
      ],
    );
  }
}

class _CalendarDowCell extends StatelessWidget {
  const _CalendarDowCell({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Center(child: Text(label, style: HyprInstrumentText.meta)),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({required this.day});

  final CalendarDay day;

  @override
  Widget build(BuildContext context) {
    const Color amber = HyprAmberToggle.amber;
    final Color textColor = day.today
        ? const Color(0xFFFFF1D8)
        : day.currentMonth
        ? HyprInstrumentColors.text
        : HyprInstrumentColors.secondary.withValues(alpha: .55);

    return Semantics(
      label:
          '${MaterialLocalizations.of(context).formatFullDate(DateTime(day.year, day.month, day.day))}${day.today ? ', Today' : ''}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: day.today
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    amber.withValues(alpha: .22),
                    amber.withValues(alpha: .08),
                  ],
                )
              : null,
          border: day.today
              ? Border.all(color: amber.withValues(alpha: .7))
              : null,
          boxShadow: day.today
              ? [BoxShadow(color: amber.withValues(alpha: .12), blurRadius: 10)]
              : null,
        ),
        child: Center(
          child: Text(
            '${day.day}',
            style: HyprInstrumentText.body.copyWith(
              fontSize: 14,
              fontFeatures: HyprTypography.tabularNumbers,
              color: textColor,
              fontWeight: day.today ? FontWeight.w600 : FontWeight.w400,
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
          child: Text(
            'Week $weekNumber',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HyprInstrumentText.meta,
          ),
        ),
        Text(
          utcOffset,
          style: HyprInstrumentText.meta.copyWith(
            fontFeatures: HyprTypography.tabularNumbers,
          ),
        ),
      ],
    );
  }
}
