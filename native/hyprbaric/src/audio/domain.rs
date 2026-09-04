//! Audio domain vocabulary.
//!
//! This module owns the small values the audio runtime publishes and reports:
//! [`Percent`], [`EndpointKind`], [`Endpoint`], [`Snapshot`], [`Command`], and
//! [`Report`]. PipeWire and command-line process details stay in the backend
//! boundary.

use serde::{Deserialize, Deserializer};

/// A clamped audio volume percentage.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Percent(u8);

/// A volume adjustment step normalized to `0..=100` percent.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct VolumeStep(u8);

/// The default PipeWire endpoint class controlled by Hyprbaric.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum EndpointKind {
    /// Default output/sink endpoint.
    Output,
    /// Default input/source endpoint.
    Input,
}

/// One default audio endpoint.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Endpoint {
    /// Endpoint class.
    pub kind: EndpointKind,
    /// PipeWire node id when available.
    pub id: Option<String>,
    /// Human-facing endpoint name.
    pub name: String,
    /// Last known volume.
    pub volume: Percent,
    /// Whether the endpoint is muted.
    pub muted: bool,
}

/// UI-facing audio state.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Snapshot {
    /// At least one default endpoint is available.
    Available {
        /// Default output endpoint, when one could be read.
        output: Option<Endpoint>,
        /// Default input endpoint, when one could be read.
        input: Option<Endpoint>,
    },
    /// No supported audio endpoint is currently available.
    Unavailable {
        /// User-facing failure detail.
        message: String,
    },
}

/// A command that reached the audio runtime boundary.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Command {
    /// Set the volume for an endpoint class.
    SetVolume {
        /// Endpoint class to change.
        kind: EndpointKind,
        /// Requested volume.
        volume: Percent,
    },
    /// Set mute state for an endpoint class.
    SetMuted {
        /// Endpoint class to change.
        kind: EndpointKind,
        /// Requested mute state.
        muted: bool,
    },
}

/// A command report published to subscribers.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Report {
    /// The command reached its process boundary.
    Started(Command),
    /// The command failed before or at the process boundary.
    Failed {
        /// The command that failed.
        command: Command,
        /// User-facing failure detail.
        message: String,
    },
}

impl Percent {
    /// Creates a percentage clamped to `0..=100`.
    pub const fn new(value: u8) -> Self {
        Self(if value > 100 { 100 } else { value })
    }

    /// Creates a percentage from a `wpctl` volume fraction.
    pub(crate) fn from_fraction(value: f32) -> Self {
        let percent = (value * 100.0).round();
        if percent.is_nan() || percent.is_sign_negative() {
            return Self(0);
        }
        Self::new(percent.min(100.0) as u8)
    }

    /// Returns the clamped integer percentage.
    pub const fn as_u8(self) -> u8 {
        self.0
    }
}

impl VolumeStep {
    /// Default adjustment applied by volume-up and volume-down shortcuts.
    pub const DEFAULT: Self = Self(5);

    /// Creates a step by clamping an integer to `0..=100`.
    pub const fn new(value: i64) -> Self {
        if value < 0 {
            Self(0)
        } else if value > 100 {
            Self(100)
        } else {
            Self(value as u8)
        }
    }

    /// Returns the normalized percentage step.
    pub const fn as_u8(self) -> u8 {
        self.0
    }
}

impl Default for VolumeStep {
    fn default() -> Self {
        Self::DEFAULT
    }
}

impl<'de> Deserialize<'de> for VolumeStep {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        i64::deserialize(deserializer).map(Self::new)
    }
}

impl Snapshot {
    /// Creates an unavailable audio snapshot.
    pub(crate) fn unavailable(message: impl Into<String>) -> Self {
        Self::Unavailable {
            message: message.into(),
        }
    }
}

impl EndpointKind {
    /// Returns the `wpctl` selector for this endpoint kind.
    pub(crate) const fn selector(self) -> &'static str {
        match self {
            Self::Output => "@DEFAULT_AUDIO_SINK@",
            Self::Input => "@DEFAULT_AUDIO_SOURCE@",
        }
    }

    /// Returns the fallback display name for this endpoint kind.
    pub(crate) const fn fallback_name(self) -> &'static str {
        match self {
            Self::Output => "Audio Output",
            Self::Input => "Audio Input",
        }
    }
}
