//! Typed application output and live subscriptions.
//!
//! Feature runtimes publish their own snapshots and reports. [`Output`] is the
//! closed application vocabulary that joins those streams before the RINF
//! transport projects them into generated wire signals.

use std::{collections::VecDeque, future};

use tokio::sync::broadcast;

use crate::{
    appearance, audio, brightness, caffeine, capabilities, clock, color_picker, hyprland, launcher,
    modules, network, night_light, notifications, portals, power, recording, schedule, screenshot,
    session, setup, shortcuts, tray, workspaces,
};

/// An application value ready for state reduction or transport publication.
#[derive(Clone, Debug)]
pub enum Output {
    /// The native backend started.
    Started,
    /// Workspace and focused-window state observed together.
    Desktop(hyprland::DesktopSnapshot),
    /// Appearance state changed.
    Appearance(appearance::Snapshot),
    /// An appearance command completed.
    AppearanceReport(appearance::Report),
    /// Module visibility state changed.
    Modules(modules::Snapshot),
    /// A module visibility command completed.
    ModulesReport(modules::Report),
    /// Workspace presentation settings changed.
    WorkspaceSettings(workspaces::Snapshot),
    /// A workspace settings command completed.
    WorkspaceSettingsReport(workspaces::Report),
    /// Application launcher results changed.
    Launcher(launcher::Results),
    /// Network state changed.
    Network(network::Snapshot),
    /// A network command completed.
    NetworkReport(network::Report),
    /// Notification state changed.
    Notifications(notifications::Snapshot),
    /// Audio state changed.
    Audio(audio::Snapshot),
    /// An audio command completed.
    AudioReport(audio::Report),
    /// Brightness state changed.
    Brightness(brightness::Snapshot),
    /// A brightness command completed.
    BrightnessReport(brightness::Report),
    /// Caffeine state changed.
    Caffeine(caffeine::Snapshot),
    /// A Caffeine command completed.
    CaffeineReport(caffeine::Report),
    /// Night-light state changed.
    NightLight(night_light::Snapshot),
    /// A night-light command completed.
    NightLightReport(night_light::Report),
    /// Schedule state changed.
    Schedule(schedule::Snapshot),
    /// A schedule command completed.
    ScheduleReport(schedule::Report),
    /// Power state changed.
    Power(power::Snapshot),
    /// A power command completed.
    PowerReport(power::Report),
    /// Recording state changed.
    Recording(recording::Snapshot),
    /// A recording command completed.
    RecordingReport(recording::Report),
    /// A screenshot command completed.
    ScreenshotReport(screenshot::Report),
    /// A color-picker command completed.
    ColorPickerReport(color_picker::Report),
    /// System tray state changed.
    Tray(tray::Snapshot),
    /// Clock state changed.
    Clock(clock::Snapshot),
    /// Host capability diagnostics were read.
    Capabilities(capabilities::Snapshot),
    /// Optional desktop-session actions were detected.
    SessionAvailability(session::Availability),
    /// First-run setup state changed.
    Setup(setup::Status),
    /// A setup command completed.
    SetupReport(setup::Report),
    /// The desktop portal color preference was read.
    Portal(portals::ColorScheme),
    /// A global shortcut was activated.
    Shortcut(shortcuts::Event),
}

/// Live feature subscriptions merged into the application output protocol.
///
/// This type owns every receiver, so supervision needs only one long-lived
/// output service instead of one service per feature stream.
pub struct Subscriptions {
    pub(crate) replay: VecDeque<Output>,
    pub(crate) desktop: broadcast::Receiver<hyprland::DesktopSnapshot>,
    pub(crate) appearance: broadcast::Receiver<appearance::Snapshot>,
    pub(crate) appearance_reports: broadcast::Receiver<appearance::Report>,
    pub(crate) modules: broadcast::Receiver<modules::Snapshot>,
    pub(crate) module_reports: broadcast::Receiver<modules::Report>,
    pub(crate) workspace_settings: broadcast::Receiver<workspaces::Snapshot>,
    pub(crate) workspace_settings_reports: broadcast::Receiver<workspaces::Report>,
    pub(crate) launcher: broadcast::Receiver<launcher::Results>,
    pub(crate) network: broadcast::Receiver<network::Snapshot>,
    pub(crate) network_reports: broadcast::Receiver<network::Report>,
    pub(crate) notifications: broadcast::Receiver<notifications::Snapshot>,
    pub(crate) audio: broadcast::Receiver<audio::Snapshot>,
    pub(crate) audio_reports: broadcast::Receiver<audio::Report>,
    pub(crate) brightness: broadcast::Receiver<brightness::Snapshot>,
    pub(crate) brightness_reports: broadcast::Receiver<brightness::Report>,
    pub(crate) caffeine: broadcast::Receiver<caffeine::Snapshot>,
    pub(crate) caffeine_reports: broadcast::Receiver<caffeine::Report>,
    pub(crate) night_light: broadcast::Receiver<night_light::Snapshot>,
    pub(crate) night_light_reports: broadcast::Receiver<night_light::Report>,
    pub(crate) schedule: broadcast::Receiver<schedule::Snapshot>,
    pub(crate) schedule_reports: broadcast::Receiver<schedule::Report>,
    pub(crate) power: broadcast::Receiver<power::Snapshot>,
    pub(crate) power_reports: broadcast::Receiver<power::Report>,
    pub(crate) recording: broadcast::Receiver<recording::Snapshot>,
    pub(crate) recording_reports: broadcast::Receiver<recording::Report>,
    pub(crate) screenshot_reports: broadcast::Receiver<screenshot::Report>,
    pub(crate) color_picker_reports: broadcast::Receiver<color_picker::Report>,
    pub(crate) tray: broadcast::Receiver<tray::Snapshot>,
    pub(crate) clock: broadcast::Receiver<clock::Snapshot>,
    pub(crate) setup: broadcast::Receiver<setup::Status>,
    pub(crate) setup_reports: broadcast::Receiver<setup::Report>,
    pub(crate) shortcuts: broadcast::Receiver<shortcuts::Event>,
}

