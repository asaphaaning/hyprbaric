import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../../state/providers.dart';
import '../../widgets/primitives/primitives.dart';
import 'settings_primitives.dart';

class WorkspacesSettingsPanel extends ConsumerWidget {
  const WorkspacesSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WorkspaceSettingsStatus status = ref.watch(
      currentWorkspaceSettingsProvider,
    );

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        _SegmentRow<WorkspaceIndicatorStyle>(
          label: 'Indicator style',
          subtitle: _indicatorSubtitle(status.indicatorStyle),
          values: WorkspaceIndicatorStyle.values,
          value: status.indicatorStyle,
          labelFor: (WorkspaceIndicatorStyle value) => value.label,
          onChanged: (WorkspaceIndicatorStyle value) {
            ref
                .read(workspaceSettingsControllerProvider.notifier)
                .setIndicatorStyle(value);
          },
        ),
        const SizedBox(height: 1),
        _ClickableRow(
          value: status.clickable,
          onChanged: (bool value) {
            ref
                .read(workspaceSettingsControllerProvider.notifier)
                .setClickable(clickable: value);
          },
        ),
        const SizedBox(height: 1),
        _SegmentRow<WorkspaceVisibleRange>(
          label: 'Visible range',
          subtitle:
              '${status.visibleRange.label} keeps ${status.visibleCount} indicators visible.',
          valueLabel: '${status.visibleCount}',
          values: WorkspaceVisibleRange.values,
          value: status.visibleRange,
          labelFor: (WorkspaceVisibleRange value) => value.label,
          onChanged: (WorkspaceVisibleRange value) {
            ref
                .read(workspaceSettingsControllerProvider.notifier)
                .setVisibleRange(value);
          },
        ),
      ],
    );
  }

  String _indicatorSubtitle(WorkspaceIndicatorStyle style) {
    return switch (style) {
      WorkspaceIndicatorStyle.roman =>
        'Show workspace numbers as Roman numerals.',
      WorkspaceIndicatorStyle.numeric =>
        'Show workspace numbers as plain digits.',
    };
  }
}

class _ClickableRow extends StatelessWidget {
  const _ClickableRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return HyprInteractionRegion(
      semanticLabel: 'Clickable workspaces',
      semanticToggled: value,
      enabled: true,
      onPressed: () => onChanged(!value),
      builder: (BuildContext context, HyprInteractionState state) {
        return _WorkspaceSettingsRow(
          label: 'Clickable workspaces',
          subtitle: value
              ? 'Direct indicator clicks switch workspaces.'
              : 'Direct indicator clicks are ignored.',
          hovered: state.hovered,
          trailing: HyprAmberToggle(value: value),
        );
      },
    );
  }
}

class _SegmentRow<T> extends StatelessWidget {
  const _SegmentRow({
    required this.label,
    required this.subtitle,
    required this.values,
    required this.value,
    required this.labelFor,
    required this.onChanged,
    this.valueLabel,
  });

  final String label;
  final String subtitle;
  final List<T> values;
  final T value;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    return _WorkspaceSettingsRow(
      label: label,
      subtitle: subtitle,
      valueLabel: valueLabel,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          for (final T option in values) ...<Widget>[
            _SegmentButton(
              label: labelFor(option),
              selected: option == value,
              onPressed: () => onChanged(option),
            ),
            if (option != values.last) const SizedBox(width: 5),
          ],
        ],
      ),
    );
  }
}

class _WorkspaceSettingsRow extends StatelessWidget {
  const _WorkspaceSettingsRow({
    required this.label,
    required this.subtitle,
    this.hovered = false,
    this.valueLabel,
    this.child,
    this.trailing,
  });

  final String label;
  final String subtitle;
  final bool hovered;
  final String? valueLabel;
  final Widget? child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      hovered: hovered,
      child: SettingsField(
        label: label,
        subtitle: subtitle,
        trailing:
            trailing ??
            (valueLabel == null ? null : SettingsValue(valueLabel!)),
        child: child,
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SettingsChoice(
      label: label,
      selected: selected,
      onPressed: onPressed,
    );
  }
}
