import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';

@UseCase(
  name: 'Open states',
  type: BarIconActionButton,
  path: '[Building blocks]/Bar controls',
)
Widget buildBarIconActionButtonStates(BuildContext context) {
  return _BarControlFrame(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        BarIconActionButton(
          label: 'Network',
          icon: Icons.wifi_rounded,
          isOpen: false,
          onPressed: _noop,
        ),
        const SizedBox(width: 4),
        BarIconActionButton(
          label: 'Controls',
          icon: Icons.tune_rounded,
          isOpen: true,
          onPressed: _noop,
        ),
      ],
    ),
  );
}

@UseCase(
  name: 'Audio and display',
  type: AudioDisplayButton,
  path: '[Building blocks]/Bar controls',
)
Widget buildAudioDisplayButtonStates(BuildContext context) {
  return _BarControlFrame(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AudioDisplayButton(isOpen: false, onPressed: _noop),
        const SizedBox(width: 4),
        AudioDisplayButton(isOpen: true, onPressed: _noop),
      ],
    ),
  );
}

@UseCase(
  name: 'Glyph rendering',
  type: BarGlyphIcon,
  path: '[Building blocks]/Bar controls',
)
Widget buildBarGlyphIcons(BuildContext context) {
  return _BarControlFrame(
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        BarGlyphIcon(icon: Icons.wifi_rounded, size: HyprIconSizes.bar),
        SizedBox(width: HyprSpacing.lg),
        BarGlyphIcon(
          icon: Icons.notifications_none_rounded,
          size: HyprIconSizes.bar,
        ),
        SizedBox(width: HyprSpacing.lg),
        BarVolumeKnobIcon(color: HyprColors.textMuted),
      ],
    ),
  );
}

@UseCase(
  name: 'Notification states',
  type: NotificationButton,
  path: '[Building blocks]/Bar controls',
)
Widget buildBarNotificationButtonStates(BuildContext context) {
  return _BarControlFrame(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        NotificationButton(unreadCount: 0, isOpen: false, onPressed: _noop),
        const SizedBox(width: 4),
        NotificationButton(unreadCount: 3, isOpen: false, onPressed: _noop),
        const SizedBox(width: 4),
        NotificationButton(unreadCount: 12, isOpen: true, onPressed: _noop),
      ],
    ),
  );
}

@UseCase(
  name: 'Clock states',
  type: ClockButton,
  path: '[Building blocks]/Bar controls',
)
Widget buildClockButtonStates(BuildContext context) {
  return _BarControlFrame(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ClockButton(status: _clock, isOpen: false, onPressed: _noop),
        const SizedBox(height: HyprSpacing.md),
        ClockButton(status: _clock, isOpen: true, onPressed: _noop),
      ],
    ),
  );
}

@UseCase(
  name: 'Session states',
  type: PowerButton,
  path: '[Building blocks]/Bar controls',
)
Widget buildPowerButtonStates(BuildContext context) {
  return _BarControlFrame(
    child: SizedBox(
      width: 160,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          PowerButton(isOpen: false, onPressed: _noop),
          PowerButton(isOpen: true, onPressed: _noop),
        ],
      ),
    ),
  );
}

@UseCase(
  name: 'Accent tints',
  type: BarVolumeKnobIcon,
  path: '[Building blocks]/Bar controls',
)
Widget buildBarVolumeKnobIconStates(BuildContext context) {
  return _BarControlFrame(
    child: SizedBox(
      width: 160,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          BarVolumeKnobIcon(color: context.hyprPalette.accentSoft),
          const BarVolumeKnobIcon(color: HyprColors.textMuted),
          const BarVolumeKnobIcon(color: HyprColors.textFaint),
        ],
      ),
    ),
  );
}

const ClockViewState _clock = ClockViewState(
  timeLabel: '08:43',
  dateLabel: 'Sun, Aug 30',
  monthLabel: 'August 2026',
  weekNumber: 35,
  utcOffset: 'UTC+02:00',
  days: <CalendarDay>[],
);

class _BarControlFrame extends StatelessWidget {
  const _BarControlFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CatalogFrame(
      width: 460,
      padding: const EdgeInsets.all(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0B1017),
          border: Border.all(color: HyprColors.border),
          borderRadius: const BorderRadius.all(Radius.circular(HyprRadii.bar)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HyprSpacing.md,
            vertical: HyprSpacing.xs,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

void _noop() {}
