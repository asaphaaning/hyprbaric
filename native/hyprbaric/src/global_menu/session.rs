//! Window-bound menu ownership. Exporter-local IDs never escape their session.

use std::sync::{Mutex, OnceLock};

use crate::hyprland::WindowId;

use super::{Endpoint, Error};

/// A menu generation captured for one focused window.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Session {
    /// Native generation, independent of layout refreshes.
    pub generation: u64,
    /// Window whose actions this session may invoke.
    pub window: WindowId,
}

/// The endpoint retained for a session, including GTK window action paths.
struct Binding {
    session: Session,
    endpoint: Endpoint,
}

/// The process has at most one focused menu session.
#[derive(Default)]
struct Sessions {
    next: u64,
    active: Option<Binding>,
}

impl Sessions {
    fn bind(&mut self, window: WindowId, endpoint: Endpoint) -> (Session, bool) {
        if let Some(binding) = &self.active
            && binding.session.window == window
            && binding.endpoint == endpoint
        {
            return (binding.session.clone(), false);
        }

        self.next += 1;
        let session = Session {
            generation: self.next,
            window,
        };
        self.active = Some(Binding {
            session: session.clone(),
            endpoint,
        });
        (session, true)
    }

    fn resolve(&self, session: &Session) -> Result<Endpoint, Error> {
        self.active
            .as_ref()
            .filter(|binding| binding.session == *session)
            .map(|binding| binding.endpoint.clone())
            .ok_or(Error::StaleSession)
    }
}

fn sessions() -> std::sync::MutexGuard<'static, Sessions> {
    static SESSIONS: OnceLock<Mutex<Sessions>> = OnceLock::new();
    SESSIONS
        .get_or_init(Mutex::default)
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner)
}

pub(super) fn bind(window: WindowId, endpoint: Endpoint) -> (Session, bool) {
    sessions().bind(window, endpoint)
}

pub(super) fn resolve(session: &Session) -> Result<Endpoint, Error> {
    sessions().resolve(session)
}

pub(super) fn current(endpoint: &Endpoint) -> Option<Session> {
    sessions()
        .active
        .as_ref()
        .filter(|binding| binding.endpoint == *endpoint)
        .map(|binding| binding.session.clone())
}

pub(super) async fn clear() {
    sessions().active = None;
    super::live::clear().await;
}

#[cfg(test)]
mod tests {
    use super::{Endpoint, Error, Sessions, WindowId};

    fn endpoint(window: &str) -> Endpoint {
        Endpoint::Gtk {
            address: None,
            service: ":1.42".into(),
            path: "/Menu".into(),
            app_menu_path: None,
            application_path: Some("/App".into()),
            window_path: Some(window.into()),
            xid: None,
        }
    }

    #[test]
    fn shared_menubar_with_different_window_actions_replaces_the_session() {
        let mut sessions = Sessions::default();
        let window = WindowId::new("0x1".into()).expect("nonempty address");
        let (first, _) = sessions.bind(window.clone(), endpoint("/Window1"));
        let (second, changed) = sessions.bind(window, endpoint("/Window2"));
        assert!(changed);
        assert_ne!(first, second);
        assert!(matches!(sessions.resolve(&first), Err(Error::StaleSession)));
        assert_eq!(sessions.resolve(&second).unwrap(), endpoint("/Window2"));
    }

    #[test]
    fn returning_to_an_exporter_does_not_revive_old_requests() {
        let mut sessions = Sessions::default();
        let window = WindowId::new("0x1".into()).expect("nonempty address");
        let (first, _) = sessions.bind(window.clone(), endpoint("/Window1"));
        sessions.active = None;
        let (second, _) = sessions.bind(window, endpoint("/Window1"));
        assert_ne!(first, second);
        assert!(sessions.resolve(&first).is_err());
    }
}
