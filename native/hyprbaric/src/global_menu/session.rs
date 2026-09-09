//! Identity carried by commands and replies for one focused exporter.
use crate::hyprland::WindowId;

/// A generation bound to the window whose actions it may invoke.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Session {
    /// Native generation, stable across layout refreshes.
    pub generation: u64,
    /// Window owning this menu.
    pub window: WindowId,
}
