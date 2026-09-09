//! Resolve a focused window through companion facts, parents, and registrar entries.
use super::{Error, endpoint::Endpoint, registrar};
use hyprland::{data::Client, prelude::HyprDataActiveOptional};
use std::{
    collections::{HashMap, HashSet},
    env,
    process::Stdio,
};
use tokio::process::Command;
#[tracing::instrument(name = "hyprbaric::global_menu::discovery", skip_all)]
pub(in crate::global_menu) async fn focused_endpoint() -> Result<Endpoint, Error> {
    let client = Client::get_active_async()
        .await
        .map_err(Error::FocusedWindow)?
        .ok_or(Error::NoFocusedWindow)?;
    let address = client.address.to_string();
    let pid = u32::try_from(client.pid).ok().filter(|pid| *pid > 0);
    let (endpoints, companion_missing) = match companion_endpoints().await {
        Ok(endpoints) => (endpoints, false),
        Err(Error::CompanionUnavailable) => (Vec::new(), true),
        Err(error) => return Err(error),
    };

    for window in lineage(&address, &endpoints) {
        if let Some(endpoint) = menu_for_address(&endpoints, window) {
            if window != address {
                tracing::debug!(
                    focused = %address,
                    parent = %window,
                    service = %endpoint.service(),
                    path = %endpoint.path(),
                    "Resolved the focused dialog through its parent window"
                );
            }
            return Ok(endpoint.clone());
        }

        let xid = xid_of(&endpoints, window);
        if let Some(registration) = registrar::lookup(xid.map(registrar::WindowId), None) {
            tracing::debug!(
                focused = %address,
                %window,
                xid,
                service = %registration.service,
                path = %registration.path,
                "Resolved the window through the AppMenu registrar"
            );
            return Ok(Endpoint::from_registrar(window.to_owned(), registration));
        }
    }

    if let Some(registration) = registrar::lookup(None, pid) {
        tracing::debug!(
            %address,
            pid,
            service = %registration.service,
            path = %registration.path,
            "Resolved the focused window through the AppMenu registrar"
        );
        return Ok(Endpoint::from_registrar(address, registration));
    }

    if let Some(pid) = pid {
        if let Some(endpoint) = menu_for_process(&endpoints, pid).await {
            tracing::debug!(
                %address,
                pid,
                service = %endpoint.service(),
                path = %endpoint.path(),
                "Resolved the focused window through its D-Bus process"
            );
            return Ok(endpoint);
        }
    }

    if companion_missing {
        return Err(Error::CompanionUnavailable);
    }

    Err(Error::NoMenuForFocusedWindow)
}

pub(in crate::global_menu) fn menu_for_address<'a>(
    endpoints: &'a [Endpoint],
    address: &str,
) -> Option<&'a Endpoint> {
    endpoints
        .iter()
        .find(|endpoint| endpoint.exposes_menu() && endpoint.address() == Some(address))
}

/// Focused window, then each mapped parent the companion named.
///
/// Cycles are cut. A dialog with no `parent()` row stays a one-element line.
pub(in crate::global_menu) fn lineage<'a>(
    start: &'a str,
    endpoints: &'a [Endpoint],
) -> Vec<&'a str> {
    let mut line = Vec::new();
    let mut seen = HashSet::new();
    let mut current = start;

    loop {
        if !seen.insert(current) {
            break;
        }
        line.push(current);
        match parent_of(endpoints, current) {
            Some(parent) => current = parent,
            None => break,
        }
    }

    line
}

pub(in crate::global_menu) fn parent_of<'a>(
    endpoints: &'a [Endpoint],
    address: &str,
) -> Option<&'a str> {
    endpoints.iter().find_map(|endpoint| {
        (endpoint.address() == Some(address))
            .then_some(endpoint.parent())
            .flatten()
            .filter(|parent| !parent.is_empty() && *parent != address)
    })
}

pub(in crate::global_menu) fn xid_of(endpoints: &[Endpoint], address: &str) -> Option<u32> {
    endpoints.iter().find_map(|endpoint| {
        (endpoint.address() == Some(address))
            .then_some(endpoint.xid())
            .flatten()
    })
}

/// GTK often publishes a menu before Hyprland has named the window, so the
/// companion snapshot has the D-Bus address and no compositor address. When
/// exactly one such menu belongs to the focused process, that is the window.
pub(in crate::global_menu) async fn menu_for_process(
    endpoints: &[Endpoint],
    pid: u32,
) -> Option<Endpoint> {
    let connection = zbus::Connection::session().await.ok()?;
    let mut pids = HashMap::new();
    for endpoint in endpoints {
        if !endpoint.exposes_menu() || endpoint.address().is_some() {
            continue;
        }
        if let std::collections::hash_map::Entry::Vacant(entry) =
            pids.entry(endpoint.service().to_owned())
        {
            if let Some(found) = process_id(&connection, endpoint.service()).await {
                entry.insert(found);
            }
        }
    }

    unique_unaddressed(endpoints, pid, |service| pids.get(service).copied()).cloned()
}

pub(in crate::global_menu) async fn process_id(
    connection: &zbus::Connection,
    service: &str,
) -> Option<u32> {
    let proxy = zbus::fdo::DBusProxy::new(connection).await.ok()?;
    let name = zbus::names::BusName::try_from(service).ok()?;
    proxy.get_connection_unix_process_id(name).await.ok()
}

pub(in crate::global_menu) fn unique_unaddressed<'a>(
    endpoints: &'a [Endpoint],
    pid: u32,
    pid_of: impl Fn(&str) -> Option<u32>,
) -> Option<&'a Endpoint> {
    let mut matches = endpoints.iter().filter(|endpoint| {
        endpoint.exposes_menu()
            && endpoint.address().is_none()
            && pid_of(endpoint.service()) == Some(pid)
    });
    let first = matches.next()?;
    matches.next().is_none().then_some(first)
}

pub(in crate::global_menu) async fn companion_endpoints() -> Result<Vec<Endpoint>, Error> {
    let mut command = Command::new("hyprctl");
    if let Ok(signature) = env::var("HYPRLAND_INSTANCE_SIGNATURE") {
        command.args(["-i", signature.as_str()]);
    }
    let output = command
        .args(["-j", "hyprbaric-appmenu"])
        .stdin(Stdio::null())
        .output()
        .await
        .map_err(Error::QueryPlugin)?;

    if !output.status.success() {
        return Err(Error::PluginRejected {
            status: output.status.code(),
        });
    }

    if String::from_utf8_lossy(&output.stdout)
        .trim()
        .starts_with("unknown request")
    {
        return Err(Error::CompanionUnavailable);
    }

    serde_json::from_slice(&output.stdout).map_err(Error::DecodeEndpoints)
}

pub(in crate::global_menu) async fn focused_list_title() -> String {
    match Client::get_active_async().await {
        Ok(Some(client)) => {
            let class = client.class.trim();
            if !class.is_empty() {
                return class.to_owned();
            }
            let title = client.title.trim();
            if !title.is_empty() {
                return title.to_owned();
            }
        }
        _ => {}
    }

    "Menu".to_owned()
}
