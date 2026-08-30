import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';

@UseCase(name: 'Tones', type: HyprBadge, path: '[Building blocks]/Feedback')
Widget buildBadgeTones(BuildContext context) {
  return CatalogFrame(
    width: 360,
    child: Wrap(
      spacing: HyprSpacing.lg,
      runSpacing: HyprSpacing.lg,
      children: <Widget>[
        HyprBadge.text(
          label: 'NEUTRAL',
          color: Color(0xFF121820),
          borderColor: HyprColors.border,
        ),
        HyprBadge.text(
          label: 'ACTIVE',
          color: HyprColors.fillStrong,
          borderColor: HyprColors.accent,
          textColor: HyprColors.accentSoft,
        ),
        HyprBadge.text(
          label: 'DANGER',
          color: Color(0x24E05F55),
          borderColor: Color(0x88E05F55),
          textColor: Color(0xFFE98C85),
        ),
      ],
    ),
  );
}
