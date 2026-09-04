//! Native application bootstrap and component assembly.

use std::{
    sync::Arc,
    time::{Duration, Instant},
};

use tracing::instrument;

use crate::{
    appearance, audio, brightness, caffeine, capabilities, clock, color_picker, config, hyprland,
    launcher, modules, network, night_light, notifications, portals, power, recording, schedule,
    screenshot, session, setup, shortcuts, tray, workspaces,
};
use crate::{
    appearance::Snapshot as AppearanceSnapshot,
    audio::Snapshot as AudioSnapshot,
    brightness::Snapshot as BrightnessSnapshot,
    caffeine::Snapshot as CaffeineSnapshot,
    capabilities::Snapshot as CapabilitySnapshot,
    clock::Snapshot as ClockSnapshot,
    hyprland::{Desktop, DesktopSnapshot},
    launcher::Results as LauncherResults,
    modules::Snapshot as ModulesSnapshot,
    network::Snapshot as NetworkSnapshot,
    night_light::Snapshot as NightLightSnapshot,
    notifications::Snapshot as NotificationSnapshot,
    portals::ColorScheme,
    power::Snapshot as PowerSnapshot,
    recording::Snapshot as RecordingSnapshot,
    schedule::Snapshot as ScheduleSnapshot,
    screenshot::Handle as ScreenshotHandle,
    setup::Status as SetupStatus,
    tray::Snapshot as TraySnapshot,
    workspaces::Snapshot as WorkspaceSettingsSnapshot,
};

const SLOW_BOOTSTRAP_PHASE: Duration = Duration::from_millis(250);

/// Private live components owned by [`crate::app::App`].
#[derive(Clone)]
pub(crate) struct Components {
    appearance: appearance::Handle,
    hyprland: Arc<Desktop>,
    audio: audio::Handle,
    brightness: brightness::Handle,
    caffeine: caffeine::Handle,
    clock: clock::Handle,
    color_picker: color_picker::Handle,
    launcher: launcher::Handle,
    modules: modules::Handle,
    workspaces: workspaces::Handle,
    network: network::Handle,
    night_light: night_light::Handle,
    notifications: notifications::Handle,
    power: power::Handle,
    recording: recording::Handle,
    schedule: schedule::Handle,
    screenshots: ScreenshotHandle,
    tray: tray::Handle,
    portal: Option<Arc<portals::Settings>>,
    session: session::Handle,
    shortcuts: shortcuts::Handle,
    setup: setup::Handle,
}

/// A fully bootstrapped application and its coherent initial UI projection.
pub struct Started {
    /// Running application state and feature handles.
    pub app: crate::app::App,
    /// Initial application outputs collected during bootstrap.
    pub initial: Initial,
}

/// Initial values published before live subscriptions begin.
pub struct Initial {
    desktop: DesktopSnapshot,
    appearance: AppearanceSnapshot,
    modules: ModulesSnapshot,
    workspace_settings: WorkspaceSettingsSnapshot,
    launcher: LauncherResults,
    network: NetworkSnapshot,
    notifications: NotificationSnapshot,
    audio: AudioSnapshot,
    brightness: BrightnessSnapshot,
    caffeine: CaffeineSnapshot,
    night_light: NightLightSnapshot,
    schedule: ScheduleSnapshot,
    power: PowerSnapshot,
    recording: RecordingSnapshot,
    tray: TraySnapshot,
    clock: ClockSnapshot,
    capabilities: CapabilitySnapshot,
    session_availability: session::Availability,
    setup: SetupStatus,
    color_scheme: Option<ColorScheme>,
}

impl Initial {
    /// Returns the initial portal color preference.
    pub const fn color_scheme(&self) -> Option<ColorScheme> {
        self.color_scheme
    }

