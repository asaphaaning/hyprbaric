import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';

@UseCase(
  name: 'States',
  type: HyprToggleSwitch,
  path: '[Building blocks]/Controls',
)
Widget buildToggleSwitchStates(BuildContext context) {
  return const CatalogFrame(
    width: 320,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _ToggleState(label: 'OFF', value: false),
        SizedBox(height: HyprSpacing.xxl),
        _ToggleState(label: 'ON', value: true),
      ],
    ),
  );
}

class _ToggleState extends StatelessWidget {
  const _ToggleState({required this.label, required this.value});

  final String label;
  final bool value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: HyprTypography.compactMonoStrong)),
        HyprToggleSwitch(value: value),
      ],
    );
  }
}
