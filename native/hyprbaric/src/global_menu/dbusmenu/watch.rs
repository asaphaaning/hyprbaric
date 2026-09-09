//! Watch D-BusMenu layouts without announcing another popup open.
use super::dbusmenu;
use crate::global_menu::{
    Error,
    endpoint::Endpoint,
    live::{
        State,
        watch::{recv, settle},
    },
};
use tokio::sync::watch;
use zbus::Connection;
pub(in crate::global_menu) async fn run(
    state: &State,
    epoch: u64,
    current: &mut watch::Receiver<u64>,
    connection: &Connection,
    endpoint: &Endpoint,
) -> Result<(), Error> {
    let proxy = dbusmenu(connection, endpoint).await?;
    let mut layout = proxy.receive_layout_updated().await.ok();
    let mut properties = proxy.receive_items_properties_updated().await.ok();

    loop {
        tokio::select! {
            _ = current.changed() => {
                if *current.borrow() != epoch {
                    return Ok(());
                }
            }
            _ = recv(&mut layout) => {}
            _ = recv(&mut properties) => {}
        }

        if !settle(current, epoch, &mut layout, &mut properties).await {
            return Ok(());
        }

        state.replace(epoch, connection, endpoint).await?;
    }
}
