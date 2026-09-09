//! Global shortcut configuration, identity, and installation.
//!
//! A shortcut starts as a stable [`Shortcut`] in the application vocabulary.
//! [`Configuration`] projects enabled shortcuts into installable [`Spec`]
//! values, and [`Registry`] keeps those specs bound through both the shortcuts
//! portal and Hyprland's `global` dispatcher.

mod binding;
mod domain;
mod hyprland;
mod identity;
mod portal;
mod registry;
pub(crate) mod settings;
mod signal;

use std::{io, path::PathBuf, process::ExitStatus};

pub use binding::Configuration;
pub use domain::{Action, Event, Shortcut, Spec, UiAction};
pub use registry::{Handle, Registry};
pub use settings::{
    Command as SettingsCommand, Report as SettingsReport, Snapshot as SettingsSnapshot,
};

/// An error raised while preparing, installing, or reconciling a [`Shortcut`].
#[derive(Debug, thiserror::Error)]
pub enum Error {
    /// An app-owned bind cannot be represented by the supported Lua dispatchers.
    #[error("unsupported or malformed shortcut bind: {value}")]
    InvalidBind { value: String },
    /// The process tried to start the registry lifecycle more than once.
    #[error("the shortcut registry is already running")]
    RegistryAlreadyRunning,
    /// The registry was asked to reconcile a shortcut it does not track.
    #[error("shortcut {shortcut} is not tracked by the registry")]
    UntrackedShortcut { shortcut: Shortcut },
    /// The desktop portal could not be reached.
    #[error("failed to connect to the global shortcuts portal")]
    ConnectPortal(#[source] ashpd::Error),
    /// The session bus for the portal connection could not be reached.
    #[error("failed to connect to the global shortcuts portal session bus: {0}")]
    ConnectPortalBus(#[source] zbus::Error),
    /// The desktop portal could not allocate a shortcuts session.
    #[error("failed to create the global shortcuts portal session")]
    CreateSession(#[source] ashpd::Error),
    /// The host process could not register its application identity with the portal.
    #[error("failed to register Hyprbaric with the desktop portal: {0}")]
    RegisterHostApp(#[source] ashpd::Error),
    /// The implementation-side activation signal bus could not be reached.
    #[error("failed to connect to the shortcut activation signal bus")]
    ConnectActivationBus(#[source] zbus::Error),
    /// The current executable path could not be resolved for a portal desktop entry.
    #[error("failed to resolve the current executable for portal registration")]
    CurrentExe(#[source] io::Error),
    /// A portal desktop entry could not be read.
    #[error("failed to read portal desktop entry `{}`", path.display())]
    ReadDesktopEntry {
        path: PathBuf,
        #[source]
        source: io::Error,
    },
    /// The portal desktop entry directory could not be created.
    #[error("failed to create portal desktop entry directory `{}`", path.display())]
    CreateDesktopEntryDir {
        path: PathBuf,
        #[source]
        source: io::Error,
    },
    /// A portal desktop entry could not be written.
    #[error("failed to write portal desktop entry `{}`", path.display())]
    WriteDesktopEntry {
        path: PathBuf,
        #[source]
        source: io::Error,
    },
    /// Portal activation events could not be subscribed to.
    #[error("failed to subscribe to global shortcut activation events")]
    SubscribeActivations(#[source] zbus::Error),
    /// The portal rejected a particular shortcut binding.
    #[error("failed to bind portal shortcut {shortcut}: {source}")]
    BindPortalShortcut {
        shortcut: Shortcut,
        #[source]
        source: ashpd::Error,
    },
    /// Hyprland returned malformed binding state.
    #[error("failed to parse `hyprctl binds -j` output")]
    ParseHyprBindings(#[source] serde_json::Error),
    /// A compositor command could not be started.
    #[error("failed to execute `{command}`")]
    CommandIo {
        command: String,
        #[source]
        source: std::io::Error,
    },
    /// A compositor command ran and reported failure.
    #[error("command `{command}` exited with status {status}")]
    CommandStatus { command: String, status: ExitStatus },
    /// A compositor command exceeded the startup-safe boundary.
    #[error("command `{command}` timed out")]
    CommandTimeout { command: String },
    /// A Hyprbaric bind cannot be replaced without touching a foreign bind.
    #[error(
        "cannot safely replace Hyprland bind `{bind}` for {shortcut} because the chord is shared with non-Hyprbaric binds"
    )]
    UnsafeUnbind { shortcut: Shortcut, bind: String },
}

impl Error {
    /// Returns whether this error should stop background shortcut retries.
    ///
    /// Unsafe unbinds are not transient failures. Retrying them just repeats a
    /// compositor operation Hyprbaric has already proven it cannot perform
    /// without touching a foreign bind.
    pub(crate) const fn blocks_shortcut_retry(&self) -> bool {
        matches!(self, Self::UnsafeUnbind { .. })
    }
}
