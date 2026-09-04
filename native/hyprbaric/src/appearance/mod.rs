//! Live bar appearance configuration.

mod domain;
pub mod settings;
mod signal;

use std::sync::Arc;

use serde::Deserialize;
use tokio::sync::{Mutex, broadcast};
use tracing::instrument;

pub use domain::{
    AccentHue, Command, CornerRadius, MonitorName, MonitorTarget, Opacity, Position, Report,
    Snapshot,
};

/// Appearance configuration loaded from Hyprbaric TOML.
#[derive(Clone, Debug, Deserialize, PartialEq, Eq)]
#[serde(default)]
pub struct Configuration {
    position: Position,
    monitor: MonitorTarget,
    opacity: Opacity,
    corner_radius: CornerRadius,
    accent_hue: AccentHue,
}

/// Shared appearance runtime handle.
pub type Handle = Arc<Appearance>;

/// Runtime owner for persisted appearance state.
pub struct Appearance {
    events: broadcast::Sender<Snapshot>,
    results: broadcast::Sender<Report>,
    state: Mutex<Configuration>,
}

impl Default for Configuration {
    fn default() -> Self {
        Self {
            position: Position::default(),
            monitor: MonitorTarget::default(),
            opacity: Opacity::default(),
            corner_radius: CornerRadius::default(),
            accent_hue: AccentHue::default(),
        }
    }
}

impl Configuration {
    pub const fn position(&self) -> Position {
        self.position
    }

    pub fn monitor(&self) -> &MonitorTarget {
        &self.monitor
    }

    pub const fn opacity(&self) -> Opacity {
        self.opacity
    }

    pub const fn corner_radius(&self) -> CornerRadius {
        self.corner_radius
    }

    pub const fn accent_hue(&self) -> AccentHue {
        self.accent_hue
    }

    pub(crate) fn apply(self, command: &Command) -> Self {
        match command {
            Command::SetPosition { position } => Self {
                position: *position,
                ..self
            },
            Command::SetMonitor { monitor } => Self {
                monitor: monitor.clone(),
                ..self
            },
            Command::SetOpacity { opacity } => Self {
                opacity: *opacity,
                ..self
            },
            Command::SetCornerRadius { corner_radius } => Self {
                corner_radius: *corner_radius,
                ..self
            },
            Command::SetAccentHue { accent_hue } => Self {
                accent_hue: *accent_hue,
                ..self
            },
            Command::RestoreDefaults => Self::default(),
        }
    }

    pub fn snapshot(&self) -> Snapshot {
        Snapshot {
            position: self.position,
            monitor: self.monitor.clone(),
            opacity: self.opacity,
            corner_radius: self.corner_radius,
            accent_hue: self.accent_hue,
        }
    }
}

impl Appearance {
    #[instrument(skip_all)]
    pub fn bootstrap(config: &Configuration) -> (Handle, Snapshot) {
        let (events, _) = broadcast::channel(16);
        let (results, _) = broadcast::channel(8);
        let appearance = Arc::new(Self {
            events,
            results,
            state: Mutex::new(config.clone()),
        });

        (appearance, config.snapshot())
    }

    pub fn subscribe(&self) -> broadcast::Receiver<Snapshot> {
        self.events.subscribe()
    }

    pub fn subscribe_results(&self) -> broadcast::Receiver<Report> {
        self.results.subscribe()
    }

    #[instrument(skip(self))]
    pub async fn apply(&self, command: Command) {
        drop(self.results.send(Report::Started(command.clone())));
        let mut state = self.state.lock().await;
        let next = match settings::save(&command, state.clone()) {
            Ok(next) => next,
            Err(error) => {
                drop(self.results.send(Report::Failed {
                    command,
                    message: error.to_string(),
                }));
                return;
            }
        };

        let snapshot = next.snapshot();
        *state = next;
        drop(state);

        drop(self.results.send(Report::Saved(command)));
        drop(self.events.send(snapshot));
    }
}

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error(transparent)]
    Config(#[from] crate::config::Error),
    #[error(transparent)]
    Opacity(#[from] domain::OpacityError),
    #[error(transparent)]
    CornerRadius(#[from] domain::CornerRadiusError),
    #[error(transparent)]
    AccentHue(#[from] domain::AccentHueError),
    #[error(transparent)]
    MonitorName(#[from] domain::MonitorNameError),
}
