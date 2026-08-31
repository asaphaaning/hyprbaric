// dart format width=80
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering

// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AppGenerator
// **************************************************************************

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:hyprbaric_widgetbook/use_cases/audio/audio_atom_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_audio_audio_atom_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/audio/audio_panel_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_audio_audio_panel_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/controls/control_atom_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_controls_control_atom_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/controls/controls_panel_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_controls_controls_panel_use_cases;
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
        name: 'Audio',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'AudioChannelStrip',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Endpoint strips',
                builder:
                    _hyprbaric_widgetbook_use_cases_audio_audio_atom_use_cases
                        .buildAudioChannelStripStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AudioDbReadout',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Decibel states',
                builder:
                    _hyprbaric_widgetbook_use_cases_audio_audio_atom_use_cases
                        .buildAudioDbReadoutStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AudioDisabledFader',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Unavailable',
                builder:
                    _hyprbaric_widgetbook_use_cases_audio_audio_atom_use_cases
                        .buildAudioDisabledFader,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AudioFader',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Fader states',
                builder:
                    _hyprbaric_widgetbook_use_cases_audio_audio_atom_use_cases
                        .buildAudioFaderStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AudioMasterRail',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'States',
                builder:
                    _hyprbaric_widgetbook_use_cases_audio_audio_atom_use_cases
                        .buildAudioMasterRailStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AudioMessage',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Unavailable message',
                builder:
                    _hyprbaric_widgetbook_use_cases_audio_audio_atom_use_cases
                        .buildAudioMessageStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AudioMixerDivider',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Vertical divider',
                builder:
                    _hyprbaric_widgetbook_use_cases_audio_audio_atom_use_cases
                        .buildAudioChromeAtoms,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AudioMixerFooter',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'External mixer',
                builder:
                    _hyprbaric_widgetbook_use_cases_audio_audio_atom_use_cases
                        .buildAudioMixerFooter,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AudioMixerHeader',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Mixer header',
                builder:
                    _hyprbaric_widgetbook_use_cases_audio_audio_atom_use_cases
                        .buildAudioMixerHeaderStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AudioMixerStage',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Mixer stage',
                builder:
                    _hyprbaric_widgetbook_use_cases_audio_audio_atom_use_cases
                        .buildAudioMixerStage,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AudioMuteButton',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Mute states',
                builder:
                    _hyprbaric_widgetbook_use_cases_audio_audio_atom_use_cases
                        .buildAudioMuteButtonStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'BrightnessControl',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Brightness control',
                builder:
                    _hyprbaric_widgetbook_use_cases_audio_audio_atom_use_cases
                        .buildBrightnessControlStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'BrightnessKnob',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Console knob',
                builder:
                    _hyprbaric_widgetbook_use_cases_audio_audio_atom_use_cases
                        .buildBrightnessKnobStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'BrightnessKnobReadout',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Brightness readout',
                builder:
                    _hyprbaric_widgetbook_use_cases_audio_audio_atom_use_cases
                        .buildBrightnessKnobReadoutStates,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Controls',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'ControlCapturePad',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Capture modes',
                builder:
                    _hyprbaric_widgetbook_use_cases_controls_control_atom_use_cases
                        .buildControlCapturePadStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'ControlChassis',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Translucent chassis',
                builder:
                    _hyprbaric_widgetbook_use_cases_controls_control_atom_use_cases
                        .buildControlChassis,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'ControlInspectButton',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Inspect actions',
                builder:
                    _hyprbaric_widgetbook_use_cases_controls_control_atom_use_cases
                        .buildControlInspectButtonStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'ControlRecordPad',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Recording phases',
                builder:
                    _hyprbaric_widgetbook_use_cases_controls_control_atom_use_cases
                        .buildControlRecordPadStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'ControlRocker',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Rocker states',
                builder:
                    _hyprbaric_widgetbook_use_cases_controls_control_atom_use_cases
                        .buildControlRockerStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'ControlSectionLabel',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Section label',
                builder:
                    _hyprbaric_widgetbook_use_cases_controls_control_atom_use_cases
                        .buildControlSectionLabel,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'ControlSectionTray',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Tray and label',
                builder:
                    _hyprbaric_widgetbook_use_cases_controls_control_atom_use_cases
                        .buildControlSectionTray,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'ControlSettingsRow',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Settings row',
                builder:
                    _hyprbaric_widgetbook_use_cases_controls_control_atom_use_cases
                        .buildControlSettingsRow,
              ),
            ],
          ),
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
        name: 'Audio',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'AudioPanel',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Interactive',
                builder:
                    _hyprbaric_widgetbook_use_cases_audio_audio_panel_use_cases
                        .buildInteractiveAudioPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Loading',
                builder:
                    _hyprbaric_widgetbook_use_cases_audio_audio_panel_use_cases
                        .buildLoadingAudioPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Muted output',
                builder:
                    _hyprbaric_widgetbook_use_cases_audio_audio_panel_use_cases
                        .buildMutedAudioPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Output only',
                builder:
                    _hyprbaric_widgetbook_use_cases_audio_audio_panel_use_cases
                        .buildOutputOnlyAudioPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Ready',
                builder:
                    _hyprbaric_widgetbook_use_cases_audio_audio_panel_use_cases
                        .buildReadyAudioPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Unavailable',
                builder:
                    _hyprbaric_widgetbook_use_cases_audio_audio_panel_use_cases
                        .buildUnavailableAudioPanel,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Controls',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'ControlsPanel',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Active toggles',
                builder:
                    _hyprbaric_widgetbook_use_cases_controls_controls_panel_use_cases
                        .buildActiveControlsPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Interactive toggles',
                builder:
                    _hyprbaric_widgetbook_use_cases_controls_controls_panel_use_cases
                        .buildInteractiveControlsPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Ready',
                builder:
                    _hyprbaric_widgetbook_use_cases_controls_controls_panel_use_cases
                        .buildReadyControlsPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Selecting recording region',
                builder:
                    _hyprbaric_widgetbook_use_cases_controls_controls_panel_use_cases
                        .buildSelectingRecordingControlsPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Services unavailable',
                builder:
                    _hyprbaric_widgetbook_use_cases_controls_controls_panel_use_cases
                        .buildUnavailableControlsPanel,
              ),
            ],
          ),
        ],
      ),
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
