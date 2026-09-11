use rinf::{DartSignal, RustSignal, SignalPiece};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, SignalPiece, Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum AudioEndpointKind {
    Output,
    Input,
}

/// An audio command exchanged with Flutter.
///
/// Command data stays attached to the variant that owns it, so requests and
/// reports do not need nullable side fields.
#[derive(Serialize, Deserialize, DartSignal, SignalPiece, Clone, Debug, PartialEq, Eq, Hash)]
pub enum AudioCommand {
    /// Select the default playback device by stable PipeWire identity.
    SelectOutput {
        id: AudioOutputId,
    },
    SetVolume {
        kind: AudioEndpointKind,
        volume: u8,
    },
    SetMuted {
        kind: AudioEndpointKind,
        muted: bool,
    },
}

/// Stable PipeWire node name; numeric node ids are resolved by Rust.
#[derive(Serialize, Deserialize, SignalPiece, Clone, Debug, PartialEq, Eq, Hash)]
pub struct AudioOutputId {
    /// PipeWire's unique node name.
    pub name: String,
}

/// A selectable playback device.
#[derive(Serialize, Deserialize, SignalPiece, Clone, Debug, PartialEq, Eq, Hash)]
pub struct AudioOutput {
    /// Stable device identity.
    pub id: AudioOutputId,
    /// Human-facing device description.
    pub name: String,
}

/// Output discovery is independent of volume and mute availability.
#[derive(Serialize, Deserialize, SignalPiece, Clone, Debug, PartialEq, Eq, Hash)]
pub enum AudioOutputs {
    /// Available devices and the currently selected default.
    Available {
        devices: Vec<AudioOutput>,
        selected: Option<AudioOutputId>,
    },
    /// User-facing discovery failure.
    Unavailable { message: String },
}

#[derive(Serialize, Deserialize, SignalPiece, Clone, Debug, PartialEq, Eq, Hash)]
pub struct AudioEndpoint {
    pub kind: AudioEndpointKind,
    pub id: Option<String>,
    pub name: String,
    pub volume: u8,
    pub muted: bool,
}

/// Current audio availability and default endpoints.
#[derive(Serialize, RustSignal)]
pub enum AudioStatus {
    Available {
        outputs: AudioOutputs,
        output: Option<AudioEndpoint>,
        input: Option<AudioEndpoint>,
    },
    Unavailable {
        message: String,
    },
}

/// The result of pushing an audio command toward its system boundary.
#[derive(Serialize, RustSignal)]
pub enum AudioCommandResult {
    Started {
        command: AudioCommand,
    },
    Failed {
        command: AudioCommand,
        message: String,
    },
}
