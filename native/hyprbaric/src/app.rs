use std::sync::Arc;

use tokio::sync::RwLock;
use tracing::instrument;

use crate::{
    appearance, audio,
    bootstrap::Components,
    brightness, caffeine, clock, color_picker,
    hyprland::{self, DesktopSnapshot},
    launcher, modules, night_light, notifications, portals, power, recording, schedule, screenshot,
    session, setup, shortcuts, tray, workspaces,
};

mod output;

pub use output::{Output, Subscriptions};

/// A typed application request after transport decoding.
#[derive(Clone, Debug)]
pub enum Command {
    /// Read or change the active workspace.
    Workspace(WorkspaceCommand),
    /// Execute a desktop-session action.
    Session(session::Action),
    /// Update the launcher query.
    LauncherQuery(String),
    /// Launch a desktop application.
    Launch(launcher::Id),
    /// Execute a network request.
    Network(NetworkCommand),
    /// Change audio state.
    Audio(audio::Command),
    /// Change persisted appearance.
    Appearance(appearance::Command),
    /// Change module visibility.
    Modules(modules::Command),
    /// Change workspace presentation settings.
    WorkspaceSettings(workspaces::Command),
    /// Change display brightness.
    Brightness(brightness::Command),
    /// Change Caffeine state.
    Caffeine(caffeine::Command),
    /// Change night-light state.
    NightLight(night_light::Command),
    /// Change a daily schedule.
    Schedule(schedule::Command),
    /// Change the active power profile.
    Power(power::Command),
    /// Capture a screenshot.
    Screenshot(screenshot::Command),
    /// Start a color pick.
    ColorPicker(color_picker::Command),
    /// Change screen recording state.
    Recording(recording::Command),
    /// Change notification state.
    Notifications(notifications::Command),
    /// Acknowledge the first-run setup journey.
    Setup(setup::Command),
    /// Execute a clock/calendar request.
    Clock(clock::Command),
    /// Activate a tray item.
    Tray(tray::Activation),
    /// Activate a tray menu row.
    TrayMenu(tray::MenuActivation),
}

/// Active workspace requests.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum WorkspaceCommand {
    /// Republish current workspace and focused-window state.
    Refresh,
    /// Move by a relative workspace offset.
    Switch {
        /// Workspace to activate.
        target: hyprland::WorkspaceTarget,
        /// Output that originated the interaction, when known.
        output: Option<hyprland::OutputName>,
    },
}

/// Network requests whose secrets remain inside the application boundary.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum NetworkCommand {
    /// Scan visible networks.
    Scan,
    /// Enable or disable Wi-Fi.
    SetWifiEnabled(bool),
    /// Connect to a visible network.
    Connect {
        /// Target network name.
        ssid: String,
        /// Optional selected access-point address.
        bssid: Option<String>,
        /// Optional boundary-only network secret.
        password: Option<String>,
    },
    /// Open the host network settings application.
    OpenSettings,
}

/// Immediate result produced while dispatching an application command.
#[derive(Debug)]
pub enum Outcome {
    /// The feature owns subsequent feedback through its subscriptions.
    None,
    /// Values should be republished immediately.
    Outputs(Vec<Output>),
    /// A session action completed synchronously at the application boundary.
    Session(session::Report),
    /// An application launch completed synchronously at the application boundary.
    Launch {
        /// Stable launcher entry ID.
        id: launcher::Id,
        /// User-facing failure detail, or `None` when launch started.
        error: Option<String>,
    },
    /// A tray activation optionally opened a menu.
    TrayMenu(Option<tray::Menu>),
}

/// The native application boundary.
///
/// `App` owns live feature components, accepts the closed [`Command`]
/// vocabulary, and exposes a single merged [`Subscriptions`] stream. Transport
/// adapters should depend on this API instead of reaching into feature handles.
#[derive(Clone)]
pub struct App {
    components: Components,
    audio_volume_step: audio::VolumeStep,
    shortcut_configuration: shortcuts::Configuration,
    inner: Arc<Inner>,
}

struct Inner {
    desktop: RwLock<DesktopSnapshot>,
    color_scheme: RwLock<Option<portals::ColorScheme>>,
}

impl App {
    /// Builds an application from bootstrapped components and initial state.
    pub(crate) fn new(
        components: Components,
        initial_desktop: DesktopSnapshot,
        initial_color_scheme: Option<portals::ColorScheme>,
        audio_volume_step: audio::VolumeStep,
        shortcut_configuration: shortcuts::Configuration,
    ) -> Self {
        Self {
            components,
            audio_volume_step,
            shortcut_configuration,
            inner: Arc::new(Inner {
                desktop: RwLock::new(initial_desktop),
                color_scheme: RwLock::new(initial_color_scheme),
            }),
        }
    }

    /// Returns the shortcut registry used by shortcut configuration commands.
    pub fn shortcuts(&self) -> shortcuts::Handle {
        self.components.shortcuts()
    }

    /// Subscribes to all live application outputs.
    pub fn subscriptions(&self) -> Subscriptions {
        self.components.subscriptions()
    }

    /// Runs Hyprland desktop observation.
    pub async fn listen_hyprland(&self) -> Result<(), crate::hyprland::Error> {
        self.components.hyprland().listen().await
    }

    /// Returns the shortcut configuration loaded for initial reconciliation.
    pub fn shortcut_configuration(&self) -> shortcuts::Configuration {
        self.shortcut_configuration.clone()
    }

    /// Returns the configured percentage applied by volume shortcuts.
    pub const fn audio_volume_step(&self) -> audio::VolumeStep {
        self.audio_volume_step
    }