    /// Converts bootstrap values into the application output protocol.
    pub fn into_outputs(self) -> Vec<crate::app::Output> {
        use crate::app::Output;

        let mut outputs = vec![
            Output::Started,
            Output::Desktop(self.desktop),
            Output::Appearance(self.appearance),
            Output::Modules(self.modules),
            Output::WorkspaceSettings(self.workspace_settings),
            Output::Launcher(self.launcher),
            Output::Network(self.network),
            Output::Notifications(self.notifications),
            Output::Audio(self.audio),
            Output::Brightness(self.brightness),
            Output::Caffeine(self.caffeine),
            Output::NightLight(self.night_light),
            Output::Schedule(self.schedule),
            Output::Power(self.power),
            Output::Recording(self.recording),
            Output::Tray(self.tray),
            Output::Clock(self.clock),
            Output::Capabilities(self.capabilities),
            Output::SessionAvailability(self.session_availability),
            Output::Setup(self.setup),
        ];

        if let Some(color_scheme) = self.color_scheme {
            outputs.push(Output::Portal(color_scheme));
        }

        outputs
    }
}

impl Components {
    async fn boot(config: &config::Configuration) -> Result<(Self, Initial), Error> {
        let bootstrap_started = Instant::now();
        let phase_started = Instant::now();
        let (hyprland, initial_desktop) = Desktop::connect().await?;
        log_bootstrap_phase("hyprland", phase_started.elapsed());
        let phase_started = Instant::now();
        let (appearance, initial_appearance) =
            appearance::Appearance::bootstrap(&config.appearance);
        log_bootstrap_phase("appearance", phase_started.elapsed());
        let phase_started = Instant::now();
        let (modules, initial_modules) = modules::Modules::bootstrap(&config.modules);
        log_bootstrap_phase("modules", phase_started.elapsed());
        let phase_started = Instant::now();
        let (workspaces, initial_workspace_settings) =
            workspaces::Workspaces::bootstrap(&config.workspaces);
        log_bootstrap_phase("workspace-settings", phase_started.elapsed());
        let phase_started = Instant::now();
        let (launcher, initial_launcher) = launcher::Launcher::bootstrap().await;
        log_bootstrap_phase("launcher", phase_started.elapsed());
        let phase_started = Instant::now();
        let (network, initial_network) = network::Wifi::bootstrap(&config.network).await;
        log_bootstrap_phase("network", phase_started.elapsed());
        let phase_started = Instant::now();
        let (notifications, initial_notifications) = notifications::Center::bootstrap().await;
        log_bootstrap_phase("notifications", phase_started.elapsed());
        let phase_started = Instant::now();
        let (audio, initial_audio) = audio::Control::bootstrap().await;
        log_bootstrap_phase("audio", phase_started.elapsed());
        let phase_started = Instant::now();
        let (brightness, initial_brightness) =
            brightness::Brightness::bootstrap(&config.brightness).await;
        log_bootstrap_phase("brightness", phase_started.elapsed());
        let phase_started = Instant::now();
        let (caffeine, initial_caffeine) = caffeine::Caffeine::bootstrap().await;
        log_bootstrap_phase("caffeine", phase_started.elapsed());
        let phase_started = Instant::now();
        let color_picker = color_picker::Picker::new();
        log_bootstrap_phase("color-picker", phase_started.elapsed());
        let phase_started = Instant::now();
        let (night_light, _) = night_light::NightLight::bootstrap(&config.night_light).await;
        log_bootstrap_phase("night-light", phase_started.elapsed());
        let phase_started = Instant::now();
        let (schedule, initial_schedule) =
            schedule::Scheduler::bootstrap(&config.schedules, night_light.clone()).await;
        log_bootstrap_phase("schedule", phase_started.elapsed());
        let phase_started = Instant::now();
        let initial_night_light = night_light.snapshot().await;
        log_bootstrap_phase("night-light-snapshot", phase_started.elapsed());
        let phase_started = Instant::now();
        let (power, initial_power) = power::Power::bootstrap(&config.power).await;
        log_bootstrap_phase("power", phase_started.elapsed());
        let phase_started = Instant::now();
        let (recording, initial_recording) = recording::Recorder::bootstrap().await;
        log_bootstrap_phase("recording", phase_started.elapsed());
        let phase_started = Instant::now();
        let (tray, initial_tray) = tray::Tray::bootstrap().await;
        log_bootstrap_phase("tray", phase_started.elapsed());
        let phase_started = Instant::now();
        let (clock, initial_clock) = clock::Clock::bootstrap();
        log_bootstrap_phase("clock", phase_started.elapsed());
        let phase_started = Instant::now();
        let (setup, initial_setup) = setup::Guide::bootstrap(&config.setup);
        log_bootstrap_phase("setup", phase_started.elapsed());
        let phase_started = Instant::now();
        let initial_capabilities = capabilities::Snapshot::read();
        log_bootstrap_phase("capabilities", phase_started.elapsed());
        let phase_started = Instant::now();
        let screenshots = screenshot::Screenshots::new();
        log_bootstrap_phase("screenshots", phase_started.elapsed());
        let phase_started = Instant::now();
        let session = Arc::new(session::Actions::detect().await);
        log_bootstrap_phase("session", phase_started.elapsed());
        let phase_started = Instant::now();
        let (portal, initial_scheme) = match portals::Settings::read().await {
            Ok(settings) => {
                let color_scheme = settings.color_scheme();
                (Some(Arc::new(settings)), Some(color_scheme))
            }
            Err(error) => {
                tracing::warn!("Portal bootstrap failed: {error}");
                (None, None)
            }
        };
        log_bootstrap_phase("portal-settings", phase_started.elapsed());
        let phase_started = Instant::now();
        let shortcuts = Arc::new(shortcuts::Registry::new());
        log_bootstrap_phase("shortcuts", phase_started.elapsed());
        tracing::info!(
            elapsed_ms = bootstrap_started.elapsed().as_millis(),
            "Native runtime bootstrap completed"
        );

        let session_availability = session.availability().clone();

        Ok((
            Self {
                appearance,
                hyprland: Arc::new(hyprland),
                audio,
                brightness,
                caffeine,
                clock,
                color_picker,
                launcher,
                modules,
                workspaces,
                network,
                night_light,
                notifications,
                power,
                recording,
                schedule,
                screenshots,
                tray,
                portal,
                session,
                shortcuts,
                setup,
            },
            Initial {
                desktop: initial_desktop,
                appearance: initial_appearance,
                modules: initial_modules,
                workspace_settings: initial_workspace_settings,
                launcher: initial_launcher,
                network: initial_network,
                notifications: initial_notifications,
                audio: initial_audio,
                brightness: initial_brightness,
                caffeine: initial_caffeine,
                night_light: initial_night_light,
                schedule: initial_schedule,
                power: initial_power,
                recording: initial_recording,
                tray: initial_tray,
                clock: initial_clock,
                capabilities: initial_capabilities,
                session_availability,
                setup: initial_setup,
                color_scheme: initial_scheme,
            },
        ))
    }

