import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../../state/providers.dart';
import '../../widgets/primitives/primitives.dart';
import 'settings_primitives.dart';

class ModulesSettingsPanel extends ConsumerWidget {
  const ModulesSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ModulesStatus status = ref.watch(currentModulesProvider);
    final GlobalMenuIntegrationStatus? globalMenuIntegration = ref
        .watch(globalMenuIntegrationProvider)
        .asData
        ?.value;

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _moduleRows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final _ModuleRowData row = _moduleRows[index];
        final bool enabled = status.isEnabled(row.module);
        return _ModuleRow(
          row: row,
          enabled: enabled,
          subtitle: _subtitle(row, enabled, globalMenuIntegration),
          onChanged: (bool value) {
            ref
                .read(modulesControllerProvider.notifier)
                .setEnabled(row.module, enabled: value);
          },
        );
      },
    );
  }
}

class _ModuleRowData {
  const _ModuleRowData({
    required this.module,
    required this.label,
    required this.subtitle,
  });

  final ModuleId module;
  final String label;
  final String subtitle;
}

const List<_ModuleRowData> _moduleRows = <_ModuleRowData>[
  _ModuleRowData(
    module: ModuleId.activeWindowTitle,
    label: 'Active window title',
    subtitle: 'Show app and document title.',
  ),
  _ModuleRowData(
    module: ModuleId.systemTray,
    label: 'System tray',
    subtitle: 'Show StatusNotifier items.',
  ),
  _ModuleRowData(
    module: ModuleId.notifications,
    label: 'Notifications',
    subtitle: 'Show notification center.',
  ),
  _ModuleRowData(
    module: ModuleId.audioDisplay,
    label: 'Audio & Display',
    subtitle: 'Show mixer and brightness control.',
  ),
  _ModuleRowData(
    module: ModuleId.globalMenu,
    label: 'Global menu',
    subtitle: "Show the focused app's menu bar.",
  ),
];

String _subtitle(
  _ModuleRowData row,
  bool enabled,
  GlobalMenuIntegrationStatus? integration,
) {
  if (row.module != ModuleId.globalMenu || !enabled) {
    return row.subtitle;
  }

  return switch (integration) {
    GlobalMenuIntegrationStatusBlocked(
      :final String message,
      :final String? instruction,
    ) =>
      instruction == null || instruction.isEmpty
          ? message
          : '$message $instruction',
    _ => row.subtitle,
  };
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({
    required this.row,
    required this.enabled,
    required this.subtitle,
    required this.onChanged,
  });

  final _ModuleRowData row;
  final bool enabled;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return HyprInteractionRegion(
      semanticLabel: row.label,
      semanticToggled: enabled,
      onPressed: () => onChanged(!enabled),
      builder: (BuildContext context, HyprInteractionState state) =>
          SettingsCard(
            hovered: state.hovered,
            child: SettingsField(
              label: row.label,
              subtitle: subtitle,
              trailing: HyprAmberToggle(value: enabled),
            ),
          ),
    );
  }
}
