import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';
import '../../stories/workspace_strip_preview.dart';

@UseCase(
  name: 'Interactive strip',
  type: WorkspaceStrip,
  path: '[Widgets]/Workspaces',
)
Widget buildInteractiveWorkspaceStrip(BuildContext context) {
  return const CatalogCanvas(child: WorkspaceStripPreview());
}
