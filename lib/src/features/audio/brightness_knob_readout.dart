import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';

class BrightnessKnobReadout extends StatelessWidget {
  const BrightnessKnobReadout({super.key, required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: value.toString(),
        children: <InlineSpan>[
          TextSpan(
            text: '%',
            style: HyprTypography.compactMonoStrong.copyWith(
              color: HyprColors.textFaint,
              fontSize: HyprTypography.size(9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      style: HyprTypography.compactMonoStrong.copyWith(
        color: HyprColors.text,
        fontSize: HyprTypography.size(14),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
