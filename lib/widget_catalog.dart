/// Production UI and typed fixtures exposed to Hyprbaric's isolated catalogs.
library;

export 'src/bindings/bindings.dart'
    show
        AppLauncherEntry,
        AppLauncherPhase,
        AppLauncherResults,
        AppStatus,
        AppearancePosition,
        AppearanceStatus,
        AudioEndpoint,
        AudioEndpointKind,
        AudioStatus,
        AudioStatusAvailable,
        AudioStatusUnavailable,
        BrightnessStatus,
        BrightnessStatusAvailable,
        BrightnessStatusDiscovering,
        BrightnessStatusUnavailable,
        CaffeineStatus,
        CaffeineStatusAvailable,
        CaffeineStatusUnavailable,
        CalendarCommand,
        CalendarDay,
        CapabilityAvailability,
        CapabilityEntry,
        CapabilityId,
        CapabilityStatus,
        CapabilityTier,
        ClockStatus,
        FocusedWindowStatus,
        ModuleEntry,
        ModuleId,
        ModulesStatus,
        NetworkCommand,
        NetworkCommandConnect,
        NetworkCommandOpenSettings,
        NetworkCommandResult,
        NetworkCommandResultFailed,
        NetworkCommandResultStarted,
        NetworkCommandScan,
        NetworkCommandSetWifiEnabled,
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
        PortalColorScheme,
        PortalStatus,
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
        ScheduleAction,
        ScheduleEntry,
        ScheduleStatus,
        ScreenshotMode,
        SessionAction,
        SetupState,
        SetupStatus,
        ShortcutBindingInput,
        ShortcutBindingPhase,
        ShortcutBindingView,
        ShortcutMappingSource,
        ShortcutMappingView,
        ShortcutMappingViewBound,
        ShortcutMappingViewDisabled,
        ShortcutModifier,
        ShortcutSettingCategory,
        ShortcutSettingId,
        ShortcutSettingsCommandResult,
        ShortcutSettingsRow,
        ShortcutSettingsSnapshot,
        TrayIcon,
        TrayIconKind,
        TrayItem,
        TrayItemStatus,
        TrayMenuItem,
        TrayMenuItemKind,
        TrayMenuStatus,
        TrayStatus,
        Uint64,
        WorkspaceIndicatorStyle,
        WorkspaceSettingsStatus,
        WorkspaceStatus,
        WorkspaceVisibleRange;
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
export 'src/features/clock/clock_controller.dart' show ClockViewState;
export 'src/features/clock/clock_panel.dart' show ClockPanel;
export 'src/features/controls/control_capture_pads.dart'
    show ControlCapturePad, ControlRecordPad;
export 'src/features/controls/control_inspect_button.dart'
    show ControlInspectButton;
export 'src/features/controls/control_rocker.dart' show ControlRocker;
export 'src/features/controls/control_settings_row.dart'
    show ControlSettingsRow;
export 'src/features/controls/controls_chrome.dart' show ControlAvailability;
export 'src/features/controls/controls_panel.dart' show ControlsPanel;
export 'src/features/launcher/app_launcher_console.dart'
    show AppLauncherConsole;
export 'src/features/network/network_panel.dart' show NetworkPanel;
export 'src/features/power/battery_chip.dart' show BatteryChip;
export 'src/features/power/power_panel.dart' show PowerPanel;
export 'src/features/power/power_profile_pad.dart' show PowerProfilePad;
export 'src/features/session/session_controller.dart' show SessionConfirmChoice;
export 'src/features/session/session_launcher_content.dart'
    show SessionLauncherCard;
export 'src/features/settings/about_settings_panel.dart'
    show AboutSettingsPanel;
export 'src/features/settings/appearance_settings_panel.dart'
    show AppearanceSettingsPanel;
export 'src/features/settings/keybindings/keybinding_controller.dart'
    show KeybindingController, keybindingControllerProvider;
export 'src/features/settings/keybindings/keybindings_panel.dart'
    show KeybindingRow, KeybindingsPanel;
export 'src/features/settings/modules_settings_panel.dart'
    show ModulesSettingsPanel;
export 'src/features/settings/night_light_settings_panel.dart'
    show NightLightSettingsPanel;
export 'src/features/settings/settings_overlay_content.dart'
    show SettingsOverlayContent;
export 'src/features/settings/settings_tab_body.dart'
    show SettingsContentHeader, SettingsTabBody;
export 'src/features/settings/settings_tabs.dart'
    show SettingsSidebar, SettingsTab, SettingsTabButton;
export 'src/features/settings/workspaces_settings_panel.dart'
    show WorkspacesSettingsPanel;
export 'src/features/setup/setup_guide_controls.dart' show SetupGuideControls;
export 'src/features/setup/setup_guide_overlay.dart' show SetupGuideCard;
export 'src/features/setup/setup_guide_preview.dart' show SetupGuidePreview;
export 'src/features/setup/setup_guide_state.dart'
    show SetupLaunch, SetupStep, setupGuideAutomaticHostProvider;
