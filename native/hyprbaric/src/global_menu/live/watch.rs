//! Shared subscription timing and protocol dispatch.
use super::State;
use crate::global_menu::{Error, dbusmenu, endpoint::Endpoint, gtk};
use futures_util::StreamExt;
use std::{future::pending, sync::Arc};
use tokio::sync::watch;
use zbus::Connection;
pub(in crate::global_menu) const DEBOUNCE: std::time::Duration =
    std::time::Duration::from_millis(80);
#[tracing::instrument(name = "hyprbaric::global_menu::watch", skip_all)]
pub(super) async fn run(
    state: Arc<State>,
    epoch: u64,
    connection: Connection,
    endpoint: Endpoint,
) -> Result<(), Error> {
    let mut current = state.generation.subscribe();
    if *current.borrow() != epoch {
        return Ok(());
    }

    match endpoint {
        Endpoint::DbusMenu { .. } => {
            dbusmenu::watch::run(&state, epoch, &mut current, &connection, &endpoint).await
        }
        Endpoint::Gtk { .. } => {
            gtk::watch::run(&state, epoch, &mut current, &connection, &endpoint).await
        }
        Endpoint::X11 { .. } | Endpoint::Parent { .. } => Ok(()),
    }
}

pub(in crate::global_menu) async fn settle3<
    A: StreamExt + Unpin,
    B: StreamExt + Unpin,
    C: StreamExt + Unpin,
>(
    current: &mut watch::Receiver<u64>,
    epoch: u64,
    first: &mut Option<A>,
    second: &mut Option<B>,
    third: &mut Option<C>,
) -> bool {
    let wait = tokio::time::sleep(DEBOUNCE);
    tokio::pin!(wait);
    loop {
        tokio::select! {
            _ = current.changed() => {
                if *current.borrow() != epoch {
                    return false;
                }
            }
            _ = recv(first) => {}
            _ = recv(second) => {}
            _ = recv(third) => {}
            _ = &mut wait => return true,
        }
    }
}

pub(in crate::global_menu) async fn settle<A: StreamExt + Unpin, B: StreamExt + Unpin>(
    current: &mut watch::Receiver<u64>,
    epoch: u64,
    first: &mut Option<A>,
    second: &mut Option<B>,
) -> bool {
    let mut none = Option::<futures_util::stream::Empty<()>>::None;
    settle3(current, epoch, first, second, &mut none).await
}

pub(in crate::global_menu) async fn recv<S: StreamExt + Unpin>(stream: &mut Option<S>) {
    match stream.as_mut() {
        Some(source) => {
            if source.next().await.is_none() {
                *stream = None;
                pending::<()>().await;
            }
        }
        None => pending::<()>().await,
    }
}
