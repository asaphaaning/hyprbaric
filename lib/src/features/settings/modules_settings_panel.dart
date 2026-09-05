import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../../state/providers.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';

class ModulesSettingsPanel extends ConsumerWidget {
  const ModulesSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ModulesStatus status = ref.watch(currentModulesProvider);

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _moduleRows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int index) {
        final _ModuleRowData row = _moduleRows[index];
        final bool enabled = status.isEnabled(row.module);
        return _ModuleRow(
          row: row,
          enabled: enabled,
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

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({
    required this.row,
    required this.enabled,
    required this.onChanged,
  });

  final _ModuleRowData row;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return HyprInteractionRegion(
      enabled: true,
      onPressed: () => onChanged(!enabled),
      builder: (BuildContext context, HyprInteractionState state) {
        final bool hovered = state.hovered;
        return DecoratedBox(
          decoration: ShapeDecoration(
            color: hovered
                ? context.hyprPalette.fill
                : Colors.black.withValues(alpha: 0.16),
            shape: RoundedSuperellipseBorder(
              borderRadius: HyprRadii.panelRadius,
              side: BorderSide(
                color: hovered
                    ? context.hyprPalette.borderSoft
                    : HyprColors.popupStroke,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        row.label,
                        style: HyprTypography.popRow.copyWith(
                          fontSize: HyprTypography.size(13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        row.subtitle,
                        style: HyprTypography.popRow.copyWith(
                          color: HyprColors.textFaint,
                          fontSize: HyprTypography.size(11),
                        ),
                      ),
                    ],
                  ),
                ),
                HyprBadge.text(
                  label: enabled ? 'On' : 'Off',
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  color: Colors.black.withValues(alpha: 0.12),
                  borderColor: HyprColors.popupStroke.withValues(alpha: 0.65),
                  borderRadius: HyprRadii.cardRadius,
                  textColor: enabled
                      ? context.hyprPalette.accent
                      : HyprColors.textMuted,
                  style: HyprTypography.compactMonoStrong.copyWith(
                    fontSize: HyprTypography.size(11),
                  ),
                ),
                const SizedBox(width: 10),
                HyprToggleSwitch(value: enabled),
              ],
            ),
          ),
        );
      },
    );
  }
}
