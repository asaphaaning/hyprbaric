import 'package:flutter/material.dart';

import '../../widgets/primitives/primitives.dart';
import 'about_settings_panel.dart';
import 'appearance_settings_panel.dart';
import 'keybindings/keybindings_panel.dart';
import 'modules_settings_panel.dart';
import 'night_light_settings_panel.dart';
import 'settings_rows.dart';
import 'settings_tabs.dart';
import 'workspaces_settings_panel.dart';

class SettingsContentHeader extends StatelessWidget {
  const SettingsContentHeader({
    super.key,
    required this.tab,
    required this.onClose,
  });

  final SettingsTab tab;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return HyprInstrumentHeader(
      title: tab.label,
      subtitle: tab.subtitle,
      icon: const Icon(Icons.settings_outlined),
      trailing: IconButton(
        onPressed: onClose,
        style: settingsCloseButtonStyle(),
        icon: const Icon(Icons.close_rounded, size: 18),
      ),
    );
  }
}

class SettingsTabBody extends StatelessWidget {
  const SettingsTabBody({super.key, required this.tab});

  final SettingsTab tab;

  @override
  Widget build(BuildContext context) {
    if (tab == SettingsTab.about) {
      return const AboutSettingsPanel();
    }
    if (tab == SettingsTab.keybinds) {
      return const KeybindingsPanel();
    }
    if (tab == SettingsTab.display) {
      return const NightLightSettingsPanel();
    }
    if (tab == SettingsTab.appearance) {
      return const AppearanceSettingsPanel();
    }
    if (tab == SettingsTab.modules) {
      return const ModulesSettingsPanel();
    }
    if (tab == SettingsTab.workspaces) {
      return const WorkspacesSettingsPanel();
    }
    return SettingsRows(rows: tab.rows);
  }
}

ButtonStyle settingsCloseButtonStyle() {
  return hyprCompactIconButtonStyle(size: const Size.square(28), radius: 9);
}
