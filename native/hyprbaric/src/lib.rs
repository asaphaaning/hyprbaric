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

    // The global menu has two halves that fail independently. The registrar is
    // immediate and is what makes applications export their menus at all, so it
    // is claimed before the bar boots. Obtaining the compositor companion can
    // mean compiling against Hyprland's headers, so it runs on its own and
    // reports where it got to. Held for the process lifetime: releasing the
    // registrar name gives applications their own menu bars back.
    let global_menu = config
        .global_menu
        .enabled(config.modules.enabled(modules::Module::GlobalMenu));
    let _registrar = match global_menu::Registrar::serve(global_menu).await {
        Ok(registrar) => registrar,
        Err(error) => {
            tracing::warn!(%error, "Could not serve the AppMenu registrar");
            None
        }
    };

    transport::rinf::publish_global_menu_integration(match global_menu {
        true => global_menu::Progress::Preparing,
        false => global_menu::Progress::Disabled,
    });

    if global_menu {
        let configuration = config.global_menu.clone();
        tokio::spawn(async move {
            let progress = match global_menu::install_companion(&configuration).await {
                Ok(readiness) => global_menu::Progress::from(readiness),
                Err(error) => global_menu::Progress::failed(&error),
            };
            transport::rinf::publish_global_menu_integration(progress);
        });
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