    /// Subscribes to the complete typed application output protocol.
    pub fn subscriptions(&self) -> crate::app::Subscriptions {
        let tray = self.tray.subscribe();
        let tray_snapshot = self.tray.snapshot();

        crate::app::Subscriptions {
            replay: std::collections::VecDeque::from([crate::app::Output::Tray(tray_snapshot)]),
            desktop: self.hyprland.subscribe(),
            appearance: self.appearance.subscribe(),
            appearance_reports: self.appearance.subscribe_results(),
            modules: self.modules.subscribe(),
            module_reports: self.modules.subscribe_results(),
            workspace_settings: self.workspaces.subscribe(),
            workspace_settings_reports: self.workspaces.subscribe_results(),
            launcher: self.launcher.subscribe(),
            network: self.network.subscribe(),
            network_reports: self.network.subscribe_results(),
            notifications: self.notifications.subscribe(),
            audio: self.audio.subscribe(),
            audio_reports: self.audio.subscribe_results(),
            brightness: self.brightness.subscribe(),
            brightness_reports: self.brightness.subscribe_results(),
            caffeine: self.caffeine.subscribe(),
            caffeine_reports: self.caffeine.subscribe_results(),
            night_light: self.night_light.subscribe(),
            night_light_reports: self.night_light.subscribe_results(),
            schedule: self.schedule.subscribe(),
            schedule_reports: self.schedule.subscribe_results(),
            power: self.power.subscribe(),
            power_reports: self.power.subscribe_results(),
            recording: self.recording.subscribe(),
            recording_reports: self.recording.subscribe_results(),
            screenshot_reports: self.screenshots.subscribe_results(),
            color_picker_reports: self.color_picker.subscribe_results(),
            tray,
            clock: self.clock.subscribe(),
            setup: self.setup.subscribe(),
            setup_reports: self.setup.subscribe_results(),
            shortcuts: self.shortcuts.subscribe(),
        }
    }

