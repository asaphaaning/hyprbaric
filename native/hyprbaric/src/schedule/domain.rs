//! Daily schedule domain vocabulary.

use serde::{Deserialize, Deserializer, de};

/// A scheduled Hyprbaric action.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Action {
    /// Enable or disable the night-light subsystem.
    NightLight,
}

/// A 24-hour wall-clock hour.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Hour(u8);

/// A daily start/stop window for one action.
#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Eq, Hash)]
#[serde(default)]
pub struct DailyWindow {
    /// Whether the schedule is active.
    pub enabled: bool,
    /// Hour at which the action becomes active.
    #[serde(rename = "start_hour")]
    pub start: Hour,
    /// Hour at which the action becomes inactive.
    #[serde(rename = "stop_hour")]
    pub stop: Hour,
}

/// A projected schedule entry for UI and transport.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Entry {
    /// Scheduled action.
    pub action: Action,
    /// Daily window for the action.
    pub window: DailyWindow,
}

/// UI-facing scheduler state.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Snapshot {
    /// Known schedule entries.
    pub entries: Vec<Entry>,
}

/// Scheduler command.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Command {
    /// Persist and apply a daily window for an action.
    SetDailyWindow {
        /// Action to update.
        action: Action,
        /// Replacement window.
        window: DailyWindow,
    },
}

/// Scheduler command report.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Report {
    /// The command was accepted.
    Started(Command),
    /// The command completed.
    Saved(Command),
    /// The command failed.
    Failed {
        /// Command that failed.
        command: Command,
        /// User-facing failure detail.
        message: String,
    },
}

impl Hour {
    /// Projects the hour from an already validated civil time.
    pub fn from_time(time: jiff::civil::Time) -> Self {
        Self(time.hour() as u8)
    }

    /// Creates a valid 24-hour wall-clock hour.
    pub const fn new(value: u8) -> Result<Self, HourError> {
        if value > 23 {
            Err(HourError::OutOfRange { value })
        } else {
            Ok(Self(value))
        }
    }

    /// Returns this hour as `0..=23`.
    pub const fn as_u8(self) -> u8 {
        self.0
    }
}

impl<'de> Deserialize<'de> for Hour {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let value = u8::deserialize(deserializer)?;
        Self::new(value).map_err(de::Error::custom)
    }
}

impl Default for DailyWindow {
    fn default() -> Self {
        Self {
            enabled: false,
            start: Hour(21),
            stop: Hour(7),
        }
    }
}

impl DailyWindow {
    /// Returns whether `hour` is inside this window.
    pub const fn contains(self, hour: Hour) -> bool {
        if !self.enabled {
            return false;
        }

        let start = self.start.as_u8();
        let stop = self.stop.as_u8();
        let hour = hour.as_u8();

        if start == stop {
            true
        } else if start < stop {
            hour >= start && hour < stop
        } else {
            hour >= start || hour < stop
        }
    }
}

impl Snapshot {
    /// Creates a schedule snapshot from one night-light window.
    pub fn night_light(window: DailyWindow) -> Self {
        Self {
            entries: vec![Entry {
                action: Action::NightLight,
                window,
            }],
        }
    }
}

/// Hour validation error.
#[derive(Clone, Copy, Debug, PartialEq, Eq, thiserror::Error)]
pub enum HourError {
    /// Hour values must fit the `0..=23` clock range.
    #[error("schedule hour `{value}` is outside 0..=23")]
    OutOfRange {
        /// Invalid hour.
        value: u8,
    },
}

#[cfg(test)]
mod tests {
    use super::{DailyWindow, Hour};

    #[test]
    fn hour_accepts_twenty_four_hour_range() {
        assert_eq!(Hour::new(0).expect("midnight should parse").as_u8(), 0);
        assert_eq!(Hour::new(23).expect("23 should parse").as_u8(), 23);
        assert!(Hour::new(24).is_err());
    }

    #[test]
    fn daily_window_checks_same_day_range() {
        let window = DailyWindow {
            enabled: true,
            start: Hour::new(9).expect("hour should parse"),
            stop: Hour::new(17).expect("hour should parse"),
        };

        assert!(!window.contains(Hour::new(8).expect("hour should parse")));
        assert!(window.contains(Hour::new(9).expect("hour should parse")));
        assert!(window.contains(Hour::new(16).expect("hour should parse")));
        assert!(!window.contains(Hour::new(17).expect("hour should parse")));
    }

    #[test]
    fn daily_window_checks_overnight_range() {
        let window = DailyWindow::default();

        assert!(!window.contains(Hour::new(20).expect("hour should parse")));
        assert!(!window.contains(Hour::new(21).expect("hour should parse")));

        let window = DailyWindow {
            enabled: true,
            ..window
        };
        assert!(window.contains(Hour::new(21).expect("hour should parse")));
        assert!(window.contains(Hour::new(0).expect("hour should parse")));
        assert!(window.contains(Hour::new(6).expect("hour should parse")));
        assert!(!window.contains(Hour::new(7).expect("hour should parse")));
    }

    #[test]
    fn disabled_window_is_never_active() {
        let window = DailyWindow::default();

        assert!(!window.contains(Hour::new(21).expect("hour should parse")));
    }
}