    /// Dispatches one typed request into the owning feature.
    #[instrument(name = "hyprbaric::app::dispatch", skip(self))]
    pub async fn dispatch(&self, command: Command) -> Outcome {
        match command {
            Command::Workspace(command) => self.dispatch_workspace(command).await,
            Command::Session(action) => {
                let report = match self.components.session().execute(action).await {
                    Ok(()) => session::Report::started(action),
                    Err(error) => {
                        tracing::error!(%error, ?action, "Session action failed");
                        session::Report::failed(action, error)
                    }
                };
                Outcome::Session(report)
            }
            Command::LauncherQuery(query) => {
                self.components.launcher().update_query(query).await;
                Outcome::None
            }
            Command::Launch(id) => {
                let error = self
                    .components
                    .launcher()
                    .launch(id.clone())
                    .await
                    .err()
                    .map(|error| {
                        tracing::error!(%error, app_id = %id, "Application launch failed");
                        error.to_string()
                    });
                Outcome::Launch { id, error }
            }
            Command::Network(command) => {
                match command {
                    NetworkCommand::Scan => self.components.network().scan().await,
                    NetworkCommand::SetWifiEnabled(enabled) => {
                        self.components.network().set_wifi_enabled(enabled).await;
                    }
                    NetworkCommand::Connect {
                        ssid,
                        bssid,
                        password,
                    } => {
                        self.components
                            .network()
                            .connect(ssid, bssid, password)
                            .await;
                    }
                    NetworkCommand::OpenSettings => {
                        self.components.network().open_settings().await;
                    }
                }
                Outcome::None
            }
            Command::Audio(command) => {
                match command {
                    audio::Command::SetVolume { kind, volume } => {
                        self.components.audio().set_volume(kind, volume).await;
                    }
                    audio::Command::SetMuted { kind, muted } => {
                        self.components.audio().set_muted(kind, muted).await;
                    }
                }
                Outcome::None
            }
            Command::Appearance(command) => {
                self.components.appearance().apply(command).await;
                Outcome::None
            }
            Command::Modules(command) => {
                self.components.modules().apply(command).await;
                Outcome::None
            }
            Command::WorkspaceSettings(command) => {
                self.components.workspaces().apply(command).await;
                Outcome::None
            }
            Command::Brightness(brightness::Command::SetLevel { value }) => {
                self.components.brightness().set_level(value).await;
                Outcome::None
            }
            Command::Caffeine(caffeine::Command::SetEnabled { enabled }) => {
                self.components.caffeine().set_enabled(enabled).await;
                Outcome::None
            }
            Command::NightLight(command) => {
                match command {
                    night_light::Command::SetEnabled { enabled } => {
                        self.components.night_light().set_enabled(enabled).await;
                    }
                    night_light::Command::SetTemperature { temperature } => {
                        self.components
                            .night_light()
                            .set_temperature(temperature)
                            .await;
                    }
                }
                Outcome::None
            }
            Command::Schedule(schedule::Command::SetDailyWindow { action, window }) => {
                self.components
                    .schedule()
                    .set_daily_window(action, window)
                    .await;
                Outcome::None
            }
            Command::Power(power::Command::SetProfile { profile }) => {
                self.components.power().set_profile(profile).await;
                Outcome::None
            }
            Command::Screenshot(screenshot::Command::Capture(mode)) => {
                self.components.screenshots().capture(mode);
                Outcome::None
            }
            Command::ColorPicker(color_picker::Command::Pick) => {
                self.components.color_picker().pick();
                Outcome::None
            }
            Command::Recording(recording::Command::Toggle { mode }) => {
                self.components.recording().toggle(mode);
                Outcome::None
            }
            Command::Notifications(command) => {
                self.components.notifications().apply(command).await;
                Outcome::None
            }
            Command::Setup(command) => {
                self.components.setup().apply(command).await;
                Outcome::None
            }
            Command::Clock(command) => {
                self.components.clock().apply(command).await;
                Outcome::None
            }
            Command::Tray(activation) => match self.components.tray().activate(activation).await {
                Ok(tray::Outcome::Menu(menu)) => Outcome::TrayMenu(Some(menu)),
                Ok(tray::Outcome::Activated) => Outcome::TrayMenu(None),
                Err(error) => {
                    tracing::warn!(%error, "Tray activation failed");
                    Outcome::TrayMenu(None)
                }
            },
            Command::TrayMenu(activation) => {
                if let Err(error) = self.components.tray().activate_menu_item(activation).await {
                    tracing::warn!(%error, "Tray menu activation failed");
                }
                Outcome::None
            }
        }
    }

    async fn dispatch_workspace(&self, command: WorkspaceCommand) -> Outcome {
        match command {
            WorkspaceCommand::Refresh => {
                Outcome::Outputs(vec![Output::Desktop(self.desktop().await)])
            }
            WorkspaceCommand::Switch { target, output } => {
                if let Err(error) = self
                    .components
                    .hyprland()
                    .dispatch(hyprland::Command::SwitchWorkspace { target, output })
                    .await
                {
                    tracing::error!(%error, ?target, "Failed to switch Hyprland workspace");
                }
                Outcome::None
            }
        }
    }

    /// Returns the latest coherent desktop projection.
    pub async fn desktop(&self) -> DesktopSnapshot {
        self.inner.desktop.read().await.clone()
    }

    /// Replaces workspace and focused-window state atomically.
    pub async fn set_desktop(&self, snapshot: DesktopSnapshot) {
        *self.inner.desktop.write().await = snapshot;
    }

    /// Returns the most recently observed portal color preference.
    #[expect(dead_code, reason = "kept for portal-driven theming state")]
    pub async fn color_scheme(&self) -> Option<portals::ColorScheme> {
        *self.inner.color_scheme.read().await
    }
}
