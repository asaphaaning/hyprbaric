import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';

/// Chords in these stories stand in for the user's own bindings, which the
/// live panel reads from the keybinding snapshot.
const String _regionChord = 'Super+Shift+S';
const String _recordChord = 'Super+Shift+R';
const String _pickChord = 'Super+Shift+P';

const ControlAvailability _unavailable = ControlAvailability.unavailable(
  'Not available yet',
);

@UseCase(
  name: 'Translucent chassis',
  type: HyprPopoverPanel,
  path: '[Building blocks]/Controls',
)
Widget buildControlChassis(BuildContext context) {
  return CatalogCanvas(
    child: HyprPopoverPanel(
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      constraints: const BoxConstraints.tightFor(width: 432),
      padding: const EdgeInsets.all(17),
      child: const HyprConsoleTray(
        label: 'Inspect',
        child: ControlInspectButton(
          label: 'Color Pick',
          shortcut: _pickChord,
          icon: Iconsax.colorfilter_copy,
          onPressed: _noop,
        ),
      ),
    ),
  );
}

@UseCase(
  name: 'Capture modes',
  type: ControlCapturePad,
  path: '[Building blocks]/Controls',
)
Widget buildControlCapturePadStates(BuildContext context) {
  return CatalogFrame(
    width: 460,
    child: SizedBox(
      height: 108,
      child: Row(
        children: const <Widget>[
          Expanded(
            child: ControlCapturePad(
              label: 'Region',
              shortcut: _regionChord,
              icon: Iconsax.maximize_3_copy,
              onPressed: _noop,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: ControlCapturePad(
              label: 'Window',
              shortcut: 'Super+Print',
              icon: Iconsax.monitor_copy,
              onPressed: _noop,
            ),
          ),
          SizedBox(width: 8),
          // A control whose binding is unknown or disabled stamps no chord.
          Expanded(
            child: ControlCapturePad(
              label: 'Full',
              icon: Iconsax.maximize_2_copy,
              onPressed: _noop,
            ),
          ),
        ],
      ),
    ),
  );
}

@UseCase(
  name: 'Recording phases',
  type: ControlRecordPad,
  path: '[Building blocks]/Controls',
)
Widget buildControlRecordPadStates(BuildContext context) {
  final int startedAt = DateTime.now()
      .subtract(const Duration(minutes: 3, seconds: 27))
      .millisecondsSinceEpoch;

  return CatalogFrame(
    width: 500,
    child: SizedBox(
      height: 110,
      child: Row(
        children: <Widget>[
          const Expanded(
            child: ControlRecordPad(
              active: false,
              availability: ControlAvailability.available(),
              phase: 'STBY',
              startedAtMs: null,
              shortcut: _recordChord,
              onPressed: _noop,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: ControlRecordPad(
              active: true,
              availability: ControlAvailability.available(),
              phase: 'SEL',
              startedAtMs: null,
              shortcut: _recordChord,
              onPressed: _noop,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ControlRecordPad(
              active: true,
              availability: const ControlAvailability.available(),
              phase: 'REC',
              startedAtMs: startedAt,
              shortcut: _recordChord,
              onPressed: _noop,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: ControlRecordPad(
              active: false,
              availability: ControlAvailability.unavailable(
                '`wf-recorder` is unavailable',
              ),
              phase: 'N/A',
              startedAtMs: null,
              shortcut: _recordChord,
              onPressed: _noop,
            ),
          ),
        ],
      ),
    ),
  );
}

@UseCase(
  name: 'Inspect actions',
  type: ControlInspectButton,
  path: '[Building blocks]/Controls',
)
Widget buildControlInspectButtonStates(BuildContext context) {
  return CatalogFrame(
    width: 500,
    child: Row(
      children: const <Widget>[
        Expanded(
          child: ControlInspectButton(
            label: 'Color Pick',
            shortcut: _pickChord,
            icon: Iconsax.colorfilter_copy,
            onPressed: _noop,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: ControlInspectButton(
            label: 'Magnify',
            icon: Iconsax.search_zoom_in_1_copy,
            availability: _unavailable,
            onPressed: _noop,
          ),
        ),
      ],
    ),
  );
}

@UseCase(
  name: 'Rocker states',
  type: ControlRocker,
  path: '[Building blocks]/Controls',
)
Widget buildControlRockerStates(BuildContext context) {
  return CatalogFrame(
    width: 500,
    child: SizedBox(
      height: 120,
      child: Row(
        children: const <Widget>[
          Expanded(
            child: ControlRocker(
              label: 'DND',
              icon: Iconsax.minus_cirlce_copy,
              value: false,
              onChanged: _ignore,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: ControlRocker(
              label: 'Night',
              icon: Iconsax.moon_copy,
              value: true,
              onChanged: _ignore,
            ),
          ),
          SizedBox(width: 8),
          // Unavailable wins over `value`: this reads as off and dimmed.
          Expanded(
            child: ControlRocker(
              label: 'Caffeine',
              icon: Iconsax.coffee_copy,
              value: true,
              availability: _unavailable,
              onChanged: _ignore,
            ),
          ),
        ],
      ),
    ),
  );
}

@UseCase(
  name: 'Settings row',
  type: ControlSettingsRow,
  path: '[Building blocks]/Controls',
)
Widget buildControlSettingsRow(BuildContext context) {
  return const CatalogFrame(
    width: 460,
    child: ControlSettingsRow(onPressed: _noop, shortcut: 'Super+Shift+C'),
  );
}

@UseCase(
  name: 'Tray and label',
  type: HyprConsoleTray,
  path: '[Building blocks]/Controls',
)
Widget buildControlSectionTray(BuildContext context) {
  return const CatalogFrame(
    width: 460,
    child: HyprConsoleTray(
      label: 'Inspect',
      child: ControlInspectButton(
        label: 'Color Pick',
        shortcut: _pickChord,
        icon: Iconsax.colorfilter_copy,
        onPressed: _noop,
      ),
    ),
  );
}

@UseCase(
  name: 'Section label',
  type: HyprConsoleSectionLabel,
  path: '[Building blocks]/Controls',
)
Widget buildControlSectionLabel(BuildContext context) {
  return const CatalogFrame(
    width: 460,
    child: HyprConsoleSectionLabel('Capture'),
  );
}

void _noop() {}

void _ignore(bool _) {}
