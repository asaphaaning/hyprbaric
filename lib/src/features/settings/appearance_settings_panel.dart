import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../../layer_shell_controller.dart';
import '../../state/providers.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';

class AppearanceSettingsPanel extends ConsumerStatefulWidget {
  const AppearanceSettingsPanel({super.key});

  @override
  ConsumerState<AppearanceSettingsPanel> createState() =>
      _AppearanceSettingsPanelState();
}

class _AppearanceSettingsPanelState
    extends ConsumerState<AppearanceSettingsPanel> {
  AppearanceStatus? _draft;

  AppearanceStatus _view(AppearanceStatus status) => _draft ?? status;

  void _preview(AppearanceStatus status) {
    setState(() => _draft = status);
    ref.read(appearancePreviewProvider.notifier).preview(status);
  }

  void _commit(VoidCallback dispatch) {
    dispatch();
    ref.read(appearancePreviewProvider.notifier).clear();
    setState(() => _draft = null);
  }

  @override
  Widget build(BuildContext context) {
    final AppearanceStatus status = ref.watch(currentAppearanceProvider);
    final AppearanceStatus view = _view(status);

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        _PositionRow(
          value: view.position,
          onChanged: (AppearancePosition position) {
            final AppearanceStatus next = view.copyWith(position: position);
            _preview(next);
            _commit(
              () => ref
                  .read(appearanceControllerProvider.notifier)
                  .setPosition(position),
            );
          },
        ),
        const SizedBox(height: 8),
        _MonitorRow(
          value: view.monitor,
          monitors: ref
              .watch(layerShellMonitorsProvider)
              .maybeWhen(
                data: (List<LayerShellMonitor> monitors) => monitors,
                orElse: () => const <LayerShellMonitor>[],
              ),
          onChanged: (AppearanceMonitorTarget monitor) {
            final AppearanceStatus next = view.copyWith(monitor: monitor);
            _preview(next);
            _commit(
              () => ref
                  .read(appearanceControllerProvider.notifier)
                  .setMonitor(monitor),
            );
          },
        ),
        const SizedBox(height: 8),
        _SliderRow(
          label: 'Opacity',
          valueLabel: '${view.opacity}%',
          subtitle: 'Background transparency.',
          value: view.opacity.toDouble(),
          min: 20,
          max: 100,
          divisions: 80,
          accent: context.hyprPalette.accent,
          onChanged: (double value) {
            _preview(view.copyWith(opacity: value.round()));
          },
          onChangeEnd: (double value) {
            final int opacity = value.round();
            _commit(
              () => ref
                  .read(appearanceControllerProvider.notifier)
                  .setOpacity(opacity),
            );
          },
        ),
        const SizedBox(height: 8),
        _SliderRow(
          label: 'Corner radius',
          valueLabel: '${view.cornerRadius}px',
          subtitle: 'Round the bar edges.',
          value: view.cornerRadius.toDouble(),
          min: 0,
          max: 32,
          divisions: 32,
          accent: context.hyprPalette.accent,
          onChanged: (double value) {
            _preview(view.copyWith(cornerRadius: value.round()));
          },
          onChangeEnd: (double value) {
            final int cornerRadius = value.round();
            _commit(
              () => ref
                  .read(appearanceControllerProvider.notifier)
                  .setCornerRadius(cornerRadius),
            );
          },
        ),
        const SizedBox(height: 8),
        _SliderRow(
          label: 'Accent hue',
          valueLabel: '${view.accentHue}°',
          subtitle: 'Drives highlights and active states.',
          value: view.accentHue.toDouble(),
          min: 0,
          max: 359,
          divisions: 359,
          accent: context.hyprPalette.accent,
          leadingValue: DecoratedBox(
            decoration: ShapeDecoration(
              color: context.hyprPalette.accent,
              shape: RoundedSuperellipseBorder(
                borderRadius: HyprRadii.compactRadius,
                side: BorderSide(
                  color: context.hyprPalette.accentSoft.withValues(alpha: 0.45),
                ),
              ),
            ),
            child: const SizedBox.square(dimension: 22),
          ),
          onChanged: (double value) {
            _preview(view.copyWith(accentHue: value.round()));
          },
          onChangeEnd: (double value) {
            final int accentHue = value.round();
            _commit(
              () => ref
                  .read(appearanceControllerProvider.notifier)
                  .setAccentHue(accentHue),
            );
          },
        ),
        const SizedBox(height: 10),
        HyprCommandButton(
          label: 'Restore defaults',
          icon: const Icon(Icons.restore_rounded, size: 15),
          onPressed: _isDefault(view)
              ? null
              : () {
                  ref.read(appearancePreviewProvider.notifier).clear();
                  setState(() => _draft = null);
                  ref
                      .read(appearanceControllerProvider.notifier)
                      .restoreDefaults();
                },
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          constraints: const BoxConstraints(minHeight: 36),
          color: Colors.black.withValues(alpha: 0.14),
          borderColor: HyprColors.popupStroke,
          foregroundColor: HyprColors.textMuted,
          hoverForegroundColor: HyprColors.text,
          hoverBorderColor: context.hyprPalette.borderSoft,
          textStyle: HyprTypography.compactMonoStrong.copyWith(
            fontSize: HyprTypography.size(11),
          ),
        ),
      ],
    );
  }

  bool _isDefault(AppearanceStatus status) {
    return status == defaultAppearanceStatus;
  }
}

