import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';

@UseCase(
  name: 'Translucent chassis',
  type: ControlChassis,
  path: '[Building blocks]/Controls',
)
Widget buildControlChassis(BuildContext context) {
  return CatalogCanvas(
    child: ControlChassis(
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      constraints: const BoxConstraints.tightFor(width: 432),
      padding: const EdgeInsets.all(17),
      child: const ControlSectionTray(
        label: 'Inspect',
        child: ControlInspectButton(
          label: 'Color Pick',
          shortcut: 'Mod P',
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
              shortcut: '⇧ Mod 4',
              icon: Iconsax.maximize_3_copy,
              onPressed: _noop,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: ControlCapturePad(
              label: 'Window',
              shortcut: 'Mod W',
              icon: Iconsax.monitor_copy,
              onPressed: _noop,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: ControlCapturePad(
              label: 'Full',
              shortcut: 'PrtSc',
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
  return CatalogFrame(
    width: 500,
    child: SizedBox(
      height: 110,
      child: Row(
        children: const <Widget>[
          Expanded(
            child: ControlRecordPad(
              active: false,
              enabled: true,
              phase: 'STBY',
              elapsed: '00:00',
              shortcut: 'Mod R',
              onPressed: _noop,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: ControlRecordPad(
              active: true,
              enabled: true,
              phase: 'SEL',
              elapsed: '00:00',
              shortcut: 'Mod R',
              onPressed: _noop,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: ControlRecordPad(
              active: true,
              enabled: true,
              phase: 'REC',
              elapsed: '03:27',
              shortcut: 'Mod R',
              onPressed: _noop,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: ControlRecordPad(
              active: false,
              enabled: false,
              phase: 'N/A',
              elapsed: '00:00',
              shortcut: 'Mod R',
              onPressed: null,
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
            shortcut: 'Mod P',
            icon: Iconsax.colorfilter_copy,
            onPressed: _noop,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: ControlInspectButton(
            label: 'Magnify',
            shortcut: 'Mod M',
            icon: Iconsax.search_zoom_in_1_copy,
            active: true,
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
          Expanded(
            child: ControlRocker(
              label: 'Caffeine',
              icon: Iconsax.coffee_copy,
              value: true,
              enabled: false,
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
    child: ControlSettingsRow(onPressed: _noop),
  );
}

@UseCase(
  name: 'Tray and label',
  type: ControlSectionTray,
  path: '[Building blocks]/Controls',
)
Widget buildControlSectionTray(BuildContext context) {
  return const CatalogFrame(
    width: 460,
    child: ControlSectionTray(
      label: 'Inspect',
      child: ControlInspectButton(
        label: 'Color Pick',
        shortcut: 'Mod P',
        icon: Iconsax.colorfilter_copy,
        onPressed: _noop,
      ),
    ),
  );
}

@UseCase(
  name: 'Section label',
  type: ControlSectionLabel,
  path: '[Building blocks]/Controls',
)
Widget buildControlSectionLabel(BuildContext context) {
  return const CatalogFrame(width: 460, child: ControlSectionLabel('Capture'));
}

void _noop() {}

void _ignore(bool _) {}
