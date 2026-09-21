import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';
import 'system_fixtures.dart';

@UseCase(name: 'Reference', type: SystemChip, path: '[Widgets]/System')
Widget buildReferenceSystemChip(BuildContext context) {
  return _chipPreview(status: SystemFixtures.barReadout());
}

@UseCase(name: 'Idle', type: SystemChip, path: '[Widgets]/System')
Widget buildIdleSystemChip(BuildContext context) {
  return _chipPreview(status: SystemFixtures.idle());
}

@UseCase(name: 'High load', type: SystemChip, path: '[Widgets]/System')
Widget buildHighSystemChip(BuildContext context) {
  return _chipPreview(status: SystemFixtures.high());
}

@UseCase(name: 'Measuring', type: SystemChip, path: '[Widgets]/System')
Widget buildMeasuringSystemChip(BuildContext context) {
  return _chipPreview(status: SystemFixtures.measuring());
}

@UseCase(name: 'Open', type: SystemChip, path: '[Widgets]/System')
Widget buildOpenSystemChip(BuildContext context) {
  return _chipPreview(status: SystemFixtures.barReadout(), isOpen: true);
}

void _noop() {}

Widget _chipPreview({required SystemStatus status, bool isOpen = false}) {
  return CatalogFrame(
    width: 420,
    child: Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0B1017),
          border: Border.all(color: HyprColors.border),
          borderRadius: const BorderRadius.all(Radius.circular(HyprRadii.bar)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HyprSpacing.lg,
            vertical: HyprSpacing.xs,
          ),
          child: SystemChip(status: status, isOpen: isOpen, onPressed: _noop),
        ),
      ),
    ),
  );
}