class _MonitorRow extends StatelessWidget {
  const _MonitorRow({
    required this.value,
    required this.monitors,
    required this.onChanged,
  });

  final AppearanceMonitorTarget value;
  final List<LayerShellMonitor> monitors;
  final ValueChanged<AppearanceMonitorTarget> onChanged;

  @override
  Widget build(BuildContext context) {
    return _AppearanceRow(
      label: 'Monitors',
      subtitle: 'Choose one display or mirror the bar across every display.',
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        children: <Widget>[
          _SegmentButton(
            label: 'Primary',
            selected: value is AppearanceMonitorTargetPrimary,
            onPressed: () => onChanged(const AppearanceMonitorTargetPrimary()),
          ),
          _SegmentButton(
            label: 'All',
            selected: value is AppearanceMonitorTargetAll,
            onPressed: () => onChanged(const AppearanceMonitorTargetAll()),
          ),
          for (final LayerShellMonitor monitor in monitors)
            _SegmentButton(
              label: monitor.label,
              selected:
                  value is AppearanceMonitorTargetNamed &&
                  (value as AppearanceMonitorTargetNamed).name == monitor.name,
              onPressed: () =>
                  onChanged(AppearanceMonitorTargetNamed(name: monitor.name)),
            ),
        ],
      ),
    );
  }
}

class _PositionRow extends StatelessWidget {
  const _PositionRow({required this.value, required this.onChanged});

  final AppearancePosition value;
  final ValueChanged<AppearancePosition> onChanged;

  @override
  Widget build(BuildContext context) {
    return _AppearanceRow(
      label: 'Position',
      subtitle: value == AppearancePosition.top
          ? 'Anchor the bar to the top of the screen.'
          : 'Anchor the bar to the bottom of the screen.',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _SegmentButton(
            label: 'Top',
            selected: value == AppearancePosition.top,
            onPressed: () => onChanged(AppearancePosition.top),
          ),
          const SizedBox(width: 5),
          _SegmentButton(
            label: 'Bottom',
            selected: value == AppearancePosition.bottom,
            onPressed: () => onChanged(AppearancePosition.bottom),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.accent,
    required this.onChanged,
    required this.onChangeEnd,
    this.leadingValue,
  });

  final String label;
  final String valueLabel;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Color accent;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final Widget? leadingValue;

  @override
  Widget build(BuildContext context) {
    return _AppearanceRow(
      label: label,
      subtitle: subtitle,
      valueLabel: valueLabel,
      child: Row(
        children: <Widget>[
          if (leadingValue != null) ...<Widget>[
            leadingValue!,
            const SizedBox(width: 8),
          ],
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: accent,
                inactiveTrackColor: HyprColors.popupStroke,
                thumbColor: HyprColors.text,
                overlayColor: accent.withValues(alpha: 0.16),
                trackHeight: 3,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceRow extends StatelessWidget {
  const _AppearanceRow({
    required this.label,
    required this.subtitle,
    this.valueLabel,
    this.child,
    this.trailing,
  });

  final String label;
  final String subtitle;
  final String? valueLabel;
  final Widget? child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        shape: const RoundedSuperellipseBorder(
          borderRadius: HyprRadii.panelRadius,
          side: BorderSide(color: HyprColors.popupStroke),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: HyprTypography.popRow.copyWith(
                          fontSize: HyprTypography.size(13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: HyprTypography.popRow.copyWith(
                          color: HyprColors.textFaint,
                          fontSize: HyprTypography.size(11),
                        ),
                      ),
                    ],
                  ),
                ),
                if (valueLabel != null)
                  HyprBadge.text(
                    label: valueLabel!,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    color: Colors.black.withValues(alpha: 0.12),
                    borderColor: HyprColors.popupStroke.withValues(alpha: 0.65),
                    borderRadius: HyprRadii.cardRadius,
                    textColor: HyprColors.textMuted,
                    style: HyprTypography.compactMonoStrong.copyWith(
                      fontSize: HyprTypography.size(11),
                    ),
                  ),
                ?trailing,
              ],
            ),
            if (child != null) ...<Widget>[const SizedBox(height: 8), child!],
          ],
        ),
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
    return HyprCommandButton(
      label: label,
      onPressed: selected ? null : onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      constraints: const BoxConstraints(minHeight: 30),
      color: selected
          ? context.hyprPalette.fillStrong
          : Colors.black.withValues(alpha: 0.12),
      borderColor: selected
          ? context.hyprPalette.borderSoft
          : HyprColors.popupStroke,
      foregroundColor: selected ? HyprColors.text : HyprColors.textMuted,
      textStyle: HyprTypography.compactMonoStrong.copyWith(
        fontSize: HyprTypography.size(10.5),
      ),
    );
  }
}
