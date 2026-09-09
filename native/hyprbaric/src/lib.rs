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

    let global_menu = config
        .global_menu
        .enabled(config.modules.enabled(modules::Module::GlobalMenu));
    transport::rinf::publish_global_menu_integration(if global_menu {
        global_menu::Progress::Preparing
    } else {
        global_menu::Progress::Disabled
    });
    if global_menu {
        let configuration = config.global_menu.clone();
        tokio::spawn(async move {
            let readiness = global_menu::install_companion(&configuration).await;
            // Claiming the registrar hides native Qt menus. Only do so once
            // their replacement is reachable; a failed install owns nothing.
            let _registrar = if matches!(readiness, Ok(global_menu::Readiness::Ready)) {
                match global_menu::Registrar::serve(true).await {
                    Ok(registrar) => registrar,
                    Err(error) => {
                        tracing::warn!(%error, "Could not serve the AppMenu registrar");
                        transport::rinf::publish_global_menu_integration(
                            global_menu::Progress::Blocked {
                                message: error.to_string(),
                                instruction: None,
                            },
                        );
                        return;
                    }
                }
            } else {
                None
            };
            let progress = match readiness {
                Ok(readiness) => global_menu::Progress::from(readiness),
                Err(error) => global_menu::Progress::failed(&error),
            };
            transport::rinf::publish_global_menu_integration(progress);
            std::future::pending::<()>().await;
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