export 'src/features/tray/tray_menu_panel.dart' show TrayMenuPanel;
export 'src/features/tray/tray_strip.dart' show TrayStrip;
export 'src/hyprbaric.dart' show Hyprbaric;
export 'src/state/rust_signals/app.dart' show appStatusProvider;
export 'src/state/rust_signals/appearance.dart' show appearanceStatusProvider;
export 'src/state/rust_signals/audio.dart'
    show audioStatusProvider, brightnessStatusProvider;
export 'src/state/rust_signals/caffeine.dart' show caffeineStatusProvider;
export 'src/state/rust_signals/capabilities.dart' show capabilityStatusProvider;
export 'src/state/rust_signals/clock.dart' show clockStatusProvider;
export 'src/state/rust_signals/compositor.dart'
    show
        focusedWindowStatusProvider,
        portalStatusProvider,
        workspaceStatusProvider;
export 'src/state/rust_signals/modules.dart' show modulesStatusProvider;
export 'src/state/rust_signals/network.dart' show networkStatusProvider;
export 'src/state/rust_signals/night_light.dart' show nightLightStatusProvider;
export 'src/state/rust_signals/notifications.dart'
    show notificationStatusProvider;
export 'src/state/rust_signals/power.dart' show powerStatusProvider;
export 'src/state/rust_signals/recording.dart' show recordingStatusProvider;
export 'src/state/rust_signals/schedule.dart' show scheduleStatusProvider;
export 'src/state/rust_signals/setup.dart' show setupStatusProvider;
export 'src/state/rust_signals/shortcuts.dart'
    show
        shortcutSettingsCommandResultProvider,
        shortcutSettingsSnapshotProvider;
export 'src/state/rust_signals/tray.dart'
    show trayMenuStatusProvider, trayStatusProvider;
export 'src/state/rust_signals/workspace_settings.dart'
    show workspaceSettingsStatusProvider;
export 'src/state/transient_overlays.dart' show OsdEvent, OsdKind, ToastEntry;
export 'src/theme/hypr_palette.dart' show HyprPalette;
export 'src/widgets/center_cluster.dart' show CenterCluster;
export 'src/widgets/hypr_surface.dart';
export 'src/widgets/left_cluster.dart' show LeftCluster;
export 'src/widgets/notification_panel.dart' show NotificationPanel;
export 'src/widgets/notification_panel_parts.dart'
    show
        NotificationCountPill,
        NotificationEmptyState,
        NotificationHeader,
        NotificationList;
export 'src/widgets/notification_row.dart' show NotificationRow;
export 'src/widgets/osd_overlay.dart'
    show
        OsdHeader,
        OsdMeter,
        OsdPanel,
        OsdReadout,
        OsdReadoutView,
        OsdScale,
        OsdSegment;
export 'src/widgets/primitives/hypr_action_row.dart' show HyprActionRow;
export 'src/widgets/primitives/hypr_badge.dart' show HyprBadge;
export 'src/widgets/primitives/hypr_command_button.dart'
    show HyprCommandButton, HyprCommandButtonVariant;
export 'src/widgets/primitives/hypr_empty_state.dart' show HyprEmptyState;
export 'src/widgets/primitives/hypr_glass_frame.dart'
    show HyprGlassFrame, HyprGlassSheen;
export 'src/widgets/primitives/hypr_glyph_badge.dart' show HyprGlyphBadge;
export 'src/widgets/primitives/hypr_hardware_toggle.dart'
    show HyprHardwareToggle;
export 'src/widgets/primitives/hypr_hover_plate.dart' show HyprHoverPlate;
export 'src/widgets/primitives/hypr_inline_tag.dart'
    show HyprBracketedTag, HyprInlineTag;
export 'src/widgets/primitives/hypr_interaction_region.dart'
    show HyprInteractionRegion, HyprInteractionState;
export 'src/widgets/primitives/hypr_interactive_tile.dart'
    show HyprInteractiveTile, HyprInteractiveTileState;
export 'src/widgets/primitives/hypr_live_value.dart' show HyprLiveValue;
export 'src/widgets/primitives/hypr_metric_card.dart' show HyprMetricCard;
export 'src/widgets/primitives/hypr_panel_divider.dart'
    show HyprPanelDivider, HyprSectionBreak;
export 'src/widgets/primitives/hypr_panel_header.dart' show HyprPanelHeader;
export 'src/widgets/primitives/hypr_plate_button.dart' show HyprPlateButton;
export 'src/widgets/primitives/hypr_popover_panel.dart' show HyprPopoverPanel;
export 'src/widgets/primitives/hypr_section_label.dart' show HyprSectionLabel;
export 'src/widgets/primitives/hypr_text_field_chrome.dart'
    show HyprTextFieldChrome;
export 'src/widgets/primitives/hypr_toggle_switch.dart' show HyprToggleSwitch;
export 'src/widgets/right_cluster_buttons.dart'
    show
        AudioDisplayButton,
        BarGlyphIcon,
        BarIconActionButton,
        BarVolumeKnobIcon,
        ClockButton,
        NotificationButton,
        PowerButton;
export 'src/widgets/toast_overlay.dart'
    show ToastAppTag, ToastCornerBrackets, ToastPill;
export 'src/widgets/workspace_strip.dart'
    show
        WorkspaceButton,
        WorkspaceNavButton,
        WorkspaceStrip,
        WorkspaceStripPlaceholder;
