//! Screenshot capture runtime.
//!
//! [`Screenshots`] is the small public handle used by the bar. Domain values
//! live in [`domain`], process/filesystem boundaries live in [`backend`], and
//! RINF projections live in [`signal`].

mod backend;
mod domain;
mod signal;

use std::sync::Arc;

use tokio::{
    sync::broadcast,
    time::{self, Duration},
};
use tracing::instrument;

use self::backend::Backend;

pub use domain::{Area, Clipboard, Command, Failure, Mode, Report, Saved};

pub type Handle = Arc<Screenshots>;

/// Live screenshot command entrypoint.
#[derive(Debug)]
pub struct Screenshots {
    results: broadcast::Sender<Report>,
    backend: Backend,
}

impl Screenshots {
    /// Creates the screenshot runtime handle.
    pub fn new() -> Handle {
        let (results, _) = broadcast::channel(16);
        Arc::new(Self {
            results,
            backend: Backend,
        })
    }

    /// Subscribes to screenshot command reports.
    pub fn subscribe_results(&self) -> broadcast::Receiver<Report> {
        self.results.subscribe()
    }

    /// Captures a screenshot for the selected [`Mode`].
    #[instrument(skip(self))]
    pub fn capture(self: &Arc<Self>, mode: Mode) {
        let screenshots = Arc::clone(self);
        tokio::spawn(async move {
            screenshots.run(Command::Capture(mode)).await;
        });
    }

    #[instrument(skip(self))]
    async fn run(&self, command: Command) {
        drop(self.results.send(Report::started(command)));

        let report =
            match time::timeout(Duration::from_secs(30), self.backend.capture(command)).await {
                Ok(Ok(saved)) => Report::saved(command, saved),
                Ok(Err(Failure::Cancelled)) => {
                    tracing::debug!("Screenshot selection cancelled");
                    Report::cancelled(command)
                }
                Ok(Err(failure)) => {
                    tracing::error!(%failure,"Screenshot capture failed");
                    Report::failed(command, failure)
                }
                Err(_) => {
                    tracing::error!("Screenshot capture timed out");
                    Report::failed(command, Failure::Timeout)
                }
            };

        drop(self.results.send(report));
    }
}
