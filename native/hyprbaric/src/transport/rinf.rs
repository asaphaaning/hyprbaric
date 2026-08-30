//! RINF request routing and Rust-to-Dart publication.

use crate::signals::{
    AppLaunchOutcome, AppLaunchRequest, AppLaunchResult, AppLauncherQuery, AppLauncherResults,
    AppStatus, AppearanceCommand, AppearanceCommandResult, AppearanceStatus, AudioCommand,
    AudioCommandResult, AudioStatus, BrightnessCommandResult, BrightnessSetLevel, BrightnessStatus,
    CaffeineCommandResult, CaffeineSetEnabled, CaffeineStatus, CapabilityStatus,
    ClockCalendarRequest, ClockStatus, ColorPickRequest, ColorPickerCommandResult,
    FocusedWindowStatus, HotkeyEvent, ModuleCommand, ModuleCommandResult, ModulesStatus,
    NetworkCommandResult, NetworkConnectRequest, NetworkScanRequest, NetworkSetWifiEnabled,
    NetworkSettingsRequest, NetworkStatus, NightLightCommandResult, NightLightSetEnabled,
    NightLightSetTemperature, NightLightStatus, NotificationClearRequest,
    NotificationDismissRequest, NotificationSetDoNotDisturb, NotificationStatus, PortalStatus,
    PowerCommandResult, PowerSetProfile, PowerStatus, RecordingCommandResult, RecordingRequest,
    RecordingStatus, ScheduleCommand, ScheduleCommandResult, ScheduleStatus,
    ScreenshotCaptureRequest, ScreenshotCommandResult, SessionActionAvailability, SessionCommand,
    SessionCommandResult, SetupCommand, SetupCommandResult, SetupStatus,
    ShortcutSettingsCommandResult,
    ShortcutSettingsRequest, ShortcutSettingsSnapshot, TrayActivateRequest,
    TrayMenuItemActivateRequest, TrayMenuStatus, TrayStatus, WorkspaceSettingsCommand,
    WorkspaceSettingsCommandResult, WorkspaceSettingsStatus, WorkspaceStatus, WorkspaceSwitch,
    WorkspaceSwitchKind,
=======
    MonitorWorkspaceStatus, SessionCommandResult, SetupCommand, SetupCommandResult, SetupStatus,
    ShortcutSettingsCommandResult,
    ShortcutSettingsRequest, ShortcutSettingsSnapshot, TrayActivateRequest,
    TrayMenuItemActivateRequest, TrayMenuStatus, TrayStatus, WorkspaceSettingsCommand,
    WorkspaceSettingsCommandResult, WorkspaceSettingsStatus, WorkspaceStatus, WorkspaceSwitch,
    WorkspaceSwitchKind,
};
use crate::{
    app::{
        App, Command as AppCommand, NetworkCommand as AppNetworkCommand, Outcome, Output,
        WorkspaceCommand as AppWorkspaceCommand,
    },
    hyprland::{self, FocusedWindowSnapshot, WorkspaceSnapshot},
};
use crate::{
    appearance, audio, brightness, caffeine, capabilities, clock, color_picker, launcher, modules,
    network, night_light, notifications, portals, power, recording, schedule, screenshot, session,
    setup, shortcuts, tray, workspaces,
};
use rinf::RustSignal;

use rinf_router::State;

pub(crate) fn send_app_signal() {
    AppStatus {
        version: env!("CARGO_PKG_VERSION").to_owned(),
    }
    .send_signal_to_dart();
}

