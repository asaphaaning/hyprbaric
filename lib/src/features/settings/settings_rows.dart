import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'settings_tabs.dart';

class SettingsRowData {
  const SettingsRowData(this.label, this.subtitle, this.value);

  final String label;
  final String subtitle;
  final String value;
}

extension SettingsRowsForTab on SettingsTab {
  List<SettingsRowData> get rows => switch (this) {
    SettingsTab.appearance => appearanceRows,
    SettingsTab.modules => const <SettingsRowData>[],
    SettingsTab.workspaces => const <SettingsRowData>[],
    SettingsTab.display => const <SettingsRowData>[],
    SettingsTab.keybinds => keybindRows,
    SettingsTab.about => const <SettingsRowData>[],
  };

  bool get hasRows => rows.isNotEmpty;
}

const List<SettingsRowData> appearanceRows = <SettingsRowData>[
  SettingsRowData(
    'Position',
    'Anchor the bar to the top of the screen.',
    'Top',
  ),
  SettingsRowData('Opacity', 'Background transparency.', '55%'),
  SettingsRowData('Corner radius', 'Round the bar edges.', '14px'),
  SettingsRowData('Accent hue', 'Drives highlights and active states.', '238°'),
];

const List<SettingsRowData> keybindRows = <SettingsRowData>[];

class SettingsRows extends StatelessWidget {
  const SettingsRows({super.key, required this.rows});

  final List<SettingsRowData> rows;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int index) {
        return SettingsRow(row: rows[index]);
      },
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({super.key, required this.row});

  final SettingsRowData row;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(9),
          side: const BorderSide(color: HyprColors.borderSoft),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    row.label,
                    style: HyprInstrumentText.body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    row.subtitle,
                    style: HyprInstrumentText.body.copyWith(
                      color: HyprInstrumentColors.secondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            HyprBadge.text(
              label: row.value,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              color: Colors.black.withValues(alpha: 0.12),
              borderColor: HyprColors.borderSoft.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(5),
              textColor: HyprInstrumentColors.secondary,
              style: HyprInstrumentText.meta.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
