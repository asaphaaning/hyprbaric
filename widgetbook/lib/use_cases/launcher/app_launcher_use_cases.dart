import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';

@UseCase(
  name: 'Populated',
  type: AppLauncherConsole,
  path: '[Widgets]/Launcher',
)
Widget buildAppLauncher(BuildContext context) => const _LauncherStory();

class _LauncherStory extends StatefulWidget {
  const _LauncherStory();

  @override
  State<_LauncherStory> createState() => _LauncherStoryState();
}

class _LauncherStoryState extends State<_LauncherStory> {
  final TextEditingController query = TextEditingController();
  final FocusNode focus = FocusNode();

  @override
  void dispose() {
    query.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CatalogCanvas(
    child: AppLauncherConsole(
      results: const AppLauncherResults(
        phase: AppLauncherPhase.ready,
        query: '',
        entries: <AppLauncherEntry>[
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
        ],
      ),
      queryController: query,
      queryFocusNode: focus,
      selectedIndex: 0,
      iconPathsByEntryId: const <String, String>{},
      borderRadius: HyprRadii.launcherRadius,
      onSelect: (_) {},
      onLaunch: (_) {},
      onClose: () {},
    ),
  );
}