/// Publishes one typed application output at the RINF boundary.
pub(crate) fn publish(output: &Output) {
    match output {
        Output::Started => send_app_signal(),
        Output::Workspace(snapshot) => send_workspace_signal(snapshot),
        Output::FocusedWindow(snapshot) => send_focused_window_signal(snapshot),
        Output::Appearance(snapshot) => send_appearance_signal(snapshot),
        Output::AppearanceReport(report) => send_appearance_command_result(report),
        Output::Modules(snapshot) => send_modules_signal(snapshot),
        Output::ModulesReport(report) => send_module_command_result(report),
        Output::WorkspaceSettings(snapshot) => send_workspace_settings_signal(snapshot),
        Output::WorkspaceSettingsReport(report) => {
            send_workspace_settings_command_result(report);
        }
        Output::Launcher(results) => send_launcher_signal(results),
        Output::Network(snapshot) => send_network_signal(snapshot),
        Output::NetworkReport(report) => send_network_command_result(report),
        Output::Notifications(snapshot) => send_notification_signal(snapshot),
        Output::Audio(snapshot) => send_audio_signal(snapshot),
        Output::AudioReport(report) => send_audio_command_result(report),
        Output::Brightness(snapshot) => send_brightness_signal(snapshot),
        Output::BrightnessReport(report) => send_brightness_command_result(report),
        Output::Caffeine(snapshot) => send_caffeine_signal(snapshot),
        Output::CaffeineReport(report) => send_caffeine_command_result(report),
        Output::NightLight(snapshot) => send_night_light_signal(snapshot),
        Output::NightLightReport(report) => send_night_light_command_result(report),
        Output::Schedule(snapshot) => send_schedule_signal(snapshot),
        Output::ScheduleReport(report) => send_schedule_command_result(report),
        Output::Power(snapshot) => send_power_signal(snapshot),
        Output::PowerReport(report) => send_power_command_result(report),
        Output::Recording(snapshot) => send_recording_signal(snapshot),
        Output::RecordingReport(report) => send_recording_command_result(report),
        Output::ScreenshotReport(report) => send_screenshot_command_result(report),
        Output::ColorPickerReport(report) => send_color_picker_command_result(report),
        Output::Tray(snapshot) => send_tray_signal(snapshot),
        Output::Clock(snapshot) => send_clock_signal(snapshot),
        Output::Capabilities(snapshot) => send_capability_signal(snapshot),
        Output::SessionAvailability(availability) => {
            send_session_availability_signal(availability);
        }
        Output::Setup(status) => send_setup_signal(*status),
        Output::SetupReport(report) => send_setup_command_result(report),
        Output::Portal(color_scheme) => send_portal_signal(*color_scheme),
        Output::Shortcut(_) => {}
    }
}

pub(crate) fn send_workspace_signal(snapshot: &WorkspaceSnapshot) {
    WorkspaceStatus {
        id: snapshot.id.get(),
        name: snapshot.name.clone(),
        is_special: snapshot.is_special,
        occupied_workspace_ids: snapshot.occupied.ids().map(|id| id.get()).collect(),
=======
        monitors: snapshot
            .monitors
            .iter()
            .map(|monitor| MonitorWorkspaceStatus {
                name: monitor.name.clone(),
                active_workspace_id: monitor.active_workspace.get(),
                is_focused: monitor.is_focused,
                width: monitor.width,
                height: monitor.height,
                refresh_hz: monitor.refresh_hz,
                scale: monitor.scale,
            })
            .collect(),
    }
    .send_signal_to_dart();
}

pub(crate) fn send_focused_window_signal(snapshot: &FocusedWindowSnapshot) {
    FocusedWindowStatus {
        app_name: snapshot.app_name.clone(),
        title: snapshot.title.clone(),
        hostname: snapshot.hostname.clone(),
        monitors: Vec::new(),
    }
    .send_signal_to_dart();
}

pub(crate) async fn handle_workspace_switch(State(context): State<App>, command: WorkspaceSwitch) {
    let command = match command.kind {
        WorkspaceSwitchKind::Relative if command.value == 0 => AppWorkspaceCommand::Refresh,
        WorkspaceSwitchKind::Relative => {
            AppWorkspaceCommand::Switch(hyprland::WorkspaceTarget::relative(command.value))
        }
        WorkspaceSwitchKind::Absolute => {
            let Some(target) = hyprland::WorkspaceTarget::absolute(command.value) else {
                tracing::warn!(target = command.value, "Ignoring invalid workspace target");
                return;
            };
            AppWorkspaceCommand::Switch(target)
        }
    };

    dispatch(&context, AppCommand::Workspace(command)).await;
}

pub(crate) async fn handle_session_command(State(context): State<App>, command: SessionCommand) {
    dispatch(
        &context,
        AppCommand::Session(session::Action::from(command)),
    )
    .await;
}

pub(crate) async fn handle_app_launcher_query(State(context): State<App>, query: AppLauncherQuery) {
    dispatch(&context, AppCommand::LauncherQuery(query.query)).await;
}

pub(crate) async fn handle_app_launch_request(
    State(context): State<App>,
    request: AppLaunchRequest,
) {
    let Some(id) = launcher::Id::new(request.id.clone()) else {
        AppLaunchResult {
            id: request.id,
            outcome: AppLaunchOutcome::Failed,
            message: Some("launcher entry ID cannot be empty".to_owned()),
        }
        .send_signal_to_dart();
        return;
    };
    dispatch(&context, AppCommand::Launch(id)).await;
}

