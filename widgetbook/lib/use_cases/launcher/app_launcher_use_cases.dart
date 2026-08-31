import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';

@UseCase(
  name: 'Populated',
  type: AppLauncherConsole,
  path: '[Widgets]/Launcher',
)
Widget buildAppLauncher(BuildContext context) {
  return const _LauncherStory(results: _LauncherFixtures.populated);
}

@UseCase(name: 'Filtered', type: AppLauncherConsole, path: '[Widgets]/Launcher')
Widget buildFilteredAppLauncher(BuildContext context) {
  return const _LauncherStory(
    initialQuery: 'wez',
    results: _LauncherFixtures.filtered,
  );
}

@UseCase(name: 'Loading', type: AppLauncherConsole, path: '[Widgets]/Launcher')
Widget buildLoadingAppLauncher(BuildContext context) {
  return const _LauncherStory(results: _LauncherFixtures.loading);
}

@UseCase(name: 'Empty', type: AppLauncherConsole, path: '[Widgets]/Launcher')
Widget buildEmptyAppLauncher(BuildContext context) {
  return const _LauncherStory(results: _LauncherFixtures.empty);
}

@UseCase(name: 'Error', type: AppLauncherConsole, path: '[Widgets]/Launcher')
Widget buildErrorAppLauncher(BuildContext context) {
  return const _LauncherStory(
    results: _LauncherFixtures.empty,
    errorMessage: 'Application index unavailable.',
  );
}

/// The production console inside the same width envelope as the live modal.
///
/// [AppLauncher] supplies a 620–680px constraint and a 680px preferred width
/// through [ModalCommandSurface]. Catalog stories render the console directly,
/// so this wrapper keeps their geometry identical to the real launcher.
class _LauncherStory extends StatefulWidget {
  const _LauncherStory({
    required this.results,
    this.initialQuery = '',
    this.errorMessage,
  });

  final AppLauncherResults results;
  final String initialQuery;
  final String? errorMessage;

  @override
  State<_LauncherStory> createState() => _LauncherStoryState();
}

class _LauncherStoryState extends State<_LauncherStory> {
  late final TextEditingController query = TextEditingController(
    text: widget.initialQuery,
  );
  final FocusNode focus = FocusNode();

  @override
  void dispose() {
    query.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CatalogCanvas(
    child: SizedBox(
      width: 680,
      child: AppLauncherConsole(
        results: widget.results,
        queryController: query,
        queryFocusNode: focus,
        selectedIndex: 0,
        iconPathsByEntryId: const <String, String>{},
        borderRadius: HyprRadii.launcherRadius,
        errorMessage: widget.errorMessage,
        onSelect: (_) {},
        onLaunch: (_) {},
        onClose: () {},
      ),
    ),
  );
}

abstract final class _LauncherFixtures {
  static const List<AppLauncherEntry> entries = <AppLauncherEntry>[
    AppLauncherEntry(
      id: 'zed.desktop',
      name: 'Zed',
      subtitle: 'Code editor',
      iconName: 'zed',
      terminal: false,
    ),
    AppLauncherEntry(
      id: 'org.wezfurlong.wezterm.desktop',
      name: 'WezTerm',
      subtitle: 'Terminal emulator',
      iconName: 'wezterm',
      terminal: false,
    ),
    AppLauncherEntry(
      id: 'firefox.desktop',
      name: 'Firefox',
      subtitle: 'Web browser',
      iconName: 'firefox',
      terminal: false,
    ),
  ];

  static const AppLauncherResults populated = AppLauncherResults(
    phase: AppLauncherPhase.ready,
    query: '',
    entries: entries,
  );

  static const AppLauncherResults filtered = AppLauncherResults(
    phase: AppLauncherPhase.ready,
    query: 'wez',
    entries: <AppLauncherEntry>[
      AppLauncherEntry(
        id: 'org.wezfurlong.wezterm.desktop',
        name: 'WezTerm',
        subtitle: 'Terminal emulator',
        iconName: 'wezterm',
        terminal: false,
      ),
    ],
  );

  static const AppLauncherResults loading = AppLauncherResults(
    phase: AppLauncherPhase.loading,
    query: '',
    entries: <AppLauncherEntry>[],
  );

  static const AppLauncherResults empty = AppLauncherResults(
    phase: AppLauncherPhase.ready,
    query: 'calendar',
    entries: <AppLauncherEntry>[],
    message: 'No applications matched that query.',
  );
}
