//! Live bar module visibility configuration.

mod domain;
pub mod settings;
mod signal;

use std::sync::Arc;

use serde::Deserialize;
use tokio::sync::{Mutex, broadcast};
use tracing::instrument;

pub use domain::{Command, Entry, Module, ModuleSettings, Report, Snapshot};

/// Bar module configuration loaded from Hyprbaric TOML.
#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Eq)]
#[serde(default)]
pub struct Configuration {
    active_window_title: ModuleSettings,
    system_tray: ModuleSettings,
    notifications: ModuleSettings,
    audio_display: ModuleSettings,
    global_menu: ModuleSettings,
}

/// Shared module visibility runtime handle.
pub type Handle = Arc<Modules>;

/// Runtime owner for persisted module visibility state.
pub struct Modules {
    events: broadcast::Sender<Snapshot>,
    results: broadcast::Sender<Report>,
    state: Mutex<Configuration>,
}

impl Default for Configuration {
    fn default() -> Self {
        Self {
            active_window_title: ModuleSettings::default(),
            system_tray: ModuleSettings::default(),
            notifications: ModuleSettings::ENABLED,
            audio_display: ModuleSettings::ENABLED,
            global_menu: ModuleSettings::DISABLED,
        }
    }
}

impl Configuration {
    pub const fn enabled(self, module: Module) -> bool {
        self.settings(module).enabled()
    }

    pub const fn settings(self, module: Module) -> ModuleSettings {
        match module {
            Module::ActiveWindowTitle => self.active_window_title,
            Module::SystemTray => self.system_tray,
            Module::Notifications => self.notifications,
            Module::AudioDisplay => self.audio_display,
            Module::GlobalMenu => self.global_menu,
        }
    }

    pub(crate) fn apply(self, command: &Command) -> Self {
        match command {
            Command::SetEnabled { module, enabled } => self.with_enabled(*module, *enabled),
        }
    }

    pub fn snapshot(self) -> Snapshot {
        Snapshot {
            entries: Module::ALL
                .into_iter()
                .map(|module| Entry {
                    module,
                    enabled: self.enabled(module),
                })
                .collect(),
        }
    }

    const fn with_enabled(self, module: Module, enabled: bool) -> Self {
        match module {
            Module::ActiveWindowTitle => Self {
                active_window_title: self.active_window_title.with_enabled(enabled),
                ..self
            },
            Module::SystemTray => Self {
                system_tray: self.system_tray.with_enabled(enabled),
                ..self
            },
            Module::Notifications => Self {
                notifications: self.notifications.with_enabled(enabled),
                ..self
            },
            Module::AudioDisplay => Self {
                audio_display: self.audio_display.with_enabled(enabled),
                ..self
            },
            Module::GlobalMenu => Self {
                global_menu: self.global_menu.with_enabled(enabled),
                ..self
            },
        }
    }
}

impl Modules {
    #[instrument(skip_all)]
    pub fn bootstrap(config: &Configuration) -> (Handle, Snapshot) {
        let (events, _) = broadcast::channel(16);
        let (results, _) = broadcast::channel(8);
        let modules = Arc::new(Self {
            events,
            results,
            state: Mutex::new(*config),
        });

        (modules, config.snapshot())
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
        let current = { *self.state.lock().await };
        let next = match settings::save(&command, current) {
            Ok(next) => next,
            Err(error) => {
                drop(self.results.send(Report::Failed {
                    command,
                    message: error.to_string(),
                }));
                return;
            }
        };

        {
            let mut state = self.state.lock().await;
            *state = next;
        }

        drop(self.results.send(Report::Saved(command)));
        drop(self.events.send(next.snapshot()));
    }
}

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error(transparent)]
    Config(#[from] crate::config::Error),
}

#[cfg(test)]
mod tests {
    use super::{Command, Configuration, Module};

    #[test]
    fn defaults_show_every_module_the_user_need_not_opt_into() {
        let config = Configuration::default();

        for module in Module::ALL {
            assert_eq!(config.enabled(module), module.default_enabled());
        }

        assert!(config.enabled(Module::SystemTray));
        assert!(!config.enabled(Module::GlobalMenu));
    }

    #[test]
    fn config_accepts_module_visibility_overrides() {
        let config = toml::from_str::<Configuration>(
            r#"
[active_window_title]
enabled = false

[system_tray]
enabled = true

[notifications]
enabled = false

[audio_display]
enabled = true
"#,
        )
        .expect("module config should parse");

        assert!(!config.enabled(Module::ActiveWindowTitle));
        assert!(config.enabled(Module::SystemTray));
        assert!(!config.enabled(Module::Notifications));
        assert!(config.enabled(Module::AudioDisplay));
    }

    #[test]
    fn command_updates_only_selected_module() {
        let config = Configuration::default().apply(&Command::SetEnabled {
            module: Module::SystemTray,
            enabled: false,
        });

        assert!(config.enabled(Module::ActiveWindowTitle));
        assert!(!config.enabled(Module::SystemTray));
        assert!(config.enabled(Module::Notifications));
        assert!(config.enabled(Module::AudioDisplay));
    }
}