pub(crate) async fn handle_network_scan_request(State(context): State<App>, _: NetworkScanRequest) {
    dispatch(&context, AppCommand::Network(AppNetworkCommand::Scan)).await;
}

pub(crate) async fn handle_network_set_wifi_enabled(
    State(context): State<App>,
    request: NetworkSetWifiEnabled,
) {
    dispatch(
        &context,
        AppCommand::Network(AppNetworkCommand::SetWifiEnabled(request.enabled)),
    )
    .await;
}

pub(crate) async fn handle_network_connect_request(
    State(context): State<App>,
    request: NetworkConnectRequest,
) {
    dispatch(
        &context,
        AppCommand::Network(AppNetworkCommand::Connect {
            ssid: request.ssid,
            bssid: request.bssid,
            password: request.password,
        }),
    )
    .await;
}

pub(crate) async fn handle_network_settings_request(
    State(context): State<App>,
    _: NetworkSettingsRequest,
) {
    dispatch(
        &context,
        AppCommand::Network(AppNetworkCommand::OpenSettings),
    )
    .await;
}

pub(crate) async fn handle_audio_command(State(context): State<App>, command: AudioCommand) {
    let command = match command {
        AudioCommand::SetVolume { kind, volume } => audio::Command::SetVolume {
            kind: audio::Kind::from(kind),
            volume: audio::Percent::new(volume),
        },
        AudioCommand::SetMuted { kind, muted } => audio::Command::SetMuted {
            kind: audio::Kind::from(kind),
            muted,
        },
    };

    dispatch(&context, AppCommand::Audio(command)).await;
}

pub(crate) async fn handle_setup_command(State(context): State<App>, command: SetupCommand) {
    dispatch(&context, AppCommand::Setup(command.into())).await;
}

pub(crate) async fn handle_appearance_command(
    State(context): State<App>,
    request: AppearanceCommand,
) {
    match appearance::Command::try_from(request) {
        Ok(command) => {
            dispatch(&context, AppCommand::Appearance(command)).await;
        }
        Err(error) => {
            let command = appearance::Command::SetOpacity {
                opacity: appearance::Opacity::default(),
            };
            send_appearance_command_result(&appearance::Report::Failed {
                command,
                message: error.to_string(),
            });
        }
    }
}

pub(crate) async fn handle_module_command(State(context): State<App>, request: ModuleCommand) {
    dispatch(
        &context,
        AppCommand::Modules(modules::Command::from(request)),
    )
    .await;
}

pub(crate) async fn handle_workspace_settings_command(
    State(context): State<App>,
    request: WorkspaceSettingsCommand,
) {
    dispatch(
        &context,
        AppCommand::WorkspaceSettings(workspaces::Command::from(request)),
    )
    .await;
}

pub(crate) async fn handle_brightness_set_level(
    State(context): State<App>,
    request: BrightnessSetLevel,
) {
    dispatch(
        &context,
        AppCommand::Brightness(brightness::Command::SetLevel {
            value: brightness::Percent::new(request.value),
        }),
    )
    .await;
}

pub(crate) async fn handle_caffeine_set_enabled(
    State(context): State<App>,
    request: CaffeineSetEnabled,
) {
    dispatch(
        &context,
        AppCommand::Caffeine(caffeine::Command::SetEnabled {
            enabled: request.enabled,
        }),
    )
    .await;
}

pub(crate) async fn handle_night_light_set_enabled(
    State(context): State<App>,
    request: NightLightSetEnabled,
) {
    dispatch(
        &context,
        AppCommand::NightLight(night_light::Command::SetEnabled {
            enabled: request.enabled,
        }),
    )
    .await;
}

pub(crate) async fn handle_night_light_set_temperature(
    State(context): State<App>,
    request: NightLightSetTemperature,
) {
    match night_light::Command::try_from(request) {
        Ok(command @ night_light::Command::SetTemperature { .. }) => {
            dispatch(&context, AppCommand::NightLight(command)).await;
        }
        Ok(command @ night_light::Command::SetEnabled { .. }) => {
            dispatch(&context, AppCommand::NightLight(command)).await;
        }
        Err(error) => {
            let command = night_light::Command::SetTemperature {
                temperature: night_light::Temperature::default(),
            };
            send_night_light_command_result(&night_light::Report::Failed {
                command,
                message: error.to_string(),
            });
        }
    }
}

