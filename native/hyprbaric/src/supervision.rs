//! Supervised application transport and output services.

use std::{future, time::Duration};

use ::rinf::dart_shutdown;
use rinf_router::{Router, handler::Handler};
use supervised::{self, Context, ServiceExt, service_fn};
use tower::ServiceBuilder;
use tracing::instrument;

use crate::{
    app::{App, Output},
    transport::rinf::{
        self, activate_shortcut, handle_app_launch_request, handle_app_launcher_query,
        handle_appearance_command, handle_audio_command, handle_brightness_set_level,
        handle_caffeine_set_enabled, handle_clock_calendar_request, handle_color_pick_request,
        handle_module_command, handle_network_connect_request, handle_network_scan_request,
        handle_network_set_wifi_enabled, handle_network_settings_request,
        handle_night_light_set_enabled, handle_night_light_set_temperature,
        handle_notification_clear_request, handle_notification_dismiss_request,
        handle_notification_dnd_request, handle_power_set_profile, handle_recording_request,
        handle_schedule_command, handle_screenshot_capture_request, handle_session_command,
        handle_setup_command, handle_shortcut_settings_request, handle_tray_activate_request,
        handle_tray_menu_item_activate_request, handle_workspace_settings_command,
        handle_workspace_switch,
    },
};

/// Builds the complete process supervisor.
pub fn builder(context: App) -> supervised::SupervisorBuilder<App> {
    supervised::SupervisorBuilder::new(context)
        .shutdown_timeout(Duration::from_secs(5))
        .add(service_fn("hyprbaric.router", router).until_cancelled())
        .add(service_fn("hyprbaric.dart-shutdown", dart_shutdown_listener).until_cancelled())
        .add(service_fn("hyprbaric.hyprland", hyprland_listener).until_cancelled())
        .add(service_fn("hyprbaric.shortcuts", shortcut_registry).until_cancelled())
        .add(service_fn("hyprbaric.shortcut-install", shortcut_install).until_cancelled())
        .add(service_fn("hyprbaric.output", output_forwarder).until_cancelled())
}

#[instrument(name = "hyprbaric::transport::rinf::router", skip_all)]
async fn router(ctx: Context<App>) -> supervised::ServiceOutcome {
    let context = ctx.into_inner();

    Router::new()
        .route(logged(handle_workspace_switch))
        .route(logged(handle_session_command))
        .route(logged(handle_app_launcher_query))
        .route(logged(handle_app_launch_request))
        .route(logged(handle_appearance_command))
        .route(logged(handle_setup_command))
        .route(logged(handle_module_command))
        .route(logged(handle_workspace_settings_command))
        .route(logged(handle_network_scan_request))
        .route(logged(handle_network_set_wifi_enabled))
        .route(logged(handle_network_connect_request))
        .route(logged(handle_network_settings_request))
        .route(logged(handle_notification_dismiss_request))
        .route(logged(handle_notification_clear_request))
        .route(logged(handle_notification_dnd_request))
        .route(logged(handle_audio_command))
        .route(logged(handle_brightness_set_level))
        .route(logged(handle_caffeine_set_enabled))
        .route(logged(handle_night_light_set_enabled))
        .route(logged(handle_night_light_set_temperature))
        .route(logged(handle_schedule_command))
        .route(logged(handle_power_set_profile))
        .route(logged(handle_recording_request))
        .route(logged(handle_screenshot_capture_request))
        .route(logged(handle_color_pick_request))
        .route(logged(handle_tray_activate_request))
        .route(logged(handle_tray_menu_item_activate_request))
        .route(logged(handle_clock_calendar_request))
        .route(logged(handle_shortcut_settings_request))
        .with_state::<()>(context)
        .run()
        .await;

    supervised::ServiceOutcome::requested_shutdown()
}

fn logged<H, T, S>(handler: H) -> impl Handler<T, S, Signal = H::Signal> + Sync + 'static
where
    H: Handler<T, S> + Clone + Send + Sync + 'static,
    H::Signal: Send + Sync + 'static,
    H::Future: Send + 'static,
    S: Clone + Send + Sync + 'static,
    T: Send + Sync + 'static,
{
    handler.layer(ServiceBuilder::new().map_request(|request: H::Signal| {
        tracing::debug!(
            request = %std::any::type_name::<H::Signal>(),
            "Processing RINF request"
        );
        request
    }))
}

#[instrument(name = "hyprbaric::transport::rinf::dart_shutdown", skip_all)]
async fn dart_shutdown_listener(_ctx: Context<App>) -> supervised::ServiceOutcome {
    dart_shutdown().await;
    supervised::ServiceOutcome::requested_shutdown()
}

#[instrument(name = "hyprbaric::hyprland::service", skip_all)]
async fn hyprland_listener(ctx: Context<App>) -> supervised::ServiceOutcome {
    let app = ctx.into_inner();

    match app.listen_hyprland().await {
        Ok(()) => supervised::ServiceOutcome::completed(),
        Err(error) => {
            tracing::error!(%error, "Hyprland listener stopped");
            supervised::ServiceOutcome::failed(error.to_string())
        }
    }
}

#[instrument(name = "hyprbaric::shortcuts::service", skip_all)]
async fn shortcut_registry(ctx: Context<App>) -> supervised::ServiceOutcome {
    let registry = ctx.into_inner().shortcuts();

    match registry.run().await {
        Ok(()) => supervised::ServiceOutcome::completed(),
        Err(error) => {
            tracing::error!(%error, "Shortcut registry stopped");
            supervised::ServiceOutcome::failed(error.to_string())
        }
    }
}

#[instrument(name = "hyprbaric::shortcuts::install", skip_all)]
async fn shortcut_install(ctx: Context<App>) -> supervised::ServiceOutcome {
    let context = ctx.into_inner();
    let config = context.shortcut_configuration();

    if let Err(error) = context.shortcuts().sync(config.specs()).await {
        tracing::warn!("Failed to install shortcuts: {error}");
    }

    future::pending().await
}

#[instrument(name = "hyprbaric::app::output", skip_all)]
async fn output_forwarder(ctx: Context<App>) -> supervised::ServiceOutcome {
    let context = ctx.into_inner();
    let mut subscriptions = context.subscriptions();

    loop {
        let output = subscriptions.next().await;

        match &output {
            Output::Desktop(snapshot) => {
                context.set_desktop(snapshot.clone()).await;
            }
            Output::Shortcut(event) => {
                tracing::debug!(shortcut = %event.shortcut, "Shortcut activated");
                activate_shortcut(context.clone(), event.shortcut).await;
                continue;
            }
            _ => {}
        }

        rinf::publish(&output);
    }
}