impl Subscriptions {
    /// Waits for the next value from any live feature subscription.
    pub async fn next(&mut self) -> Output {
        if let Some(output) = self.replay.pop_front() {
            return output;
        }

        tokio::select! {
            value = receive(&mut self.desktop, "desktop") => Output::Desktop(value),
            value = receive(&mut self.appearance, "appearance") => Output::Appearance(value),
            value = receive(&mut self.appearance_reports, "appearance-report") => {
                Output::AppearanceReport(value)
            }
            value = receive(&mut self.modules, "modules") => Output::Modules(value),
            value = receive(&mut self.module_reports, "module-report") => {
                Output::ModulesReport(value)
            }
            value = receive(&mut self.workspace_settings, "workspace-settings") => {
                Output::WorkspaceSettings(value)
            }
            value = receive(
                &mut self.workspace_settings_reports,
                "workspace-settings-report",
            ) => Output::WorkspaceSettingsReport(value),
            value = receive(&mut self.launcher, "launcher") => Output::Launcher(value),
            value = receive(&mut self.network, "network") => Output::Network(value),
            value = receive(&mut self.network_reports, "network-report") => {
                Output::NetworkReport(value)
            }
            value = receive(&mut self.notifications, "notifications") => {
                Output::Notifications(value)
            }
            value = receive(&mut self.audio, "audio") => Output::Audio(value),
            value = receive(&mut self.audio_reports, "audio-report") => {
                Output::AudioReport(value)
            }
            value = receive(&mut self.brightness, "brightness") => Output::Brightness(value),
            value = receive(&mut self.brightness_reports, "brightness-report") => {
                Output::BrightnessReport(value)
            }
            value = receive(&mut self.caffeine, "caffeine") => Output::Caffeine(value),
            value = receive(&mut self.caffeine_reports, "caffeine-report") => {
                Output::CaffeineReport(value)
            }
            value = receive(&mut self.night_light, "night-light") => Output::NightLight(value),
            value = receive(&mut self.night_light_reports, "night-light-report") => {
                Output::NightLightReport(value)
            }
            value = receive(&mut self.schedule, "schedule") => Output::Schedule(value),
            value = receive(&mut self.schedule_reports, "schedule-report") => {
                Output::ScheduleReport(value)
            }
            value = receive(&mut self.power, "power") => Output::Power(value),
            value = receive(&mut self.power_reports, "power-report") => {
                Output::PowerReport(value)
            }
            value = receive(&mut self.recording, "recording") => Output::Recording(value),
            value = receive(&mut self.recording_reports, "recording-report") => {
                Output::RecordingReport(value)
            }
            value = receive(&mut self.screenshot_reports, "screenshot-report") => {
                Output::ScreenshotReport(value)
            }
            value = receive(&mut self.color_picker_reports, "color-picker-report") => {
                Output::ColorPickerReport(value)
            }
            value = receive(&mut self.tray, "tray") => Output::Tray(value),
            value = receive(&mut self.clock, "clock") => Output::Clock(value),
            value = receive(&mut self.setup, "setup") => Output::Setup(value),
            value = receive(&mut self.setup_reports, "setup-report") => {
                Output::SetupReport(value)
            }
            value = receive(&mut self.shortcuts, "shortcuts") => Output::Shortcut(value),
        }
    }
}

async fn receive<T>(receiver: &mut broadcast::Receiver<T>, source: &'static str) -> T
where
    T: Clone,
{
    loop {
        match receiver.recv().await {
            Ok(value) => return value,
            Err(broadcast::error::RecvError::Lagged(skipped)) => {
                tracing::warn!(source, skipped, "Application subscription lagged");
            }
            Err(broadcast::error::RecvError::Closed) => {
                tracing::debug!(source, "Application subscription closed");
                future::pending().await
            }
        }
    }
}