pub(crate) async fn handle_schedule_command(State(context): State<App>, request: ScheduleCommand) {
    match schedule::Command::try_from(request) {
        Ok(command) => dispatch(&context, AppCommand::Schedule(command)).await,
        Err(error) => {
            let command = schedule::Command::SetDailyWindow {
                action: schedule::Action::NightLight,
                window: schedule::DailyWindow::default(),
            };
            send_schedule_command_result(&schedule::Report::Failed {
                command,
                message: error.to_string(),
            });
        }
    }
}

pub(crate) async fn handle_power_set_profile(State(context): State<App>, request: PowerSetProfile) {
    dispatch(
        &context,
        AppCommand::Power(power::Command::SetProfile {
            profile: power::Profile::from(request.profile),
        }),
    )
    .await;
}

pub(crate) async fn handle_screenshot_capture_request(
    State(context): State<App>,
    request: ScreenshotCaptureRequest,
) {
    dispatch(
        &context,
        AppCommand::Screenshot(screenshot::Command::Capture(screenshot::Mode::from(
            request.mode,
        ))),
    )
    .await;
}

pub(crate) async fn handle_color_pick_request(State(context): State<App>, _: ColorPickRequest) {
    dispatch(
        &context,
        AppCommand::ColorPicker(color_picker::Command::Pick),
    )
    .await;
}

pub(crate) async fn handle_recording_request(
    State(context): State<App>,
    request: RecordingRequest,
) {
    dispatch(
        &context,
        AppCommand::Recording(recording::Command::from(request)),
    )
    .await;
}

pub(crate) async fn handle_tray_activate_request(
    State(context): State<App>,
    request: TrayActivateRequest,
) {
    dispatch(&context, AppCommand::Tray(tray::Activation::from(request))).await;
}

pub(crate) async fn handle_tray_menu_item_activate_request(
    State(context): State<App>,
    request: TrayMenuItemActivateRequest,
) {
    dispatch(
        &context,
        AppCommand::TrayMenu(tray::MenuActivation::from(request)),
    )
    .await;
}

pub(crate) async fn handle_notification_dismiss_request(
    State(context): State<App>,
    request: NotificationDismissRequest,
) {
    dispatch(
        &context,
        AppCommand::Notifications(notifications::Command::from(request)),
    )
    .await;
}

pub(crate) async fn handle_notification_clear_request(
    State(context): State<App>,
    request: NotificationClearRequest,
) {
    dispatch(
        &context,
        AppCommand::Notifications(notifications::Command::from(request)),
    )
    .await;
}

pub(crate) async fn handle_notification_dnd_request(
    State(context): State<App>,
    request: NotificationSetDoNotDisturb,
) {
    dispatch(
        &context,
        AppCommand::Notifications(notifications::Command::from(request)),
    )
    .await;
}

pub(crate) async fn handle_clock_calendar_request(
    State(context): State<App>,
    request: ClockCalendarRequest,
) {
    dispatch(&context, AppCommand::Clock(clock::Command::from(request))).await;
}

pub(crate) async fn handle_shortcut_settings_request(
    State(context): State<App>,
    request: ShortcutSettingsRequest,
) {
    let command = match shortcuts::SettingsCommand::try_from(request) {
        Ok(command) => command,
        Err(error) => {
            let command = shortcuts::SettingsCommand::Load;
            send_shortcut_settings_result(&shortcuts::SettingsReport::failed(command, error));
            return;
        }
    };

    send_shortcut_settings_result(&shortcuts::SettingsReport::started(command.clone()));

    if matches!(command, shortcuts::SettingsCommand::Load) {
        match shortcuts::settings::load() {
            Ok(snapshot) => {
                send_shortcut_settings_snapshot(&snapshot);
                send_shortcut_settings_result(&shortcuts::SettingsReport::saved(command));
            }
            Err(error) => {
                send_shortcut_settings_result(&shortcuts::SettingsReport::failed(command, error));
            }
        }
        return;
    }

    match shortcuts::settings::save(&command) {
        Ok(config) => {
            // Persisted settings should reach the UI even if live compositor
            // reconciliation later fails on a shared Hyprland chord.
            match shortcuts::settings::snapshot(&config) {
                Ok(snapshot) => send_shortcut_settings_snapshot(&snapshot),
                Err(error) => tracing::warn!("Failed to publish shortcut settings: {error}"),
            }
            if let Err(error) = context.shortcuts().sync(config.shortcuts.specs()).await {
                send_shortcut_settings_result(&shortcuts::SettingsReport::failed(command, error));
                return;
            }
            send_shortcut_settings_result(&shortcuts::SettingsReport::saved(command));
        }
        Err(error) => {
            send_shortcut_settings_result(&shortcuts::SettingsReport::failed(command, error));
        }
    }
}

