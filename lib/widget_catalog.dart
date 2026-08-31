/// Production UI and typed fixtures exposed to Hyprbaric's isolated catalogs.
library;

export 'src/bindings/bindings.dart'
    show
        AudioEndpoint,
        AudioEndpointKind,
        AppLauncherEntry,
        AppLauncherPhase,
        AppLauncherResults,
        AudioStatus,
        AudioStatusAvailable,
        AudioStatusUnavailable,
        BrightnessStatus,
        BrightnessStatusAvailable,
        BrightnessStatusDiscovering,
        BrightnessStatusUnavailable,
        CalendarCommand,
        CaffeineStatus,
        CaffeineStatusAvailable,
        CaffeineStatusUnavailable,
        CalendarDay,
        ClockStatus,
        FocusedWindowStatus,
        MonitorFocusedWindowStatus,
        MonitorWorkspaceStatus,
        NetworkEntry,
        NetworkEntryState,
        NetworkInterface,
        NetworkStatus,
        NetworkTraffic,
        NetworkTransfer,
        NightLightStatus,
        NightLightStatusAvailable,
        NightLightStatusUnavailable,
        NotificationEntry,
        NotificationStatus,
        NotificationUrgency,
        PowerBatteryState,
        PowerCommandResult,
        PowerCommandResultFailed,
        PowerCommandSetProfile,
        PowerProfile,
        PowerStatus,
        RecordingMode,
        RecordingStatus,
        RecordingStatusIdle,
        RecordingStatusSelecting,
        RecordingStatusUnavailable,
        ScreenshotMode,
        Uint64,
        WorkspaceStatus;
export 'src/features/audio/audio_channel_strip.dart'
    show AudioChannelStrip, AudioDbReadout, AudioMixerChannel, AudioMuteButton;
export 'src/features/audio/audio_chrome.dart'
    show AudioMessage, AudioMixerDivider, audioDecibelReadout;
export 'src/features/audio/audio_fader.dart'
    show AudioDisabledFader, AudioFader;
export 'src/features/audio/audio_mixer_layout.dart'
    show AudioMasterRail, AudioMixerFooter, AudioMixerHeader, AudioMixerStage;
export 'src/features/audio/audio_panel.dart' show AudioPanel;
export 'src/features/audio/brightness_control.dart'
    show BrightnessControl, BrightnessControlPresentation;
export 'src/features/audio/brightness_knob.dart'
    show BrightnessKnob, BrightnessKnobPresentation;
export 'src/features/audio/brightness_knob_readout.dart'
    show BrightnessKnobReadout;
export 'src/features/controls/control_capture_pads.dart'
    show ControlCapturePad, ControlRecordPad;
export 'src/features/controls/control_inspect_button.dart'
    show ControlInspectButton;
export 'src/features/controls/control_rocker.dart' show ControlRocker;
export 'src/features/controls/control_settings_row.dart'
    show ControlSettingsRow;
export 'src/features/controls/controls_chrome.dart'
    show ControlChassis, ControlSectionLabel, ControlSectionTray;
export 'src/features/controls/controls_panel.dart' show ControlsPanel;
export 'src/features/clock/clock_controller.dart' show ClockViewState;
export 'src/features/clock/clock_panel.dart' show ClockPanel;
export 'src/features/power/battery_chip.dart' show BatteryChip;
export 'src/features/power/power_panel.dart' show PowerPanel;
export 'src/features/power/power_profile_pad.dart' show PowerProfilePad;
export 'src/features/launcher/app_launcher_console.dart'
    show AppLauncherConsole;
export 'src/features/settings/settings_overlay_content.dart'
    show SettingsOverlayContent;
export 'src/features/settings/settings_tab_body.dart'
    show SettingsContentHeader, SettingsTabBody;
export 'src/features/settings/settings_tabs.dart'
    show SettingsSidebar, SettingsTab, SettingsTabButton;
export 'src/features/setup/setup_guide_state.dart'
    show setupGuideAutomaticHostProvider;
export 'src/hyprbaric.dart' show Hyprbaric;
export 'src/state/rust_signals/audio.dart'
    show audioStatusProvider, brightnessStatusProvider;
export 'src/state/rust_signals/clock.dart' show clockStatusProvider;
export 'src/state/rust_signals/compositor.dart'
    show focusedWindowStatusProvider, workspaceStatusProvider;
export 'src/state/rust_signals/network.dart' show networkStatusProvider;
export 'src/state/rust_signals/notifications.dart'
    show notificationStatusProvider;
export 'src/state/rust_signals/power.dart' show powerStatusProvider;
export 'src/theme/hypr_palette.dart' show HyprPalette;
export 'src/widgets/hypr_surface.dart';
export 'src/widgets/notification_panel.dart' show NotificationPanel;
export 'src/widgets/notification_panel_parts.dart'
    show
        NotificationCountPill,
        NotificationEmptyState,
        NotificationHeader,
        NotificationList;
export 'src/widgets/notification_row.dart' show NotificationRow;
export 'src/widgets/primitives/hypr_action_row.dart' show HyprActionRow;
export 'src/widgets/primitives/hypr_badge.dart' show HyprBadge;
export 'src/widgets/primitives/hypr_toggle_switch.dart' show HyprToggleSwitch;
export 'src/widgets/right_cluster_buttons.dart' show NotificationButton;
