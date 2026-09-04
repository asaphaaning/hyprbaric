import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';
import 'workspace_fixtures.dart';

@UseCase(name: 'Roman', type: WorkspaceStrip, path: '[Widgets]/Bar')
Widget buildRomanWorkspaceStrip(BuildContext context) {
  return const _WorkspaceStripStory(
    status: WorkspaceFixtures.occupied,
    settings: WorkspaceFixtures.roman,
  );
}

@UseCase(name: 'Numeric', type: WorkspaceStrip, path: '[Widgets]/Bar')
Widget buildNumericWorkspaceStrip(BuildContext context) {
  return const _WorkspaceStripStory(
    status: WorkspaceFixtures.occupied,
    settings: WorkspaceFixtures.numeric,
  );
}

@UseCase(name: 'Read-only', type: WorkspaceStrip, path: '[Widgets]/Bar')
Widget buildReadOnlyWorkspaceStrip(BuildContext context) {
  return const _WorkspaceStripStory(
    status: WorkspaceFixtures.occupied,
    settings: WorkspaceFixtures.readOnly,
  );
}

@UseCase(name: 'Special workspace', type: WorkspaceStrip, path: '[Widgets]/Bar')
Widget buildSpecialWorkspaceStrip(BuildContext context) {
  return const _WorkspaceStripStory(
    status: WorkspaceFixtures.special,
    settings: WorkspaceFixtures.roman,
  );
}

@UseCase(name: 'Interactive', type: WorkspaceStrip, path: '[Widgets]/Bar')
Widget buildInteractiveWorkspaceStrip(BuildContext context) {
  return const _InteractiveWorkspaceStripStory();
}

@UseCase(
  name: 'Loading and error',
  type: WorkspaceStripPlaceholder,
  path: '[Building blocks]/Bar',
)
Widget buildWorkspaceStripPlaceholders(BuildContext context) {
  return const _WorkspaceStripPlaceholderStates();
}

@UseCase(name: 'States', type: WorkspaceButton, path: '[Building blocks]/Bar')
Widget buildWorkspaceButtonStates(BuildContext context) {
  return const _WorkspaceButtonStates();
}

@UseCase(
  name: 'Previous and next',
  type: WorkspaceNavButton,
  path: '[Building blocks]/Bar',
)
Widget buildWorkspaceNavButtonStates(BuildContext context) {
  return const _WorkspaceNavButtonStates();
}

/// The strip on the bar's own translucent chrome rather than a bare canvas.
class _BarChrome extends StatelessWidget {
  const _BarChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xB3081119)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: child,
      ),
    );
  }
}

class _WorkspaceStripStory extends StatelessWidget {
  const _WorkspaceStripStory({required this.status, required this.settings});

  final WorkspaceStatus status;
  final WorkspaceSettingsStatus settings;

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: _BarChrome(
        child: WorkspaceStrip(
          status: status,
          settings: settings,
          resolution: MonitorWorkspaceResolution(
            activeWorkspaceId: status.id,
            activeWorkspaceName: status.name,
            isSpecial: status.isSpecial,
            monitorName: null,
          ),
          onPrevious: () {},
          onNext: () {},
          onSelect: (_) {},
        ),
      ),
    );
  }
}

class _InteractiveWorkspaceStripStory extends StatefulWidget {
  const _InteractiveWorkspaceStripStory();

  @override
  State<_InteractiveWorkspaceStripStory> createState() =>
      _InteractiveWorkspaceStripStoryState();
}

class _InteractiveWorkspaceStripStoryState
    extends State<_InteractiveWorkspaceStripStory> {
  int active = 3;

  void _move(int offset) {
    setState(() => active = (active + offset).clamp(1, 9));
  }

  @override
  Widget build(BuildContext context) {
    final WorkspaceStatus status = WorkspaceStatus(
      id: active,
      name: '$active',
      isSpecial: false,
      occupiedWorkspaceIds: WorkspaceFixtures.occupied.occupiedWorkspaceIds,
      monitors: const [],
    );

    return CatalogCanvas(
      child: _BarChrome(
        child: WorkspaceStrip(
          status: status,
          settings: WorkspaceFixtures.roman,
          resolution: MonitorWorkspaceResolution(
            activeWorkspaceId: active,
            activeWorkspaceName: '$active',
            isSpecial: false,
            monitorName: null,
          ),
          onPrevious: () => _move(-1),
          onNext: () => _move(1),
          onSelect: (int index) => setState(() => active = index),
        ),
      ),
    );
  }
}

class _WorkspaceStripPlaceholderStates extends StatelessWidget {
  const _WorkspaceStripPlaceholderStates();

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: _BarChrome(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const <Widget>[
            WorkspaceStripPlaceholder(label: '…'),
            SizedBox(width: 24),
            WorkspaceStripPlaceholder(label: '!'),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceButtonStates extends StatelessWidget {
  const _WorkspaceButtonStates();

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: _BarChrome(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            WorkspaceButton(
              label: 'I',
              active: true,
              occupied: true,
              onPressed: () {},
            ),
            const SizedBox(width: 12),
            WorkspaceButton(
              label: 'II',
              active: false,
              occupied: true,
              onPressed: () {},
            ),
            const SizedBox(width: 12),
            WorkspaceButton(
              label: 'III',
              active: false,
              occupied: false,
              onPressed: () {},
            ),
            const SizedBox(width: 12),
            const WorkspaceButton(label: 'IV', active: false, occupied: false),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceNavButtonStates extends StatelessWidget {
  const _WorkspaceNavButtonStates();

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: _BarChrome(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            WorkspaceNavButton(
              icon: Icons.chevron_left_rounded,
              label: 'Previous workspace',
              onPressed: () {},
            ),
            const SizedBox(width: 12),
            WorkspaceNavButton(
              icon: Icons.chevron_right_rounded,
              label: 'Next workspace',
              onPressed: () {},
            ),
            const SizedBox(width: 24),
            const WorkspaceNavButton(
              icon: Icons.chevron_right_rounded,
              label: 'Next workspace disabled',
            ),
          ],
        ),
      ),
    );
  }
}
