// dart format width=80
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering

// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AppGenerator
// **************************************************************************

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:hyprbaric_widgetbook/use_cases/notifications/notification_atom_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_notifications_notification_atom_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/notifications/notification_panel_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_notifications_notification_panel_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/power/battery_chip_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_power_battery_chip_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/power/power_panel_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_power_power_panel_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/power/power_profile_pad_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_power_power_profile_pad_use_cases;
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
        name: 'Notifications',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'NotificationButton',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'States',
                builder:
                    _hyprbaric_widgetbook_use_cases_notifications_notification_atom_use_cases
                        .buildNotificationButtonStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'NotificationCountPill',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Counts',
                builder:
                    _hyprbaric_widgetbook_use_cases_notifications_notification_atom_use_cases
                        .buildNotificationCountPillStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'NotificationEmptyState',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Available and unavailable',
                builder:
                    _hyprbaric_widgetbook_use_cases_notifications_notification_atom_use_cases
                        .buildNotificationEmptyStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'NotificationHeader',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Empty and populated',
                builder:
                    _hyprbaric_widgetbook_use_cases_notifications_notification_atom_use_cases
                        .buildNotificationHeaderStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'NotificationList',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Populated',
                builder:
                    _hyprbaric_widgetbook_use_cases_notifications_notification_atom_use_cases
                        .buildNotificationList,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'NotificationRow',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Urgencies',
                builder:
                    _hyprbaric_widgetbook_use_cases_notifications_notification_atom_use_cases
                        .buildNotificationRowUrgencies,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Power',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'PowerProfilePad',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Profiles',
                builder:
                    _hyprbaric_widgetbook_use_cases_power_power_profile_pad_use_cases
                        .buildPowerProfilePadStates,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Unavailable',
                builder:
                    _hyprbaric_widgetbook_use_cases_power_power_profile_pad_use_cases
                        .buildUnavailablePowerProfilePad,
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
        name: 'Notifications',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'NotificationPanel',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Do not disturb',
                builder:
                    _hyprbaric_widgetbook_use_cases_notifications_notification_panel_use_cases
                        .buildDoNotDisturbNotificationPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Empty',
                builder:
                    _hyprbaric_widgetbook_use_cases_notifications_notification_panel_use_cases
                        .buildEmptyNotificationPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Interactive inbox',
                builder:
                    _hyprbaric_widgetbook_use_cases_notifications_notification_panel_use_cases
                        .buildInteractiveNotificationPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Overflow',
                builder:
                    _hyprbaric_widgetbook_use_cases_notifications_notification_panel_use_cases
                        .buildOverflowNotificationPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Populated',
                builder:
                    _hyprbaric_widgetbook_use_cases_notifications_notification_panel_use_cases
                        .buildPopulatedNotificationPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Service unavailable',
                builder:
                    _hyprbaric_widgetbook_use_cases_notifications_notification_panel_use_cases
                        .buildUnavailableNotificationPanel,
              ),
            ],
          ),
        ],
      ),
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
          _widgetbook.WidgetbookComponent(
            name: 'PowerPanel',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Desktop — no battery',
                builder:
                    _hyprbaric_widgetbook_use_cases_power_power_panel_use_cases
                        .buildDesktopPowerPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Interactive profiles',
                builder:
                    _hyprbaric_widgetbook_use_cases_power_power_panel_use_cases
                        .buildInteractivePowerPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Laptop — charging',
                builder:
                    _hyprbaric_widgetbook_use_cases_power_power_panel_use_cases
                        .buildChargingPowerPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Laptop — discharging',
                builder:
                    _hyprbaric_widgetbook_use_cases_power_power_panel_use_cases
                        .buildDischargingPowerPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Laptop — full',
                builder:
                    _hyprbaric_widgetbook_use_cases_power_power_panel_use_cases
                        .buildFullPowerPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Laptop — low battery',
                builder:
                    _hyprbaric_widgetbook_use_cases_power_power_panel_use_cases
                        .buildLowBatteryPowerPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Loading',
                builder:
                    _hyprbaric_widgetbook_use_cases_power_power_panel_use_cases
                        .buildLoadingPowerPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Profile command failed',
                builder:
                    _hyprbaric_widgetbook_use_cases_power_power_panel_use_cases
                        .buildFailedPowerPanel,
              ),
            ],
          ),
        ],
      ),
    ],
  ),
];
