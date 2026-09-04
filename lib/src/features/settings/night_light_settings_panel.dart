import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../../state/providers.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';

class NightLightSettingsPanel extends ConsumerStatefulWidget {
  const NightLightSettingsPanel({super.key});

  @override
  ConsumerState<NightLightSettingsPanel> createState() =>
      _NightLightSettingsPanelState();
}

class _NightLightSettingsPanelState
    extends ConsumerState<NightLightSettingsPanel> {
  final TextEditingController _temperatureController = TextEditingController();
  final FocusNode _temperatureFocus = FocusNode(debugLabel: 'night-light-temp');

  String? _localError;

  @override
  void dispose() {
    _temperatureController.dispose();
    _temperatureFocus.dispose();
    super.dispose();
  }

  void _syncTemperature(int temperature) {
    if (_temperatureFocus.hasFocus) {
      return;
    }
    final String next = temperature.toString();
    if (_temperatureController.text == next) {
      return;
    }
    _temperatureController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  void _applyTemperature() {
    final int? temperature = int.tryParse(_temperatureController.text.trim());
    if (temperature == null || temperature <= 0) {
      setState(() => _localError = 'Temperature must be above 0K');
      return;
    }
    setState(() => _localError = null);
    ref.read(nightLightControllerProvider.notifier).setTemperature(temperature);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<NightLightStatus> status = ref.watch(
      nightLightStatusProvider,
    );
    final AsyncValue<ScheduleStatus> schedule = ref.watch(
      scheduleStatusProvider,
    );
    return status.when(
      data: (NightLightStatus status) =>
          _buildStatus(status, schedule.asData?.value),
      loading: () => const Center(child: HyprSpinner.panel()),
      error: (Object error, StackTrace stackTrace) => HyprEmptyState(
        symbol: 'NITE',
        message: 'Night light unavailable: $error',
      ),
    );
  }

  Widget _buildStatus(NightLightStatus status, ScheduleStatus? schedule) {
    final _NightLightView view = _NightLightView.fromStatus(status);
    final _ScheduleView scheduleView = _ScheduleView.fromStatus(schedule);
    _syncTemperature(view.temperature);
    final String? detail = _localError ?? view.message;

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        DecoratedBox(
          decoration: ShapeDecoration(
            color: Colors.black.withValues(alpha: view.available ? 0.16 : 0.10),
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(9),
              side: BorderSide(
                color: view.available
                    ? HyprColors.popupStroke
                    : HyprColors.popupStroke.withValues(alpha: 0.55),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
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
                            'Night light',
                            style: HyprTypography.popRow.copyWith(
                              fontSize: HyprTypography.size(13),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            view.available
                                ? 'hyprsunset ${view.enabled ? 'active' : 'ready'}'
                                : 'hyprsunset unavailable',
                            style: HyprTypography.popRow.copyWith(
                              color: HyprColors.textFaint,
                              fontSize: HyprTypography.size(11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    HyprBadge.text(
                      label: view.badgeLabel,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      color: Colors.black.withValues(alpha: 0.12),
                      borderColor: HyprColors.popupStroke.withValues(
                        alpha: 0.65,
                      ),
                      borderRadius: BorderRadius.circular(5),
                      textColor: view.available && view.enabled
                          ? HyprColors.accent
                          : HyprColors.textMuted,
                      style: HyprTypography.compactMonoStrong.copyWith(
                        fontSize: HyprTypography.size(11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    SizedBox(
                      width: 118,
                      child: TextField(
                        controller: _temperatureController,
                        focusNode: _temperatureFocus,
                        enabled: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onSubmitted: (_) => _applyTemperature(),
                        style: HyprTypography.compactMonoStrong.copyWith(
                          color: view.available
                              ? HyprColors.text
                              : HyprColors.text,
                          fontSize: HyprTypography.size(12),
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          suffixText: 'K',
                          suffixStyle: HyprTypography.compactMono.copyWith(
                            color: HyprColors.textFaint,
                            fontSize: HyprTypography.size(11),
                          ),
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.16),
                          border: _inputBorder(HyprColors.popupStroke),
                          enabledBorder: _inputBorder(HyprColors.popupStroke),
                          focusedBorder: _inputBorder(HyprColors.accentSoft),
                          disabledBorder: _inputBorder(
                            HyprColors.popupStroke.withValues(alpha: 0.45),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    HyprCommandButton(
                      label: 'Apply',
                      onPressed: _applyTemperature,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      constraints: const BoxConstraints(minHeight: 34),
                      textStyle: HyprTypography.compactMonoStrong.copyWith(
                        fontSize: HyprTypography.size(10.5),
                      ),
                    ),
                    const Spacer(),
                    HyprCommandButton(
                      label: view.buttonLabel,
                      onPressed: () => ref
                          .read(nightLightControllerProvider.notifier)
                          .setEnabled(enabled: !view.enabled),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      constraints: const BoxConstraints(minHeight: 34),
                      textStyle: HyprTypography.compactMonoStrong.copyWith(
                        fontSize: HyprTypography.size(10.5),
                      ),
                    ),
                  ],
                ),
                if (detail != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HyprTypography.popRow.copyWith(
                      color: _localError == null
                          ? HyprColors.textFaint
                          : HyprColors.danger,
                      fontSize: HyprTypography.size(11),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _ScheduleCard(
          view: scheduleView,
          enabled: true,
          onChanged: ({bool? enabled, int? startHour, int? stopHour}) {
            ref
                .read(scheduleControllerProvider.notifier)
                .setDailyWindow(
                  action: ScheduleAction.nightLight,
                  enabled: enabled ?? scheduleView.enabled,
                  startHour: startHour ?? scheduleView.startHour,
                  stopHour: stopHour ?? scheduleView.stopHour,
                );
          },
        ),
      ],
    );
  }
}

OutlineInputBorder _inputBorder(Color color) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: BorderSide(color: color),
  );
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.view,
    required this.enabled,
    required this.onChanged,
  });

  final _ScheduleView view;
  final bool enabled;
  final void Function({bool? enabled, int? startHour, int? stopHour}) onChanged;

  @override
  Widget build(BuildContext context) {
    final Color contentColor = enabled ? HyprColors.text : HyprColors.textFaint;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Colors.black.withValues(alpha: enabled ? 0.14 : 0.08),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(9),
          side: BorderSide(
            color: HyprColors.popupStroke.withValues(alpha: enabled ? 1 : 0.45),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? () => onChanged(enabled: !view.enabled) : null,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Schedule',
                          style: HyprTypography.popRow.copyWith(
                            color: contentColor,
                            fontSize: HyprTypography.size(13),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatHour(view.startHour)} - ${_formatHour(view.stopHour)}',
                          style: HyprTypography.compactMono.copyWith(
                            color: HyprColors.textFaint,
                            fontSize: HyprTypography.size(11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  HyprToggleSwitch(
                    key: const ValueKey<String>('night-light-schedule-toggle'),
                    value: view.enabled,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _HourSelect(
                    key: const ValueKey<String>('night-light-schedule-start'),
                    label: 'Start',
                    value: view.startHour,
                    enabled: enabled,
                    onChanged: (int value) => onChanged(startHour: value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HourSelect(
                    key: const ValueKey<String>('night-light-schedule-stop'),
                    label: 'Stop',
                    value: view.stopHour,
                    enabled: enabled,
                    onChanged: (int value) => onChanged(stopHour: value),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HourSelect extends StatelessWidget {
  const _HourSelect({
    super.key,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: HyprColors.popupStroke.withValues(alpha: enabled ? 1 : 0.45),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Row(
          children: <Widget>[
            Text(
              label,
              style: HyprTypography.popRow.copyWith(
                color: HyprColors.textFaint,
                fontSize: HyprTypography.size(10.5),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: value,
                  isDense: true,
                  isExpanded: true,
                  dropdownColor: HyprColors.surfaceStrong,
                  iconEnabledColor: HyprColors.textMuted,
                  iconDisabledColor: HyprColors.textFaint,
                  style: HyprTypography.compactMonoStrong.copyWith(
                    color: enabled ? HyprColors.text : HyprColors.textFaint,
                    fontSize: HyprTypography.size(11.5),
                  ),
                  onChanged: enabled
                      ? (int? next) {
                          if (next != null) {
                            onChanged(next);
                          }
                        }
                      : null,
                  items: List<DropdownMenuItem<int>>.generate(
                    24,
                    (int hour) => DropdownMenuItem<int>(
                      value: hour,
                      child: Text(_formatHour(hour)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NightLightView {
  const _NightLightView({
    required this.available,
    required this.enabled,
    required this.temperature,
    required this.message,
  });

  final bool available;
  final bool enabled;
  final int temperature;
  final String? message;

  String get badgeLabel {
    if (!available) {
      return 'Unavailable';
    }
    return enabled ? 'On' : 'Off';
  }

  String get buttonLabel {
    if (!available) {
      return enabled ? 'Disable' : 'Retry';
    }
    return enabled ? 'Disable' : 'Enable';
  }

  factory _NightLightView.fromStatus(NightLightStatus status) {
    return switch (status) {
      NightLightStatusAvailable(:final enabled, :final temperature) =>
        _NightLightView(
          available: true,
          enabled: enabled,
          temperature: temperature,
          message: null,
        ),
      NightLightStatusUnavailable(
        :final enabled,
        :final temperature,
        :final message,
      ) =>
        _NightLightView(
          available: false,
          enabled: enabled,
          temperature: temperature,
          message: message,
        ),
      _ => const _NightLightView(
        available: false,
        enabled: false,
        temperature: 3500,
        message: null,
      ),
    };
  }
}

class _ScheduleView {
  const _ScheduleView({
    required this.enabled,
    required this.startHour,
    required this.stopHour,
  });

  final bool enabled;
  final int startHour;
  final int stopHour;

  static const _ScheduleView fallback = _ScheduleView(
    enabled: false,
    startHour: 21,
    stopHour: 7,
  );

  factory _ScheduleView.fromStatus(ScheduleStatus? status) {
    if (status == null) {
      return fallback;
    }

    for (final ScheduleEntry entry in status.entries) {
      if (entry.action == ScheduleAction.nightLight) {
        return _ScheduleView(
          enabled: entry.enabled,
          startHour: entry.startHour,
          stopHour: entry.stopHour,
        );
      }
    }

    return fallback;
  }
}

String _formatHour(int hour) => '${hour.toString().padLeft(2, '0')}:00';
