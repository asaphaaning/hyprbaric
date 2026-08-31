import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';

@UseCase(name: 'Volume', type: OsdPanel, path: '[Widgets]/OSD')
Widget buildVolumeOsd(BuildContext context) {
  return const _OsdStory(
    event: OsdEvent(
      id: 1,
      kind: OsdKind.volume,
      label: 'Volume',
      value: 68,
      muted: false,
    ),
  );
}

@UseCase(name: 'Muted volume', type: OsdPanel, path: '[Widgets]/OSD')
Widget buildMutedVolumeOsd(BuildContext context) {
  return const _OsdStory(
    event: OsdEvent(
      id: 2,
      kind: OsdKind.volume,
      label: 'Volume',
      value: 68,
      muted: true,
    ),
  );
}

@UseCase(name: 'Brightness', type: OsdPanel, path: '[Widgets]/OSD')
Widget buildBrightnessOsd(BuildContext context) {
  return const _OsdStory(
    event: OsdEvent(
      id: 3,
      kind: OsdKind.brightness,
      label: 'Brightness',
      value: 75,
      muted: false,
    ),
  );
}

class _OsdStory extends StatelessWidget {
  const _OsdStory({required this.event});

  final OsdEvent event;

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(child: OsdPanel(event: event));
  }
}
