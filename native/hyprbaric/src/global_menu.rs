//! Focused application menus.
//!
//! ```text
//! Runtime -> Active { Session, Endpoint, Live }
//!                                      |-- snapshot + popups
//!                                      +-- owned watch task
//! ```
//!
//! The application owns one runtime. Protocol adapters decode D-Bus values;
//! discovery joins compositor facts; the runtime owns cancellation and publication.
//!
//! Domain values stay in `domain` and `session`. `discovery` resolves a typed
//! `endpoint`; `dbusmenu` and `gtk` separate clients, tree transforms, and watches.
//! `snapshot` preserves served rows, `popup` determines descendant closure, and
//! `live` combines those values for one immutable identity. Replacing the active
//! session cancels and joins its watch before opening another. `publish` projects
//! typed [Update] values into RINF signals at the application boundary.
mod dbusmenu;
mod discovery;
mod domain;
mod endpoint;
mod error;
mod gtk;
mod live;
mod model;
mod plugin;
mod popup;
pub(crate) mod publish;
mod registrar;
mod runtime;
mod session;
mod snapshot;

pub use domain::{Item, ItemId, ItemKind, Menu, Section, SectionId, Update};
pub use error::Error;
pub use plugin::{Configuration, Progress, Readiness};
pub use registrar::Registrar;
pub use runtime::Runtime;
pub use session::Session;

/// Installs the companion independently of the menu command runtime.
#[tracing::instrument(name = "hyprbaric::global_menu::install", skip_all, err)]
pub async fn install_companion(configuration: &Configuration) -> Result<Readiness, plugin::Error> {
    plugin::install(configuration).await
}

#[cfg(test)]
mod tests;
