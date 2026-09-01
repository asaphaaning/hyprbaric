import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';

@UseCase(name: 'Accents', type: ToastAppTag, path: '[Building blocks]/Toasts')
Widget buildToastAppTagStates(BuildContext context) {
  return const _ToastAtomCanvas(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ToastAppTag(app: 'GITHUB', accent: Color(0xFF78B8FF)),
        SizedBox(height: 10),
        ToastAppTag(app: 'SYSTEM', accent: Color(0xFFE16658)),
        SizedBox(height: 10),
        ToastAppTag(
          app: 'A VERY LONG APPLICATION NAME',
          accent: Color(0xFF4BDA88),
        ),
      ],
    ),
  );
}

@UseCase(
  name: 'Frame corners',
  type: ToastCornerBrackets,
  path: '[Building blocks]/Toasts',
)
Widget buildToastCornerBrackets(BuildContext context) {
  return const _ToastAtomCanvas(
    child: SizedBox(width: 260, height: 70, child: ToastCornerBrackets()),
  );
}

/// The toast atoms only read on the dark surface the overlay paints them on.
class _ToastAtomCanvas extends StatelessWidget {
  const _ToastAtomCanvas({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: HyprColors.popoverSurface,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: HyprColors.popupStroke),
          ),
        ),
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      ),
    );
  }
}
