import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';

@UseCase(name: 'Normal', type: ToastPill, path: '[Widgets]/Toasts')
Widget buildNormalToast(BuildContext context) {
  return _ToastCanvas(entry: _entries[0]);
}

@UseCase(name: 'Critical', type: ToastPill, path: '[Widgets]/Toasts')
Widget buildCriticalToast(BuildContext context) {
  return _ToastCanvas(entry: _entries[1]);
}

@UseCase(name: 'Interactive stack', type: ToastPill, path: '[Widgets]/Toasts')
Widget buildInteractiveToasts(BuildContext context) {
  return const _InteractiveToastCanvas();
}

class _ToastCanvas extends StatelessWidget {
  const _ToastCanvas({required this.entry});

  final ToastEntry entry;

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: ToastPill(entry: entry, onPressed: _noop),
    );
  }
}

class _InteractiveToastCanvas extends StatefulWidget {
  const _InteractiveToastCanvas();

  @override
  State<_InteractiveToastCanvas> createState() =>
      _InteractiveToastCanvasState();
}

class _InteractiveToastCanvasState extends State<_InteractiveToastCanvas> {
  late List<ToastEntry> entries = List<ToastEntry>.of(_entries);

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final ToastEntry entry in entries) ...<Widget>[
            ToastPill(
              key: ValueKey<int>(entry.id),
              entry: entry,
              onPressed: () {
                setState(() {
                  entries = entries
                      .where((ToastEntry item) => item.id != entry.id)
                      .toList(growable: false);
                });
              },
            ),
            const SizedBox(height: 10),
          ],
          if (entries.isEmpty)
            const Text(
              'All toasts dismissed',
              style: TextStyle(color: Color(0xFF89939E)),
            ),
        ],
      ),
    );
  }
}

const List<ToastEntry> _entries = <ToastEntry>[
  ToastEntry(
    id: 1,
    app: 'GITHUB',
    message: 'New PR merged: feat/bar-glass',
    initials: 'GH',
    color: Color(0xFF78B8FF),
    urgency: NotificationUrgency.normal,
  ),
  ToastEntry(
    id: 2,
    app: 'SYSTEM',
    message: 'Update available: hyprland 0.51.1',
    initials: 'SY',
    color: Color(0xFFE16658),
    urgency: NotificationUrgency.critical,
  ),
];

void _noop() {}
