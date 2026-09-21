import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';
import 'system_fixtures.dart';

@UseCase(name: 'Reference', type: SystemPanel, path: '[Widgets]/System')
Widget buildReferenceSystemPanel(BuildContext context) {
  return _SystemPanelStory(status: AsyncValue.data(SystemFixtures.reference()));
}

@UseCase(name: 'High load', type: SystemPanel, path: '[Widgets]/System')
Widget buildHighSystemPanel(BuildContext context) {
  return _SystemPanelStory(status: AsyncValue.data(SystemFixtures.high()));
}

@UseCase(name: 'Idle', type: SystemPanel, path: '[Widgets]/System')
Widget buildIdleSystemPanel(BuildContext context) {
  return _SystemPanelStory(status: AsyncValue.data(SystemFixtures.idle()));
}

@UseCase(name: 'Loading', type: SystemPanel, path: '[Widgets]/System')
Widget buildLoadingSystemPanel(BuildContext context) {
  return const _SystemPanelStory(status: AsyncValue.loading());
}

@UseCase(name: 'Unavailable', type: SystemPanel, path: '[Widgets]/System')
Widget buildUnavailableSystemPanel(BuildContext context) {
  return _SystemPanelStory(
    status: AsyncValue.data(SystemFixtures.unavailable()),
  );
}

@UseCase(name: 'Interactive', type: SystemPanel, path: '[Widgets]/System')
Widget buildInteractiveSystemPanel(BuildContext context) {
  final int cpu = context.knobs.int.slider(
    label: 'CPU %',
    initialValue: 12,
    min: 0,
    max: 100,
    divisions: 100,
  );
  final double memory = context.knobs.double.slider(
    label: 'Memory GiB',
    initialValue: 1.8,
    min: 0.2,
    max: 32,
    divisions: 64,
  );
  final int disk = context.knobs.int.slider(
    label: 'Disk %',
    initialValue: 56,
    min: 0,
    max: 100,
    divisions: 100,
  );
  return _SystemPanelStory(
    status: AsyncValue.data(
      SystemFixtures.reference(
        cpuPercent: cpu,
        memoryGib: memory,
        diskPercent: disk,
      ),
    ),
  );
}

@UseCase(name: 'Chip and popover', type: SystemPanel, path: '[Widgets]/System')
Widget buildSystemChipAndPanel(BuildContext context) {
  final SystemStatus status = SystemFixtures.reference();
  return CatalogCanvas(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF0B1017),
            border: Border.all(color: HyprColors.border),
            borderRadius: const BorderRadius.all(
              Radius.circular(HyprRadii.bar),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HyprSpacing.lg,
              vertical: HyprSpacing.xs,
            ),
            child: SystemChip(status: status, isOpen: true, onPressed: () {}),
          ),
        ),
        const SizedBox(height: 18),
        SystemPanel(
          borderRadius: SystemPanel.radius,
          status: AsyncValue.data(status),
        ),
      ],
    ),
  );
}

class _SystemPanelStory extends StatelessWidget {
  const _SystemPanelStory({required this.status});

  final AsyncValue<SystemStatus> status;

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: SystemPanel(borderRadius: SystemPanel.radius, status: status),
    );
  }
}