pub(crate) fn send_session_availability_signal(availability: &session::Availability) {
    SessionActionAvailability::from(availability).send_signal_to_dart();
}

async fn dispatch(app: &App, command: AppCommand) {
    match app.dispatch(command).await {
        Outcome::None => {}
        Outcome::Outputs(outputs) => {
            for output in outputs {
                publish(&output);
            }
        }
        Outcome::Session(report) => {
            SessionCommandResult::from(&report).send_signal_to_dart();
        }
        Outcome::Launch { id, error } => {
            AppLaunchResult {
                id: id.to_string(),
                outcome: if error.is_some() {
                    AppLaunchOutcome::Failed
                } else {
                    AppLaunchOutcome::Started
                },
                message: error,
            }
            .send_signal_to_dart();
        }
        Outcome::TrayMenu(Some(menu)) => send_tray_menu_signal(&menu),
        Outcome::TrayMenu(None) => {}
    }
}

#[tracing::instrument(skip(context), fields(shortcut_id = %shortcut))]
pub(crate) async fn activate_shortcut(context: App, shortcut: shortcuts::Shortcut) {
    use shortcuts::{Action, UiAction};

    match shortcut.action() {
        Action::Ui(action) => {
            let volume_step = context.audio_volume_step().as_u8();
            match action {
                UiAction::ToggleAppLauncher => HotkeyEvent::ToggleAppLauncher {},
                UiAction::ToggleControls => HotkeyEvent::ToggleControls {},
                UiAction::OpenBarSettings => HotkeyEvent::OpenBarSettings {},
                UiAction::ToggleSessionLauncher => HotkeyEvent::ToggleSessionLauncher {},
                UiAction::VolumeUp => HotkeyEvent::VolumeUp { step: volume_step },
                UiAction::VolumeDown => HotkeyEvent::VolumeDown { step: volume_step },
                UiAction::ToggleMute => HotkeyEvent::ToggleMute {},
                UiAction::BrightnessUp => HotkeyEvent::BrightnessUp {},
                UiAction::BrightnessDown => HotkeyEvent::BrightnessDown {},
                UiAction::ColorPick => HotkeyEvent::ColorPick {},
                UiAction::ToggleRecording => HotkeyEvent::ToggleRecording {},
                UiAction::ToggleDoNotDisturb => HotkeyEvent::ToggleDoNotDisturb {},
                UiAction::ToggleNightLight => HotkeyEvent::ToggleNightLight {},
                UiAction::ToggleCaffeine => HotkeyEvent::ToggleCaffeine {},
            }
            .send_signal_to_dart();
        }
        Action::Session(action) => dispatch(&context, AppCommand::Session(action)).await,
        Action::Screenshot(mode) => {
            dispatch(
                &context,
                AppCommand::Screenshot(screenshot::Command::Capture(mode)),
            )
            .await;
        }
    }
}

pub(crate) fn send_launcher_signal(results: &launcher::Results) {
    AppLauncherResults::from(results).send_signal_to_dart();
}

pub(crate) fn send_network_signal(snapshot: &network::Snapshot) {
    NetworkStatus::from(snapshot).send_signal_to_dart();
}

pub(crate) fn send_network_command_result(result: &network::Report) {
    NetworkCommandResult::from(result).send_signal_to_dart();
}

pub(crate) fn send_appearance_signal(snapshot: &appearance::Snapshot) {
    AppearanceStatus::from(snapshot).send_signal_to_dart();
}

pub(crate) fn send_setup_signal(status: setup::Status) {
    SetupStatus {
        state: status.into(),
    }
    .send_signal_to_dart();
}

pub(crate) fn send_setup_command_result(result: &setup::Report) {
    SetupCommandResult::from(result).send_signal_to_dart();
}

pub(crate) fn send_appearance_command_result(result: &appearance::Report) {
    AppearanceCommandResult::from(result).send_signal_to_dart();
}

