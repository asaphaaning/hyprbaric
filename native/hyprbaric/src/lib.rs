#![recursion_limit = "256"]

//! Hyprbaric native application.

mod app;
mod appearance;
mod audio;
mod bootstrap;
mod brightness;
mod caffeine;
mod capabilities;
mod clock;
mod color_picker;
mod config;
mod global_menu;
mod hyprland;
mod launcher;
mod modules;
mod network;
mod night_light;
mod notifications;
mod portals;
mod power;
mod recording;
mod schedule;
mod screenshot;
mod session;
mod setup;
mod shortcuts;
mod signals;
mod supervision;
mod telemetry;
mod transport;
mod tray;
mod workspaces;

async fn run() -> Result<(), Error> {
    let config = config::Configuration::load()?;

    if let Err(error) = global_menu::load_companion(&config.global_menu).await {
        tracing::warn!(%error, "Could not load the configured AppMenu companion");
    }

    let bootstrap::Started { app, initial } = bootstrap::boot(&config).await?;

    for output in initial.into_outputs() {
        transport::rinf::publish(&output);
    }

    let summary = supervision::builder(app).build().run().await?;
    tracing::info!(cause = ?summary.shutdown_cause(), "Hyprbaric supervisor stopped");

    Ok(())
}

#[derive(Debug, thiserror::Error)]
enum Error {
    #[error("failed to load Hyprbaric configuration")]
    Configuration(#[from] config::Error),
    #[error("failed to bootstrap the Hyprbaric application")]
    Bootstrap(#[from] bootstrap::Error),
    #[error("Hyprbaric supervisor failed")]
    Supervisor(#[from] supervised::Error),
}

#[tokio::main(flavor = "current_thread")]
pub async fn start() {
    telemetry::init();

    if let Err(error) = run().await {
        tracing::error!(%error, "Hyprbaric native application failed");
    }
}
