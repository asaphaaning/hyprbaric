// dart format width=80
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering

// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AppGenerator
// **************************************************************************

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:hyprbaric_widgetbook/use_cases/power/battery_chip_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_power_battery_chip_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/primitives/hypr_action_row_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_primitives_hypr_action_row_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/primitives/hypr_badge_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_primitives_hypr_badge_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/primitives/hypr_toggle_switch_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_primitives_hypr_toggle_switch_use_cases;
import 'package:widgetbook/widgetbook.dart' as _widgetbook;

final directories = <_widgetbook.WidgetbookNode>[
  _widgetbook.WidgetbookCategory(
    name: 'Building blocks',
    children: [
      _widgetbook.WidgetbookFolder(
        name: 'Controls',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'HyprToggleSwitch',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'States',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_hypr_toggle_switch_use_cases
                        .buildToggleSwitchStates,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Feedback',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'HyprBadge',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Tones',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_hypr_badge_use_cases
                        .buildBadgeTones,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Rows',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'HyprActionRow',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'States',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_hypr_action_row_use_cases
                        .buildActionRowStates,
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  _widgetbook.WidgetbookCategory(
    name: 'Widgets',
    children: [
      _widgetbook.WidgetbookFolder(
        name: 'Power',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'BatteryChip',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Desktop — no battery',
                builder:
                    _hyprbaric_widgetbook_use_cases_power_battery_chip_use_cases
                        .buildDesktopBatteryChip,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Interactive',
                builder:
                    _hyprbaric_widgetbook_use_cases_power_battery_chip_use_cases
                        .buildInteractiveBatteryChip,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Laptop — charging',
                builder:
                    _hyprbaric_widgetbook_use_cases_power_battery_chip_use_cases
                        .buildChargingBatteryChip,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Laptop — discharging',
                builder:
                    _hyprbaric_widgetbook_use_cases_power_battery_chip_use_cases
                        .buildDischargingBatteryChip,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Laptop — full',
                builder:
                    _hyprbaric_widgetbook_use_cases_power_battery_chip_use_cases
                        .buildFullBatteryChip,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Laptop — low battery',
                builder:
                    _hyprbaric_widgetbook_use_cases_power_battery_chip_use_cases
                        .buildLowBatteryChip,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'State matrix',
                builder:
                    _hyprbaric_widgetbook_use_cases_power_battery_chip_use_cases
                        .buildBatteryStateMatrix,
              ),
            ],
          ),
        ],
      ),
    ],
  ),
];