pub(crate) fn send_modules_signal(snapshot: &modules::Snapshot) {
    ModulesStatus::from(snapshot).send_signal_to_dart();
}

pub(crate) fn send_module_command_result(result: &modules::Report) {
    ModuleCommandResult::from(result).send_signal_to_dart();
}

pub(crate) fn send_workspace_settings_signal(snapshot: &workspaces::Snapshot) {
    WorkspaceSettingsStatus::from(snapshot).send_signal_to_dart();
}

pub(crate) fn send_workspace_settings_command_result(result: &workspaces::Report) {
    WorkspaceSettingsCommandResult::from(result).send_signal_to_dart();
}

pub(crate) fn send_audio_signal(snapshot: &audio::Snapshot) {
    AudioStatus::from(snapshot).send_signal_to_dart();
}

pub(crate) fn send_audio_command_result(result: &audio::Report) {
    AudioCommandResult::from(result).send_signal_to_dart();
}

pub(crate) fn send_brightness_signal(snapshot: &brightness::Snapshot) {
    BrightnessStatus::from(snapshot).send_signal_to_dart();
}

pub(crate) fn send_brightness_command_result(result: &brightness::Report) {
    BrightnessCommandResult::from(result).send_signal_to_dart();
}

pub(crate) fn send_caffeine_signal(snapshot: &caffeine::Snapshot) {
    CaffeineStatus::from(snapshot).send_signal_to_dart();
}

pub(crate) fn send_caffeine_command_result(result: &caffeine::Report) {
    CaffeineCommandResult::from(result).send_signal_to_dart();
}

pub(crate) fn send_night_light_signal(snapshot: &night_light::Snapshot) {
    NightLightStatus::from(snapshot).send_signal_to_dart();
}

pub(crate) fn send_night_light_command_result(result: &night_light::Report) {
    NightLightCommandResult::from(result).send_signal_to_dart();
}

pub(crate) fn send_schedule_signal(snapshot: &schedule::Snapshot) {
    ScheduleStatus::from(snapshot).send_signal_to_dart();
}

pub(crate) fn send_schedule_command_result(result: &schedule::Report) {
    ScheduleCommandResult::from(result).send_signal_to_dart();
}

pub(crate) fn send_power_signal(snapshot: &power::Snapshot) {
    PowerStatus::from(snapshot).send_signal_to_dart();
}

pub(crate) fn send_power_command_result(result: &power::Report) {
    PowerCommandResult::from(result).send_signal_to_dart();
}

pub(crate) fn send_recording_signal(snapshot: &recording::Snapshot) {
    RecordingStatus::from(snapshot).send_signal_to_dart();
}

pub(crate) fn send_recording_command_result(result: &recording::Report) {
    RecordingCommandResult::from(result).send_signal_to_dart();
}

pub(crate) fn send_screenshot_command_result(result: &screenshot::Report) {
    ScreenshotCommandResult::from(result).send_signal_to_dart();
}

pub(crate) fn send_color_picker_command_result(result: &color_picker::Report) {
    ColorPickerCommandResult::from(result).send_signal_to_dart();
}

pub(crate) fn send_tray_signal(snapshot: &tray::Snapshot) {
    TrayStatus::from(snapshot).send_signal_to_dart();
}

pub(crate) fn send_tray_menu_signal(menu: &tray::Menu) {
    TrayMenuStatus::from(menu).send_signal_to_dart();
}

pub(crate) fn send_notification_signal(snapshot: &notifications::Snapshot) {
    NotificationStatus::from(snapshot).send_signal_to_dart();
}

pub(crate) fn send_clock_signal(snapshot: &clock::Snapshot) {
    ClockStatus::from(snapshot).send_signal_to_dart();
}

pub(crate) fn send_capability_signal(snapshot: &capabilities::Snapshot) {
    CapabilityStatus::from(snapshot).send_signal_to_dart();
}

pub(crate) fn send_shortcut_settings_snapshot(snapshot: &shortcuts::SettingsSnapshot) {
    ShortcutSettingsSnapshot::from(snapshot).send_signal_to_dart();
}

pub(crate) fn send_shortcut_settings_result(result: &shortcuts::SettingsReport) {
    ShortcutSettingsCommandResult::from(result).send_signal_to_dart();
}

pub(crate) fn send_portal_signal(color_scheme: portals::ColorScheme) {
    PortalStatus {
        color_scheme: color_scheme.into(),
    }
    .send_signal_to_dart();
}
