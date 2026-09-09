//! RINF signal boundary types.
//!
//! These modules keep transport-facing types grouped by feature while this
//! module preserves the flat `signals::*` import surface used by the runtime.

mod app;
mod appearance;
mod audio;
mod brightness;
mod caffeine;
mod capabilities;
mod clock;
mod color_picker;
mod compositor;
mod global_menu;
mod launcher;
mod modules;
mod network;
mod night_light;
mod notifications;
mod portal;
mod power;
mod recording;
mod schedule;
mod screenshot;
mod session;
mod setup;
mod shortcuts;
mod tray;
mod workspaces;

pub use self::{
    app::*, appearance::*, audio::*, brightness::*, caffeine::*, capabilities::*, clock::*,
    color_picker::*, compositor::*, global_menu::*, launcher::*, modules::*, network::*,
    night_light::*, notifications::*, portal::*, power::*, recording::*, schedule::*,
    screenshot::*, session::*, setup::*, shortcuts::*, tray::*, workspaces::*,
};
