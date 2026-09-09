//! Failures at application menu boundaries.

#[derive(Debug, thiserror::Error)]
pub enum Error {
    /// The request belongs to a focus observation or exporter that has expired.
    #[error("the menu session is no longer current")]
    StaleSession,
    /// An exporter sent a splice outside the subscribed menu.
    #[error("the GTK menu update is outside its current rows")]
    InvalidGtkChange,
    #[error("failed to read the focused Hyprland window")]
    FocusedWindow(#[source] hyprland::error::HyprError),
    #[error("there is no focused Hyprland window")]
    NoFocusedWindow,
    #[error("failed to query the Hyprbaric AppMenu companion")]
    QueryPlugin(#[source] std::io::Error),
    #[error("the Hyprbaric AppMenu companion rejected the query with status {status:?}")]
    PluginRejected { status: Option<i32> },
    #[error("the Hyprbaric AppMenu companion is not loaded")]
    CompanionUnavailable,
    #[error("the Hyprbaric AppMenu companion returned invalid JSON")]
    DecodeEndpoints(#[source] serde_json::Error),
    #[error("the focused window does not expose an AppMenu")]
    NoMenuForFocusedWindow,
    #[error("failed to connect to the session bus")]
    Connect(#[source] zbus::Error),
    #[error("failed to create the D-BusMenu proxy")]
    CreateProxy(#[source] zbus::Error),
    #[error("failed to read the D-BusMenu layout")]
    Layout(#[source] zbus::Error),
    #[error("failed to create the GTK menu proxy")]
    CreateGtkProxy(#[source] zbus::Error),
    #[error("failed to read the GTK menu layout")]
    GtkLayout(#[source] zbus::Error),
    #[error("the GTK menu omitted group {group}, menu {menu}")]
    MissingGtkGroup { group: u32, menu: u32 },
    #[error("the GTK action `{action}` names no reachable action group")]
    UnscopedGtkAction { action: String },
    #[error("the GTK action target could not be decoded")]
    InvalidGtkTarget,
    #[error("the application refused the activation")]
    Activate(#[source] zbus::Error),
    #[error("the application refused the menu event")]
    Event(#[source] zbus::Error),
    #[error("the D-BusMenu layout used an unsupported value")]
    DecodeLayout(#[source] zbus::zvariant::Error),
    #[error("the D-BusMenu layout contained an invalid item")]
    InvalidNode,
}

impl Error {
    /// Records ordinary absence at debug level and real failures once at warning level.
    pub(crate) fn report(&self, operation: &'static str) {
        if self.is_absence() {
            tracing::debug!(error=%self, operation, "Menu request no longer applies");
        } else {
            tracing::warn!(error=%self, operation, "Menu request failed");
        }
    }

    /// Empty workspace, or a window that never published a menu.
    ///
    /// The bar asks on every focus change and retries while a new window
    /// catches up. Those answers are the usual ones, not a fault in the bar.
    pub fn is_absence(&self) -> bool {
        matches!(
            self,
            Self::StaleSession | Self::NoFocusedWindow | Self::NoMenuForFocusedWindow
        )
    }
}

#[cfg(test)]
mod tests {
    use std::{
        io::Write,
        sync::{Arc, Mutex},
    };
    use tracing::instrument::WithSubscriber;
    #[derive(Clone)]
    struct Log(Arc<Mutex<Vec<u8>>>);
    impl Write for Log {
        fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
            self.0.lock().expect("log lock").write(bytes)
        }
        fn flush(&mut self) -> std::io::Result<()> {
            Ok(())
        }
    }
    #[tokio::test]
    async fn expected_menu_outcomes_are_debug_and_real_failures_remain_visible() {
        let log = Log(Arc::default());
        let writer = log.clone();
        let subscriber = tracing_subscriber::fmt()
            .without_time()
            .with_ansi(false)
            .with_max_level(tracing::Level::TRACE)
            .with_writer(move || writer.clone())
            .finish();
        async {
            let mut runtime = crate::global_menu::Runtime::new(|_| {});
            runtime
                .read(None)
                .await
                .expect_err("empty workspace")
                .report("read");
            super::Error::StaleSession.report("activate");
            super::Error::NoMenuForFocusedWindow.report("read");
            super::Error::CompanionUnavailable.report("read");
        }
        .with_subscriber(subscriber)
        .await;
        let output =
            String::from_utf8(log.0.lock().expect("log lock").clone()).expect("UTF-8 logs");
        assert!(!output.contains("ERROR"), "{output}");
        assert_eq!(output.matches("DEBUG").count(), 3, "{output}");
        assert_eq!(output.matches("WARN").count(), 1, "{output}");
        assert!(output.contains("companion is not loaded"), "{output}");
    }
}
