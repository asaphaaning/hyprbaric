import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';

@UseCase(
  name: 'Profiles',
  type: PowerProfilePad,
  path: '[Building blocks]/Power',
)
Widget buildPowerProfilePadStates(BuildContext context) {
  return CatalogFrame(
    width: 430,
    child: Row(
      children: <Widget>[
        for (final PowerProfile profile in PowerProfile.values) ...<Widget>[
          Expanded(
            child: PowerProfilePad(
              profile: profile,
              active: profile == PowerProfile.balanced,
              enabled: true,
              onPressed: (_) {},
            ),
          ),
          if (profile != PowerProfile.values.last)
            const SizedBox(width: HyprSpacing.lg),
        ],
      ],
    ),
  );
}

@UseCase(
  name: 'Unavailable',
  type: PowerProfilePad,
  path: '[Building blocks]/Power',
)
Widget buildUnavailablePowerProfilePad(BuildContext context) {
  return CatalogFrame(
    width: 220,
    child: PowerProfilePad(
      profile: PowerProfile.performance,
      active: false,
      enabled: false,
      onPressed: (_) {},
    ),
  );
}
