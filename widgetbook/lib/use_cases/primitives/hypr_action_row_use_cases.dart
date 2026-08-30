import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';

@UseCase(name: 'States', type: HyprActionRow, path: '[Building blocks]/Rows')
Widget buildActionRowStates(BuildContext context) {
  return CatalogFrame(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        HyprActionRow(
          title: 'Default action',
          subtitle: 'Hover to inspect the interaction chrome',
          icon: Icons.tune_rounded,
          trailing: const Icon(Icons.chevron_right_rounded),
          onPressed: () {},
        ),
        const SizedBox(height: HyprSpacing.md),
        HyprActionRow(
          title: 'Selected action',
          subtitle: 'Persistent selected treatment',
          icon: Icons.check_rounded,
          selected: true,
          trailing: const Text('ON'),
          onPressed: () {},
        ),
        const SizedBox(height: HyprSpacing.md),
        const HyprActionRow(
          title: 'Unavailable action',
          subtitle: 'Disabled interaction state',
          icon: Icons.block_rounded,
          enabled: false,
          onPressed: null,
        ),
      ],
    ),
  );
}
