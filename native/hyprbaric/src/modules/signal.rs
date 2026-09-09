//! RINF projections for module visibility settings.

use crate::signals;

use super::{Command, Entry, Module, Report, Snapshot};

impl From<Module> for signals::ModuleId {
    fn from(module: Module) -> Self {
        match module {
            Module::ActiveWindowTitle => Self::ActiveWindowTitle,
            Module::SystemTray => Self::SystemTray,
            Module::Notifications => Self::Notifications,
            Module::AudioDisplay => Self::AudioDisplay,
            Module::GlobalMenu => Self::GlobalMenu,
        }
    }
}

impl From<signals::ModuleId> for Module {
    fn from(module: signals::ModuleId) -> Self {
        match module {
            signals::ModuleId::ActiveWindowTitle => Self::ActiveWindowTitle,
            signals::ModuleId::SystemTray => Self::SystemTray,
            signals::ModuleId::Notifications => Self::Notifications,
            signals::ModuleId::AudioDisplay => Self::AudioDisplay,
            signals::ModuleId::GlobalMenu => Self::GlobalMenu,
        }
    }
}

impl From<signals::ModuleCommand> for Command {
    fn from(command: signals::ModuleCommand) -> Self {
        match command {
            signals::ModuleCommand::SetEnabled { module, enabled } => Self::SetEnabled {
                module: module.into(),
                enabled,
            },
        }
    }
}

impl From<&Snapshot> for signals::ModulesStatus {
    fn from(snapshot: &Snapshot) -> Self {
        Self {
            entries: snapshot.entries.iter().map(Into::into).collect(),
        }
    }
}

impl From<&Entry> for signals::ModuleEntry {
    fn from(entry: &Entry) -> Self {
        Self {
            module: entry.module.into(),
            enabled: entry.enabled,
        }
    }
}

impl From<&Report> for signals::ModuleCommandResult {
    fn from(report: &Report) -> Self {
        match report {
            Report::Started(command) => Self::Started {
                command: command.into(),
            },
            Report::Saved(command) => Self::Saved {
                command: command.into(),
            },
            Report::Failed { command, message } => Self::Failed {
                command: command.into(),
                message: message.clone(),
            },
        }
    }
}

impl From<&Command> for signals::ModuleCommand {
    fn from(command: &Command) -> Self {
        match command {
            Command::SetEnabled { module, enabled } => Self::SetEnabled {
                module: (*module).into(),
                enabled: *enabled,
            },
        }
    }
}

#[cfg(test)]
mod tests {
    use crate::{
        modules::{Command, Module, Snapshot},
        signals,
    };

    #[test]
    fn command_projects_from_transport() {
        let command = Command::from(signals::ModuleCommand::SetEnabled {
            module: signals::ModuleId::SystemTray,
            enabled: false,
        });

        assert!(matches!(
            command,
            Command::SetEnabled {
                module: Module::SystemTray,
                enabled: false
            }
        ));
    }

    #[test]
    fn snapshot_projects_status_entries() {
        let status = signals::ModulesStatus::from(&Snapshot {
            entries: crate::modules::Configuration::default().snapshot().entries,
        });

        assert_eq!(status.entries.len(), Module::ALL.len());
        assert_eq!(
            status.entries[0].module,
            signals::ModuleId::ActiveWindowTitle
        );
        assert!(status.entries[0].enabled);
    }
}
