import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';

@UseCase(
  name: 'Interactive calendar',
  type: ClockPanel,
  path: '[Widgets]/Calendar',
)
Widget buildInteractiveCalendar(BuildContext context) {
  return const _CalendarStory();
}

/// Exercises the real calendar panel against a deterministic clock snapshot.
///
/// The story keeps the command boundary intact: navigation is handled exactly
/// like the live bar, while the catalog owns the visible month so every state
/// remains deterministic and reviewable.
class _CalendarStory extends StatefulWidget {
  const _CalendarStory();

  @override
  State<_CalendarStory> createState() => _CalendarStoryState();
}

class _CalendarStoryState extends State<_CalendarStory> {
  static final DateTime _today = DateTime(2026, 8, 30);
  DateTime _visibleMonth = DateTime(2026, 8);

  @override
  Widget build(BuildContext context) {
    final DateTime today = _today;
    return CatalogCanvas(
      child: ClockPanel(
        status: ClockViewState(
          timeLabel: '08:18',
          dateLabel: 'Sun, Aug 30',
          monthLabel: _monthLabel(_visibleMonth),
          weekNumber: 35,
          utcOffset: 'UTC+02:00',
          days: _calendarDays(_visibleMonth, today),
        ),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        onCommand: (CalendarCommand command) {
          setState(() {
            switch (command) {
              case CalendarCommand.previousMonth:
                _visibleMonth = DateTime(
                  _visibleMonth.year,
                  _visibleMonth.month - 1,
                );
              case CalendarCommand.today:
                _visibleMonth = DateTime(today.year, today.month);
              case CalendarCommand.nextMonth:
                _visibleMonth = DateTime(
                  _visibleMonth.year,
                  _visibleMonth.month + 1,
                );
            }
          });
        },
      ),
    );
  }
}

List<CalendarDay> _calendarDays(DateTime visibleMonth, DateTime today) {
  final DateTime first = DateTime(visibleMonth.year, visibleMonth.month);
  final int firstOffset = first.weekday - DateTime.monday;
  final int daysInMonth = DateTime(first.year, first.month + 1, 0).day;
  final int totalCells = ((firstOffset + daysInMonth + 6) ~/ 7) * 7;
  final DateTime start = first.subtract(Duration(days: firstOffset));

  return List<CalendarDay>.generate(totalCells, (int index) {
    final DateTime date = start.add(Duration(days: index));
    return CalendarDay(
      year: date.year,
      month: date.month,
      day: date.day,
      currentMonth: date.year == first.year && date.month == first.month,
      today: _sameDate(date, today),
    );
  });
}

bool _sameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _monthLabel(DateTime month) {
  const List<String> names = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${names[month.month - 1]} ${month.year}';
}