    /// Returns live Hyprland state and commands.
    pub fn hyprland(&self) -> Arc<Desktop> {
        Arc::clone(&self.hyprland)
    }

    /// Returns the appearance configuration handle.
    pub fn appearance(&self) -> appearance::Handle {
        Arc::clone(&self.appearance)
    }

    /// Returns the module visibility configuration handle.
    pub fn modules(&self) -> modules::Handle {
        Arc::clone(&self.modules)
    }

    /// Returns the workspace indicator configuration handle.
    pub fn workspaces(&self) -> workspaces::Handle {
        Arc::clone(&self.workspaces)
    }

    /// Returns the audio control handle.
    pub fn audio(&self) -> audio::Handle {
        Arc::clone(&self.audio)
    }

    /// Returns the display brightness control handle.
    pub fn brightness(&self) -> brightness::Handle {
        Arc::clone(&self.brightness)
    }

    /// Returns the Caffeine inhibitor handle.
    pub fn caffeine(&self) -> caffeine::Handle {
        Arc::clone(&self.caffeine)
    }

    /// Returns the night-light control handle.
    pub fn night_light(&self) -> night_light::Handle {
        Arc::clone(&self.night_light)
    }

    /// Returns the daily scheduler handle.
    pub fn schedule(&self) -> schedule::Handle {
        Arc::clone(&self.schedule)
    }

    /// Returns the live clock/calendar handle.
    pub fn clock(&self) -> clock::Handle {
        Arc::clone(&self.clock)
    }

    /// Returns the color picker command handle.
    pub fn color_picker(&self) -> color_picker::Handle {
        Arc::clone(&self.color_picker)
    }

    /// Returns the application launcher handle.
    pub fn launcher(&self) -> launcher::Handle {
        Arc::clone(&self.launcher)
    }

    /// Returns the network status and command handle.
    pub fn network(&self) -> network::Handle {
        Arc::clone(&self.network)
    }

    /// Returns the notification center handle.
    pub fn notifications(&self) -> notifications::Handle {
        Arc::clone(&self.notifications)
    }

    /// Returns the battery and power-profile handle.
    pub fn power(&self) -> power::Handle {
        Arc::clone(&self.power)
    }

    /// Returns the screen recording handle.
    pub fn recording(&self) -> recording::Handle {
        Arc::clone(&self.recording)
    }

    /// Returns the screenshot capture handle.
    pub fn screenshots(&self) -> ScreenshotHandle {
        Arc::clone(&self.screenshots)
    }

    /// Returns the system tray handle.
    pub fn tray(&self) -> tray::Handle {
        Arc::clone(&self.tray)
    }

    #[expect(dead_code, reason = "reserved for future portal settings consumers")]
    pub fn portal(&self) -> Option<Arc<portals::Settings>> {
        self.portal.as_ref().map(Arc::clone)
    }

    /// Returns the global shortcut registry.
    pub fn shortcuts(&self) -> shortcuts::Handle {
        Arc::clone(&self.shortcuts)
    }

    /// Returns the first-run setup runtime.
    pub fn setup(&self) -> setup::Handle {
        Arc::clone(&self.setup)
    }

    /// Returns the desktop session action handle.
    pub fn session(&self) -> session::Handle {
        Arc::clone(&self.session)
    }
}

/// Boots the native application and returns its initial output projection.
#[instrument(name = "hyprbaric::bootstrap::boot", skip_all, err)]
pub async fn boot(config: &config::Configuration) -> Result<Started, Error> {
    let (components, initial) = Components::boot(config).await?;
    let app = crate::app::App::new(
        components,
        initial.desktop.clone(),
        initial.color_scheme(),
        config.audio.volume_step(),
        config.shortcuts.clone(),
    );

    Ok(Started { app, initial })
}

fn log_bootstrap_phase(name: &'static str, elapsed: Duration) {
    let elapsed_ms = elapsed.as_millis();
    if elapsed >= SLOW_BOOTSTRAP_PHASE {
        tracing::info!(phase = name, elapsed_ms, "Slow native bootstrap phase");
    } else {
        tracing::debug!(phase = name, elapsed_ms, "Native bootstrap phase completed");
    }
}

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("failed to bootstrap the Hyprland desktop connection")]
    Hyprland(#[from] hyprland::Error),
}
