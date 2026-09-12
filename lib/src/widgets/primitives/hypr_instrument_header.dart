import 'package:flutter/material.dart';

import '../surfaces/hypr_instrument_surface.dart';
import '../surfaces/hypr_typography.dart';
import 'hypr_panel_header.dart';

/// The common top-left icon, uppercase title and optional supporting line.
class HyprInstrumentHeader extends StatelessWidget {
  const HyprInstrumentHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final Widget icon;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => HyprPanelHeader(
    title: title,
    uppercaseTitle: true,
    leading: IconTheme(
      data: const IconThemeData(
        size: 26,
        color: HyprInstrumentColors.secondary,
      ),
      child: SizedBox.square(dimension: 28, child: Center(child: icon)),
    ),
    leadingGap: 12,
    subtitle: subtitle,
    trailing: trailing,
    titleStyle: HyprInstrumentText.title,
    titleColor: HyprInstrumentColors.secondary,
    subtitleStyle: HyprInstrumentText.meta,
    subtitleColor: HyprInstrumentColors.secondary,
  );
}
