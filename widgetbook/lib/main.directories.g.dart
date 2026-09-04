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
import 'package:hyprbaric_widgetbook/use_cases/bar/bar_cluster_button_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_bar_bar_cluster_button_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/bar/bar_cluster_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_bar_bar_cluster_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/bar/bar_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_bar_bar_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/bar/workspace_strip_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_bar_workspace_strip_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/clock/clock_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_clock_clock_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/controls/control_atom_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_controls_control_atom_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/controls/controls_panel_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_controls_controls_panel_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/launcher/app_launcher_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_launcher_app_launcher_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/network/network_panel_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_network_network_panel_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/notifications/notification_atom_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_notifications_notification_atom_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/notifications/notification_panel_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_notifications_notification_panel_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/notifications/toast_atom_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_notifications_toast_atom_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/notifications/toast_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_notifications_toast_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/osd/osd_atom_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_osd_osd_atom_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/osd/osd_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_osd_osd_use_cases;
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
import 'package:hyprbaric_widgetbook/use_cases/primitives/shared_primitives_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_primitives_shared_primitives_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/primitives/surface_primitive_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_primitives_surface_primitive_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/session/session_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_session_session_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/settings/settings_chrome_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_settings_settings_chrome_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/settings/settings_subpanel_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_settings_settings_subpanel_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/settings/settings_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_settings_settings_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/setup/setup_guide_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_setup_setup_guide_use_cases;
import 'package:hyprbaric_widgetbook/use_cases/tray/tray_use_cases.dart'
    as _hyprbaric_widgetbook_use_cases_tray_tray_use_cases;
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
          _widgetbook.WidgetbookComponent(
            name: 'HyprPanelDivider',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Vertical divider',
                builder:
                    _hyprbaric_widgetbook_use_cases_audio_audio_atom_use_cases
                        .buildAudioChromeAtoms,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Bar',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'WorkspaceButton',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'States',
                builder:
                    _hyprbaric_widgetbook_use_cases_bar_workspace_strip_use_cases
                        .buildWorkspaceButtonStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'WorkspaceNavButton',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Previous and next',
                builder:
                    _hyprbaric_widgetbook_use_cases_bar_workspace_strip_use_cases
                        .buildWorkspaceNavButtonStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'WorkspaceStripPlaceholder',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Loading and error',
                builder:
                    _hyprbaric_widgetbook_use_cases_bar_workspace_strip_use_cases
                        .buildWorkspaceStripPlaceholders,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Bar controls',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'AudioDisplayButton',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Audio and display',
                builder:
                    _hyprbaric_widgetbook_use_cases_bar_bar_cluster_button_use_cases
                        .buildAudioDisplayButtonStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'BarGlyphIcon',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Glyph rendering',
                builder:
                    _hyprbaric_widgetbook_use_cases_bar_bar_cluster_button_use_cases
                        .buildBarGlyphIcons,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'BarIconActionButton',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Open states',
                builder:
                    _hyprbaric_widgetbook_use_cases_bar_bar_cluster_button_use_cases
                        .buildBarIconActionButtonStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'BarVolumeKnobIcon',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Accent tints',
                builder:
                    _hyprbaric_widgetbook_use_cases_bar_bar_cluster_button_use_cases
                        .buildBarVolumeKnobIconStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'ClockButton',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Clock states',
                builder:
                    _hyprbaric_widgetbook_use_cases_bar_bar_cluster_button_use_cases
                        .buildClockButtonStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'NotificationButton',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Notification states',
                builder:
                    _hyprbaric_widgetbook_use_cases_bar_bar_cluster_button_use_cases
                        .buildBarNotificationButtonStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'PowerButton',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Session states',
                builder:
                    _hyprbaric_widgetbook_use_cases_bar_bar_cluster_button_use_cases
                        .buildPowerButtonStates,
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
            name: 'HyprCommandButton',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Variants',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_shared_primitives_use_cases
                        .buildCommandButtonVariants,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'HyprConsoleSectionLabel',
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
            name: 'HyprConsoleTray',
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
            name: 'HyprHardwareToggle',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'On and off',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_shared_primitives_use_cases
                        .buildHardwareToggleStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'HyprHoverPlate',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Interactive states',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_shared_primitives_use_cases
                        .buildHoverPlateStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'HyprInteractionRegion',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Interaction states',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_shared_primitives_use_cases
                        .buildInteractionRegionStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'HyprInteractiveTile',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Selection states',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_shared_primitives_use_cases
                        .buildInteractiveTileStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'HyprPopoverPanel',
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
            name: 'HyprTextFieldChrome',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Field states',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_shared_primitives_use_cases
                        .buildTextFieldChromeStates,
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
          _widgetbook.WidgetbookComponent(
            name: 'HyprBracketedTag',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Bracketed tag',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_shared_primitives_use_cases
                        .buildBracketedTag,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'HyprEmptyState',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Message states',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_shared_primitives_use_cases
                        .buildEmptyStateMessages,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'HyprGlyphBadge',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Identity states',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_shared_primitives_use_cases
                        .buildGlyphBadgeStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'HyprInlineTag',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Tag styles',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_shared_primitives_use_cases
                        .buildInlineTagStyles,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'HyprMetricCard',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Metric alignment',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_shared_primitives_use_cases
                        .buildMetricCardStates,
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
            name: 'NotificationPlaceholder',
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
        name: 'OSD',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'OsdHeader',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Volume, muted, and brightness',
                builder: _hyprbaric_widgetbook_use_cases_osd_osd_atom_use_cases
                    .buildOsdHeaderStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'OsdMeter',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Fill and peak hold',
                builder: _hyprbaric_widgetbook_use_cases_osd_osd_atom_use_cases
                    .buildOsdMeterStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'OsdReadoutView',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Decibels and percent',
                builder: _hyprbaric_widgetbook_use_cases_osd_osd_atom_use_cases
                    .buildOsdReadoutViewStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'OsdScale',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Volume and brightness ticks',
                builder: _hyprbaric_widgetbook_use_cases_osd_osd_atom_use_cases
                    .buildOsdScaleStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'OsdSegment',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Active, peak, and idle',
                builder: _hyprbaric_widgetbook_use_cases_osd_osd_atom_use_cases
                    .buildOsdSegmentStates,
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
          _widgetbook.WidgetbookComponent(
            name: 'HyprPanelDivider',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Divider treatments',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_shared_primitives_use_cases
                        .buildPanelDividers,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'HyprPanelHeader',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Header and dividers',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_shared_primitives_use_cases
                        .buildPanelChrome,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'HyprPlateButton',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Settings row',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_shared_primitives_use_cases
                        .buildPlateButton,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'HyprSectionBreak',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Section break',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_shared_primitives_use_cases
                        .buildSectionBreak,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'HyprSectionLabel',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Trailing line',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_shared_primitives_use_cases
                        .buildSectionLabel,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Settings',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'KeybindingRow',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Binding states',
                builder:
                    _hyprbaric_widgetbook_use_cases_settings_settings_chrome_use_cases
                        .buildKeybindingRowStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'SettingsContentHeader',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Every tab',
                builder:
                    _hyprbaric_widgetbook_use_cases_settings_settings_chrome_use_cases
                        .buildSettingsContentHeaderStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'SettingsSidebar',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Interactive',
                builder:
                    _hyprbaric_widgetbook_use_cases_settings_settings_chrome_use_cases
                        .buildSettingsSidebar,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'SettingsTabBody',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'About',
                builder:
                    _hyprbaric_widgetbook_use_cases_settings_settings_chrome_use_cases
                        .buildAboutSettingsTabBody,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Appearance',
                builder:
                    _hyprbaric_widgetbook_use_cases_settings_settings_chrome_use_cases
                        .buildAppearanceSettingsTabBody,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Display',
                builder:
                    _hyprbaric_widgetbook_use_cases_settings_settings_chrome_use_cases
                        .buildDisplaySettingsTabBody,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Keybinds',
                builder:
                    _hyprbaric_widgetbook_use_cases_settings_settings_chrome_use_cases
                        .buildKeybindsSettingsTabBody,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Modules',
                builder:
                    _hyprbaric_widgetbook_use_cases_settings_settings_chrome_use_cases
                        .buildModulesSettingsTabBody,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Workspaces',
                builder:
                    _hyprbaric_widgetbook_use_cases_settings_settings_chrome_use_cases
                        .buildWorkspacesSettingsTabBody,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'SettingsTabButton',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Active and idle',
                builder:
                    _hyprbaric_widgetbook_use_cases_settings_settings_chrome_use_cases
                        .buildSettingsTabButtonStates,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Setup',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'SetupGuideControls',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Controls — every step',
                builder:
                    _hyprbaric_widgetbook_use_cases_setup_setup_guide_use_cases
                        .buildSetupGuideControlsSteps,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'SetupGuidePreview',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Stage — every step',
                builder:
                    _hyprbaric_widgetbook_use_cases_setup_setup_guide_use_cases
                        .buildSetupGuidePreviewSteps,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Surfaces',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'HyprDivider',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Bar divider',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_surface_primitive_use_cases
                        .buildDivider,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'HyprGlassFrame',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Frame treatments',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_shared_primitives_use_cases
                        .buildGlassFrameTreatments,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'HyprGlassSurface',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Glass frame',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_surface_primitive_use_cases
                        .buildGlassSurface,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'HyprInsetBorder',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Inset treatment',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_surface_primitive_use_cases
                        .buildInsetBorder,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'HyprPopoverPanel',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Popover frame',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_shared_primitives_use_cases
                        .buildPopoverPanel,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'HyprPopoverSurface',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Popover frame',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_surface_primitive_use_cases
                        .buildPopoverSurface,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'HyprSurface',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Panel frame',
                builder:
                    _hyprbaric_widgetbook_use_cases_primitives_surface_primitive_use_cases
                        .buildSurface,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Toasts',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'ToastAppTag',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Accents',
                builder:
                    _hyprbaric_widgetbook_use_cases_notifications_toast_atom_use_cases
                        .buildToastAppTagStates,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'ToastCornerBrackets',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Frame corners',
                builder:
                    _hyprbaric_widgetbook_use_cases_notifications_toast_atom_use_cases
                        .buildToastCornerBrackets,
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
        name: 'Bar',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'CenterCluster',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Empty desktop',
                builder:
                    _hyprbaric_widgetbook_use_cases_bar_bar_cluster_use_cases
                        .buildEmptyCenterCluster,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Focused window',
                builder:
                    _hyprbaric_widgetbook_use_cases_bar_bar_cluster_use_cases
                        .buildFocusedCenterCluster,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'Hyprbaric',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Desktop — active',
                builder: _hyprbaric_widgetbook_use_cases_bar_bar_use_cases
                    .buildDesktopBar,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Laptop — active',
                builder: _hyprbaric_widgetbook_use_cases_bar_bar_use_cases
                    .buildLaptopBar,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'LeftCluster',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Awaiting compositor',
                builder:
                    _hyprbaric_widgetbook_use_cases_bar_bar_cluster_use_cases
                        .buildLoadingLeftCluster,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Launcher open',
                builder:
                    _hyprbaric_widgetbook_use_cases_bar_bar_cluster_use_cases
                        .buildLauncherOpenLeftCluster,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Numeric workspaces',
                builder:
                    _hyprbaric_widgetbook_use_cases_bar_bar_cluster_use_cases
                        .buildNumericLeftCluster,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Roman workspaces',
                builder:
                    _hyprbaric_widgetbook_use_cases_bar_bar_cluster_use_cases
                        .buildRomanLeftCluster,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'WorkspaceStrip',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Interactive',
                builder:
                    _hyprbaric_widgetbook_use_cases_bar_workspace_strip_use_cases
                        .buildInteractiveWorkspaceStrip,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Numeric',
                builder:
                    _hyprbaric_widgetbook_use_cases_bar_workspace_strip_use_cases
                        .buildNumericWorkspaceStrip,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Read-only',
                builder:
                    _hyprbaric_widgetbook_use_cases_bar_workspace_strip_use_cases
                        .buildReadOnlyWorkspaceStrip,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Roman',
                builder:
                    _hyprbaric_widgetbook_use_cases_bar_workspace_strip_use_cases
                        .buildRomanWorkspaceStrip,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Special workspace',
                builder:
                    _hyprbaric_widgetbook_use_cases_bar_workspace_strip_use_cases
                        .buildSpecialWorkspaceStrip,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Calendar',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'ClockPanel',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Interactive calendar',
                builder: _hyprbaric_widgetbook_use_cases_clock_clock_use_cases
                    .buildInteractiveCalendar,
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
        name: 'Launcher',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'AppLauncherConsole',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Empty',
                builder:
                    _hyprbaric_widgetbook_use_cases_launcher_app_launcher_use_cases
                        .buildEmptyAppLauncher,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Error',
                builder:
                    _hyprbaric_widgetbook_use_cases_launcher_app_launcher_use_cases
                        .buildErrorAppLauncher,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Filtered',
                builder:
                    _hyprbaric_widgetbook_use_cases_launcher_app_launcher_use_cases
                        .buildFilteredAppLauncher,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Loading',
                builder:
                    _hyprbaric_widgetbook_use_cases_launcher_app_launcher_use_cases
                        .buildLoadingAppLauncher,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Populated',
                builder:
                    _hyprbaric_widgetbook_use_cases_launcher_app_launcher_use_cases
                        .buildAppLauncher,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Network',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'NetworkPanel',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Connected — networks and traffic',
                builder:
                    _hyprbaric_widgetbook_use_cases_network_network_panel_use_cases
                        .buildConnectedNetworkPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Interactive Wi-Fi',
                builder:
                    _hyprbaric_widgetbook_use_cases_network_network_panel_use_cases
                        .buildInteractiveNetworkPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Loading',
                builder:
                    _hyprbaric_widgetbook_use_cases_network_network_panel_use_cases
                        .buildLoadingNetworkPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'No device',
                builder:
                    _hyprbaric_widgetbook_use_cases_network_network_panel_use_cases
                        .buildNoDeviceNetworkPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Scanning',
                builder:
                    _hyprbaric_widgetbook_use_cases_network_network_panel_use_cases
                        .buildScanningNetworkPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Service unavailable',
                builder:
                    _hyprbaric_widgetbook_use_cases_network_network_panel_use_cases
                        .buildNetworkServiceError,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Wi-Fi off',
                builder:
                    _hyprbaric_widgetbook_use_cases_network_network_panel_use_cases
                        .buildWifiOffNetworkPanel,
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
        name: 'OSD',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'OsdPanel',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Brightness',
                builder: _hyprbaric_widgetbook_use_cases_osd_osd_use_cases
                    .buildBrightnessOsd,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Muted volume',
                builder: _hyprbaric_widgetbook_use_cases_osd_osd_use_cases
                    .buildMutedVolumeOsd,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Volume',
                builder: _hyprbaric_widgetbook_use_cases_osd_osd_use_cases
                    .buildVolumeOsd,
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
      _widgetbook.WidgetbookFolder(
        name: 'Session',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'SessionLauncherCard',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Actions',
                builder:
                    _hyprbaric_widgetbook_use_cases_session_session_use_cases
                        .buildSessionActions,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Confirmation',
                builder:
                    _hyprbaric_widgetbook_use_cases_session_session_use_cases
                        .buildSessionConfirmation,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Interactive',
                builder:
                    _hyprbaric_widgetbook_use_cases_session_session_use_cases
                        .buildInteractiveSession,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Settings',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'AboutSettingsPanel',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Capabilities',
                builder:
                    _hyprbaric_widgetbook_use_cases_settings_settings_subpanel_use_cases
                        .buildAboutSettingsPanel,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AppearanceSettingsPanel',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Customized',
                builder:
                    _hyprbaric_widgetbook_use_cases_settings_settings_subpanel_use_cases
                        .buildCustomizedAppearanceSettingsPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Defaults',
                builder:
                    _hyprbaric_widgetbook_use_cases_settings_settings_subpanel_use_cases
                        .buildAppearanceSettingsPanel,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'KeybindingsPanel',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Loading',
                builder:
                    _hyprbaric_widgetbook_use_cases_settings_settings_subpanel_use_cases
                        .buildLoadingKeybindingsPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Populated',
                builder:
                    _hyprbaric_widgetbook_use_cases_settings_settings_subpanel_use_cases
                        .buildKeybindingsPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Unavailable',
                builder:
                    _hyprbaric_widgetbook_use_cases_settings_settings_subpanel_use_cases
                        .buildUnavailableKeybindingsPanel,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'ModulesSettingsPanel',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'All modules enabled',
                builder:
                    _hyprbaric_widgetbook_use_cases_settings_settings_subpanel_use_cases
                        .buildAllModulesSettingsPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Focused modules',
                builder:
                    _hyprbaric_widgetbook_use_cases_settings_settings_subpanel_use_cases
                        .buildFocusedModulesSettingsPanel,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'NightLightSettingsPanel',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Enabled with schedule',
                builder:
                    _hyprbaric_widgetbook_use_cases_settings_settings_subpanel_use_cases
                        .buildEnabledNightLightSettingsPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Unavailable',
                builder:
                    _hyprbaric_widgetbook_use_cases_settings_settings_subpanel_use_cases
                        .buildUnavailableNightLightSettingsPanel,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'SettingsOverlayContent',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Interactive menu',
                builder:
                    _hyprbaric_widgetbook_use_cases_settings_settings_use_cases
                        .buildSettingsMenu,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'WorkspacesSettingsPanel',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Numeric indicators',
                builder:
                    _hyprbaric_widgetbook_use_cases_settings_settings_subpanel_use_cases
                        .buildNumericWorkspacesSettingsPanel,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Roman indicators',
                builder:
                    _hyprbaric_widgetbook_use_cases_settings_settings_subpanel_use_cases
                        .buildRomanWorkspacesSettingsPanel,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Setup',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'SetupGuideCard',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Accent',
                builder:
                    _hyprbaric_widgetbook_use_cases_setup_setup_guide_use_cases
                        .buildAccentSetupGuide,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Interactive',
                builder:
                    _hyprbaric_widgetbook_use_cases_setup_setup_guide_use_cases
                        .buildInteractiveSetupGuide,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Layout',
                builder:
                    _hyprbaric_widgetbook_use_cases_setup_setup_guide_use_cases
                        .buildLayoutSetupGuide,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Transparency',
                builder:
                    _hyprbaric_widgetbook_use_cases_setup_setup_guide_use_cases
                        .buildTransparencySetupGuide,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Welcome',
                builder:
                    _hyprbaric_widgetbook_use_cases_setup_setup_guide_use_cases
                        .buildWelcomeSetupGuide,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Toasts',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'ToastPill',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Critical',
                builder:
                    _hyprbaric_widgetbook_use_cases_notifications_toast_use_cases
                        .buildCriticalToast,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Interactive stack',
                builder:
                    _hyprbaric_widgetbook_use_cases_notifications_toast_use_cases
                        .buildInteractiveToasts,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Normal',
                builder:
                    _hyprbaric_widgetbook_use_cases_notifications_toast_use_cases
                        .buildNormalToast,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Tray',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'TrayMenuPanel',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Empty',
                builder: _hyprbaric_widgetbook_use_cases_tray_tray_use_cases
                    .buildEmptyTrayMenu,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Nested actions',
                builder: _hyprbaric_widgetbook_use_cases_tray_tray_use_cases
                    .buildNestedTrayMenu,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Populated',
                builder: _hyprbaric_widgetbook_use_cases_tray_tray_use_cases
                    .buildPopulatedTrayMenu,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'TrayStrip',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Empty',
                builder: _hyprbaric_widgetbook_use_cases_tray_tray_use_cases
                    .buildEmptyTrayStrip,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Interactive',
                builder: _hyprbaric_widgetbook_use_cases_tray_tray_use_cases
                    .buildInteractiveTrayStrip,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Populated',
                builder: _hyprbaric_widgetbook_use_cases_tray_tray_use_cases
                    .buildPopulatedTrayStrip,
              ),
            ],
          ),
        ],
      ),
    ],
  ),
];
