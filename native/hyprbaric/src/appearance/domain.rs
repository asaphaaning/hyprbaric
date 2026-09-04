//! Bar appearance settings shared by Rust configuration and Flutter UI.

use std::fmt;

use serde::{Deserialize, Deserializer, de};

pub const DEFAULT_OPACITY: u8 = 77;
pub const DEFAULT_CORNER_RADIUS: u8 = 12;
pub const DEFAULT_ACCENT_HUE: u16 = 197;

#[derive(Clone, Copy, Debug, Default, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "snake_case")]
pub enum Position {
    #[default]
    Top,
    Bottom,
}

/// The monitor set on which the bar should be rendered.
#[derive(Clone, Debug, Default, PartialEq, Eq, Hash)]
pub enum MonitorTarget {
    /// Render one bar on the compositor's primary monitor.
    #[default]
    Primary,
    /// Render one bar on every connected monitor.
    All,
    /// Render one bar on the monitor identified by [`MonitorName`].
    Named(MonitorName),
}

/// A non-empty monitor identity reported by the native GTK boundary.
#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub struct MonitorName(String);

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Opacity(u8);

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct CornerRadius(u8);

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct AccentHue(u16);

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Snapshot {
    pub position: Position,
    pub monitor: MonitorTarget,
    pub opacity: Opacity,
    pub corner_radius: CornerRadius,
    pub accent_hue: AccentHue,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Command {
    SetPosition { position: Position },
    SetMonitor { monitor: MonitorTarget },
    SetOpacity { opacity: Opacity },
    SetCornerRadius { corner_radius: CornerRadius },
    SetAccentHue { accent_hue: AccentHue },
    RestoreDefaults,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Report {
    Started(Command),
    Saved(Command),
    Failed { command: Command, message: String },
}

impl Position {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Top => "top",
            Self::Bottom => "bottom",
        }
    }
}

impl MonitorTarget {
    /// Parses the compact value persisted in `[appearance].monitor`.
    pub fn from_config(value: &str) -> Result<Self, MonitorNameError> {
        match value.trim() {
            "primary" => Ok(Self::Primary),
            "all" => Ok(Self::All),
            name => MonitorName::new(name).map(Self::Named),
        }
    }

    /// Returns the compact value persisted in `[appearance].monitor`.
    pub fn as_str(&self) -> &str {
        match self {
            Self::Primary => "primary",
            Self::All => "all",
            Self::Named(name) => name.as_str(),
        }
    }
}

impl<'de> Deserialize<'de> for MonitorTarget {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let value = String::deserialize(deserializer)?;
        Self::from_config(&value).map_err(de::Error::custom)
    }
}

impl MonitorName {
    /// Creates a monitor identity from the native display label.
    pub fn new(value: impl Into<String>) -> Result<Self, MonitorNameError> {
        let value = value.into();
        let value = value.trim();

        if value.is_empty() || matches!(value, "primary" | "all") {
            Err(MonitorNameError::Invalid(value.to_owned()))
        } else {
            Ok(Self(value.to_owned()))
        }
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for MonitorName {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.0.fmt(formatter)
    }
}

impl Opacity {
    pub const MIN: u8 = 20;
    pub const MAX: u8 = 100;

    pub const fn new(value: u8) -> Result<Self, OpacityError> {
        if value < Self::MIN || value > Self::MAX {
            Err(OpacityError::OutOfRange(value))
        } else {
            Ok(Self(value))
        }
    }

    pub const fn default_value() -> Self {
        Self(DEFAULT_OPACITY)
    }

    pub const fn as_u8(self) -> u8 {
        self.0
    }
}

impl Default for Opacity {
    fn default() -> Self {
        Self::default_value()
    }
}

impl<'de> Deserialize<'de> for Opacity {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let value = u8::deserialize(deserializer)?;
        Self::new(value).map_err(de::Error::custom)
    }
}

impl CornerRadius {
    pub const MAX: u8 = 32;

    pub const fn new(value: u8) -> Result<Self, CornerRadiusError> {
        if value > Self::MAX {
            Err(CornerRadiusError::OutOfRange(value))
        } else {
            Ok(Self(value))
        }
    }

    pub const fn default_value() -> Self {
        Self(DEFAULT_CORNER_RADIUS)
    }

    pub const fn as_u8(self) -> u8 {
        self.0
    }
}

impl Default for CornerRadius {
    fn default() -> Self {
        Self::default_value()
    }
}

impl<'de> Deserialize<'de> for CornerRadius {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let value = u8::deserialize(deserializer)?;
        Self::new(value).map_err(de::Error::custom)
    }
}

impl AccentHue {
    pub const MAX: u16 = 359;

    pub const fn new(value: u16) -> Result<Self, AccentHueError> {
        if value > Self::MAX {
            Err(AccentHueError::OutOfRange(value))
        } else {
            Ok(Self(value))
        }
    }

    pub const fn default_value() -> Self {
        Self(DEFAULT_ACCENT_HUE)
    }

    pub const fn as_u16(self) -> u16 {
        self.0
    }
}

impl Default for AccentHue {
    fn default() -> Self {
        Self::default_value()
    }
}

impl<'de> Deserialize<'de> for AccentHue {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let value = u16::deserialize(deserializer)?;
        Self::new(value).map_err(de::Error::custom)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, thiserror::Error)]
pub enum OpacityError {
    #[error("appearance opacity {0} is outside 20..=100")]
    OutOfRange(u8),
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, thiserror::Error)]
pub enum CornerRadiusError {
    #[error("appearance corner radius {0}px is outside 0..=32px")]
    OutOfRange(u8),
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, thiserror::Error)]
pub enum AccentHueError {
    #[error("appearance accent hue {0} is outside 0..=359 degrees")]
    OutOfRange(u16),
}

#[derive(Clone, Debug, PartialEq, Eq, thiserror::Error)]
pub enum MonitorNameError {
    #[error("monitor name `{0}` is empty or reserved")]
    Invalid(String),
}

#[cfg(test)]
mod tests {
    use super::{AccentHue, CornerRadius, MonitorTarget, Opacity};

    #[test]
    fn opacity_enforces_configurable_range() {
        assert!(Opacity::new(Opacity::MIN).is_ok());
        assert!(Opacity::new(Opacity::MAX).is_ok());
        assert!(Opacity::new(Opacity::MIN - 1).is_err());
    }

    #[test]
    fn corner_radius_allows_square_edges() {
        assert_eq!(
            CornerRadius::new(0).expect("radius should parse").as_u8(),
            0
        );
        assert!(CornerRadius::new(CornerRadius::MAX + 1).is_err());
    }

    #[test]
    fn accent_hue_accepts_color_wheel_degrees() {
        assert_eq!(AccentHue::new(359).expect("hue should parse").as_u16(), 359);
        assert!(AccentHue::new(360).is_err());
    }

    #[test]
    fn monitor_target_preserves_named_monitors() {
        assert_eq!(
            MonitorTarget::from_config("Dell U2720Q #2")
                .expect("monitor target should parse")
                .as_str(),
            "Dell U2720Q #2"
        );
        assert_eq!(
            MonitorTarget::from_config("  "),
            Err(super::MonitorNameError::Invalid(String::new()))
        );
    }
}
