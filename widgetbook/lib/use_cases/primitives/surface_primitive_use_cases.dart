import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';

@UseCase(
  name: 'Panel frame',
  type: HyprSurface,
  path: '[Building blocks]/Surfaces',
)
Widget buildSurface(BuildContext context) {
  return CatalogCanvas(
    child: HyprSurface(
      borderRadius: HyprRadii.panelRadius,
      shadow: true,
      child: const Padding(
        padding: EdgeInsets.all(HyprSpacing.loose),
        child: Text('Panel surface'),
      ),
    ),
  );
}

@UseCase(
  name: 'Glass frame',
  type: HyprGlassSurface,
  path: '[Building blocks]/Surfaces',
)
Widget buildGlassSurface(BuildContext context) {
  return CatalogCanvas(
    child: HyprGlassSurface(
      borderRadius: HyprRadii.cardRadius,
      color: HyprColors.fillStrong,
      child: const Padding(
        padding: EdgeInsets.all(HyprSpacing.loose),
        child: Text('Glass surface'),
      ),
    ),
  );
}

@UseCase(
  name: 'Popover frame',
  type: HyprPopoverSurface,
  path: '[Building blocks]/Surfaces',
)
Widget buildPopoverSurface(BuildContext context) {
  return CatalogCanvas(
    child: HyprPopoverSurface(
      borderRadius: HyprRadii.popoverRadius,
      shadow: true,
      child: const Padding(
        padding: EdgeInsets.all(HyprSpacing.loose),
        child: Text('Popover surface'),
      ),
    ),
  );
}

@UseCase(
  name: 'Inset treatment',
  type: HyprInsetBorder,
  path: '[Building blocks]/Surfaces',
)
Widget buildInsetBorder(BuildContext context) {
  return CatalogFrame(
    width: 360,
    child: const SizedBox(
      height: 88,
      child: HyprInsetBorder(
        borderRadius: HyprRadii.panelRadius,
        borderColor: HyprColors.border,
        frame: HyprSurfaceFrame.panel,
      ),
    ),
  );
}

@UseCase(
  name: 'Bar divider',
  type: HyprDivider,
  path: '[Building blocks]/Surfaces',
)
Widget buildDivider(BuildContext context) {
  return CatalogFrame(
    width: 260,
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[Text('LEFT'), HyprDivider(height: 26), Text('RIGHT')],
    ),
  );
}
