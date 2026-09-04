//! RINF projections for appearance settings.

use crate::signals;

use super::{
    AccentHue, Command, CornerRadius, MonitorName, MonitorTarget, Opacity, Position, Report,
    Snapshot,
};

impl From<Position> for signals::AppearancePosition {
    fn from(position: Position) -> Self {
        match position {
            Position::Top => Self::Top,
            Position::Bottom => Self::Bottom,
        }
    }
}

impl From<signals::AppearancePosition> for Position {
    fn from(position: signals::AppearancePosition) -> Self {
        match position {
            signals::AppearancePosition::Top => Self::Top,
            signals::AppearancePosition::Bottom => Self::Bottom,
        }
    }
}

impl From<&MonitorTarget> for signals::AppearanceMonitorTarget {
    fn from(monitor: &MonitorTarget) -> Self {
        match monitor {
            MonitorTarget::Primary => Self::Primary,
            MonitorTarget::All => Self::All,
            MonitorTarget::Named(name) => Self::Named {
                name: name.as_str().to_owned(),
            },
        }
    }
}

impl TryFrom<signals::AppearanceMonitorTarget> for MonitorTarget {
    type Error = super::Error;

    fn try_from(monitor: signals::AppearanceMonitorTarget) -> Result<Self, Self::Error> {
        match monitor {
            signals::AppearanceMonitorTarget::Primary => Ok(Self::Primary),
            signals::AppearanceMonitorTarget::All => Ok(Self::All),
            signals::AppearanceMonitorTarget::Named { name } => {
                Ok(Self::Named(MonitorName::new(name)?))
            }
        }
    }
}

impl TryFrom<signals::AppearanceCommand> for Command {
    type Error = super::Error;

    fn try_from(command: signals::AppearanceCommand) -> Result<Self, Self::Error> {
        match command {
            signals::AppearanceCommand::SetPosition { position } => Ok(Self::SetPosition {
                position: position.into(),
            }),
            signals::AppearanceCommand::SetMonitor { monitor } => Ok(Self::SetMonitor {
                monitor: monitor.try_into()?,
            }),
            signals::AppearanceCommand::SetOpacity { opacity } => Ok(Self::SetOpacity {
                opacity: Opacity::new(opacity)?,
            }),
            signals::AppearanceCommand::SetCornerRadius { corner_radius } => {
                Ok(Self::SetCornerRadius {
                    corner_radius: CornerRadius::new(corner_radius)?,
                })
            }
            signals::AppearanceCommand::SetAccentHue { accent_hue } => Ok(Self::SetAccentHue {
                accent_hue: AccentHue::new(accent_hue)?,
            }),
            signals::AppearanceCommand::RestoreDefaults => Ok(Self::RestoreDefaults),
        }
    }
}

impl From<&Snapshot> for signals::AppearanceStatus {
    fn from(snapshot: &Snapshot) -> Self {
        Self {
            position: snapshot.position.into(),
            monitor: (&snapshot.monitor).into(),
            opacity: snapshot.opacity.as_u8(),
            corner_radius: snapshot.corner_radius.as_u8(),
            accent_hue: snapshot.accent_hue.as_u16(),
        }
    }
}

impl From<&Report> for signals::AppearanceCommandResult {
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

impl From<&Command> for signals::AppearanceCommand {
    fn from(command: &Command) -> Self {
        match command {
            Command::SetPosition { position } => Self::SetPosition {
                position: (*position).into(),
            },
            Command::SetMonitor { monitor } => Self::SetMonitor {
                monitor: monitor.into(),
            },
            Command::SetOpacity { opacity } => Self::SetOpacity {
                opacity: opacity.as_u8(),
            },
            Command::SetCornerRadius { corner_radius } => Self::SetCornerRadius {
                corner_radius: corner_radius.as_u8(),
            },
            Command::SetAccentHue { accent_hue } => Self::SetAccentHue {
                accent_hue: accent_hue.as_u16(),
            },
            Command::RestoreDefaults => Self::RestoreDefaults,
        }
    }
}

#[cfg(test)]
mod tests {
    use crate::{
        appearance::{AccentHue, Command, Snapshot},
        signals,
    };

    #[test]
    fn command_rejects_invalid_hue() {
        let error = Command::try_from(signals::AppearanceCommand::SetAccentHue { accent_hue: 360 })
            .expect_err("invalid hue should fail");

        assert!(error.to_string().contains("outside 0..=359"));
    }

    #[test]
    fn command_rejects_empty_named_monitor() {
        let error = Command::try_from(signals::AppearanceCommand::SetMonitor {
            monitor: signals::AppearanceMonitorTarget::Named {
                name: "  ".to_owned(),
            },
        })
        .expect_err("empty monitor name should fail");

        assert!(error.to_string().contains("empty or reserved"));
    }

    #[test]
    fn restore_defaults_projects_to_transport() {
        let command = signals::AppearanceCommand::from(&Command::RestoreDefaults);

        assert!(matches!(
            command,
            signals::AppearanceCommand::RestoreDefaults
        ));
    }

    #[test]
    fn snapshot_projects_status() {
        let status = signals::AppearanceStatus::from(&Snapshot {
            position: crate::appearance::Position::Bottom,
            monitor: crate::appearance::MonitorTarget::All,
            opacity: crate::appearance::Opacity::new(80).expect("opacity should parse"),
            corner_radius: crate::appearance::CornerRadius::new(10).expect("radius should parse"),
            accent_hue: AccentHue::new(240).expect("hue should parse"),
        });

        assert_eq!(status.position, signals::AppearancePosition::Bottom);
        assert_eq!(status.monitor, signals::AppearanceMonitorTarget::All);
        assert_eq!(status.opacity, 80);
        assert_eq!(status.corner_radius, 10);
        assert_eq!(status.accent_hue, 240);
    }
}
