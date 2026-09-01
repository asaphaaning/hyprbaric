import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';

const OsdEvent _volume = OsdEvent(
  id: 1,
  kind: OsdKind.volume,
  label: 'Volume',
  value: 68,
  muted: false,
);

const OsdEvent _mutedVolume = OsdEvent(
  id: 2,
  kind: OsdKind.volume,
  label: 'Volume',
  value: 68,
  muted: true,
);

const OsdEvent _brightness = OsdEvent(
  id: 3,
  kind: OsdKind.brightness,
  label: 'Brightness',
  value: 75,
  muted: false,
);

@UseCase(
  name: 'Volume, muted, and brightness',
  type: OsdHeader,
  path: '[Building blocks]/OSD',
)
Widget buildOsdHeaderStates(BuildContext context) {
  return const _OsdAtomStates(
    children: <(String, Widget)>[
      ('Volume', OsdHeader(event: _volume)),
      ('Muted', OsdHeader(event: _mutedVolume)),
      ('Brightness', OsdHeader(event: _brightness)),
    ],
  );
}

@UseCase(
  name: 'Decibels and percent',
  type: OsdReadoutView,
  path: '[Building blocks]/OSD',
)
Widget buildOsdReadoutViewStates(BuildContext context) {
  return _OsdAtomStates(
    children: <(String, Widget)>[
      ('Volume', OsdReadoutView(readout: OsdReadout.fromEvent(_volume))),
      ('Muted', OsdReadoutView(readout: OsdReadout.fromEvent(_mutedVolume))),
      (
        'Brightness',
        OsdReadoutView(readout: OsdReadout.fromEvent(_brightness)),
      ),
    ],
  );
}

@UseCase(
  name: 'Fill and peak hold',
  type: OsdMeter,
  path: '[Building blocks]/OSD',
)
Widget buildOsdMeterStates(BuildContext context) {
  return const _OsdAtomStates(
    width: 320,
    children: <(String, Widget)>[
      (
        'Volume — 22 of 32',
        OsdMeter(kind: OsdKind.volume, filled: 22, peak: 0),
      ),
      (
        'Volume — peak hold at 30',
        OsdMeter(kind: OsdKind.volume, filled: 22, peak: 30),
      ),
      ('Volume — silent', OsdMeter(kind: OsdKind.volume, filled: 0, peak: 0)),
      (
        'Brightness — 24 of 32',
        OsdMeter(kind: OsdKind.brightness, filled: 24, peak: 0),
      ),
    ],
  );
}

@UseCase(
  name: 'Volume and brightness ticks',
  type: OsdScale,
  path: '[Building blocks]/OSD',
)
Widget buildOsdScaleStates(BuildContext context) {
  return const _OsdAtomStates(
    width: 320,
    children: <(String, Widget)>[
      ('Volume', OsdScale(kind: OsdKind.volume)),
      ('Brightness', OsdScale(kind: OsdKind.brightness)),
    ],
  );
}

@UseCase(
  name: 'Active, peak, and idle',
  type: OsdSegment,
  path: '[Building blocks]/OSD',
)
Widget buildOsdSegmentStates(BuildContext context) {
  return const _OsdSegmentStates();
}

/// A single OSD segment is 5 logical pixels wide inside the meter, so the
/// states are shown at that size against the panel's own dark ground.
class _OsdSegmentStates extends StatelessWidget {
  const _OsdSegmentStates();

  static const Color _nominal = Color(0xFF4BDA88);
  static const Color _loud = Color(0xFFE16658);

  @override
  Widget build(BuildContext context) {
    return _OsdAtomStates(
      children: <(String, Widget)>[
        (
          'Active',
          _segment(
            const OsdSegment(color: _nominal, active: true, peak: false),
          ),
        ),
        (
          'Peak hold',
          _segment(const OsdSegment(color: _loud, active: false, peak: true)),
        ),
        (
          'Idle',
          _segment(
            const OsdSegment(color: _nominal, active: false, peak: false),
          ),
        ),
      ],
    );
  }

  static Widget _segment(Widget segment) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(width: 6, height: 10, child: segment),
    );
  }
}

/// Lays out OSD atoms on the translucent ground the overlay paints them on.
class _OsdAtomStates extends StatelessWidget {
  const _OsdAtomStates({required this.children, this.width = 220});

  final List<(String, Widget)> children;
  final double width;

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: HyprColors.popoverSurface,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: HyprColors.popupStroke),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final (String label, Widget child) in children) ...<Widget>[
                Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 6),
                SizedBox(width: width, child: child),
                const SizedBox(height: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
