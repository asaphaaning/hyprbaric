import 'package:flutter/material.dart';

import '../hypr_surface.dart';
import 'hypr_select.dart';
import 'hypr_well.dart';

/// A compact instrument status display, recessed into its surrounding panel.
///
/// The label carries meaning independently of its signal color. This is a
/// readout, not an interactive control; it has no hover or pressed treatment.
class HyprStatusReadout extends StatelessWidget {
  const HyprStatusReadout({
    super.key,
    required this.label,
    this.color = HyprInstrumentColors.secondary,
  });

  /// Human-readable state, displayed in uppercase instrument lettering.
  final String label;

  /// Signal color; the housing remains neutral for every state.
  final Color color;

  @override
  Widget build(BuildContext context) => HyprWell(
    color: HyprSelectStyle.fill,
    borderColor: HyprSelectStyle.border,
    borderRadius: const BorderRadius.all(Radius.circular(5)),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    child: Text(
      label.toUpperCase(),
      maxLines: 1,
      style: HyprInstrumentText.meta.copyWith(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: .8,
        height: 1.2,
        shadows: [Shadow(color: color.withValues(alpha: .18), blurRadius: 5)],
      ),
    ),
  );
}
