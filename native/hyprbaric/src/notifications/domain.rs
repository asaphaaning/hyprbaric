//! Notification domain vocabulary and state transitions.
//!
//! Raw D-Bus traffic is converted into [`Event`] values before it reaches this
//! module. The model only owns notification concepts: visible entries,
//! replacement, dismissal, and invalidation.

use std::time::Duration;

const MAX_ENTRIES: usize = 24;

/// A notification command requested by Flutter.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Command {
    /// Dismiss one notification.
    Dismiss(NotificationId),
    /// Clear all visible notifications.
    Clear,
    /// Toggle Hyprbaric's do-not-disturb mode.
    SetDoNotDisturb(bool),
}

/// One typed notification integration event.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Event {
    /// A notification integration accepted one notification.
    Received {
        /// Notification-server-assigned ID.
        id: NotificationId,
        /// Notification content normalized at the D-Bus boundary.
        pending: Pending,
    },
    /// The active integration reported that a notification closed.
    Closed(NotificationId),
    /// Every visible notification became invalid at once.
    Invalidated,
}

/// UI-facing notification snapshot.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Snapshot {
    /// Whether notification integration is available.
    pub available: bool,
    /// Visible notifications, newest first.
    pub entries: Vec<Entry>,
    /// Count rendered by the notification bell.
    pub unread_count: u32,
    /// Whether Hyprbaric is currently suppressing notification UI.
    pub dnd_enabled: bool,
    /// Optional unavailable or failure copy.
    pub message: Option<String>,
}

/// One visible notification.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Entry {
    /// Notification daemon ID.
    pub id: NotificationId,
    /// Display application name.
    pub app: String,
    /// Display message copy.
    pub message: String,
    /// Creation time in Unix milliseconds.
    pub created_at_ms: u64,
    /// Urgency hint.
    pub urgency: Urgency,
}

/// A notification daemon ID.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct NotificationId(u32);

/// Notification urgency.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash)]
pub enum Urgency {
    /// Low urgency.
    Low,
    /// Normal urgency.
    #[default]
    Normal,
    /// Critical urgency.
    Critical,
}

/// Normalized notification data before it becomes a visible entry.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Pending {
    app: String,
    message: String,
    replaces_id: Option<NotificationId>,
    created_at_ms: u64,
    urgency: Urgency,
}

/// Lifetime requested by a notification client.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) enum Lifetime {
    /// Let the server choose when the notification expires.
    ServerDefault,
    /// Keep the notification until it is explicitly closed.
    Persistent,
    /// Expire the notification after the requested duration.
    After(Duration),
}

/// The notification center model.
#[derive(Clone, Debug, Default)]
pub(super) struct Model {
    entries: Vec<Entry>,
    dnd_enabled: bool,
}

impl Snapshot {
    /// Creates an available empty snapshot.
    pub fn empty() -> Self {
        Self {
            available: true,
            entries: Vec::new(),
            unread_count: 0,
            dnd_enabled: false,
            message: None,
        }
    }

    /// Creates an unavailable snapshot.
    pub fn unavailable(message: impl Into<String>) -> Self {
        Self {
            available: false,
            entries: Vec::new(),
            unread_count: 0,
            dnd_enabled: false,
            message: Some(message.into()),
        }
    }
}

impl NotificationId {
    /// Creates a notification ID.
    pub const fn new(value: u32) -> Self {
        Self(value)
    }

    /// Returns the daemon ID value.
    pub const fn as_u32(self) -> u32 {
        self.0
    }
}

impl Urgency {
    /// Converts a Freedesktop urgency hint into domain urgency.
    pub const fn from_hint(value: u8) -> Self {
        match value {
            0 => Self::Low,
            2 => Self::Critical,
            _ => Self::Normal,
        }
    }
}

impl Pending {
    /// Creates a pending notification from boundary data.
    pub fn new(
        app: impl Into<String>,
        summary: &str,
        body: &str,
        replaces_id: Option<NotificationId>,
        created_at_ms: u64,
        urgency: Urgency,
    ) -> Self {
        Self {
            app: display_app(&app.into()),
            message: compose_message(summary, body),
            replaces_id,
            created_at_ms,
            urgency,
        }
    }
}

impl Lifetime {
    /// Parses the Freedesktop `expire_timeout` value.
    pub(super) fn from_milliseconds(value: i32) -> Self {
        match value {
            value if value > 0 => Self::After(Duration::from_millis(value as u64)),
            0 => Self::Persistent,
            _ => Self::ServerDefault,
        }
    }

    /// Returns the explicit expiry duration, if the client supplied one.
    pub(super) const fn duration(self) -> Option<Duration> {
        match self {
            Self::After(duration) => Some(duration),
            Self::ServerDefault | Self::Persistent => None,
        }
    }
}

impl Model {
    /// Applies one notification event and returns a changed snapshot.
    pub(super) fn apply(&mut self, event: Event) -> Option<Snapshot> {
        match event {
            Event::Received { id, pending } => {
                self.insert(id, pending);
                Some(self.snapshot())
            }
            Event::Closed(id) => self.dismiss(id),
            Event::Invalidated => {
                if self.entries.is_empty() {
                    None
                } else {
                    self.entries.clear();
                    Some(self.snapshot())
                }
            }
        }
    }

    /// Removes one visible notification and returns a changed snapshot.
    pub(super) fn dismiss(&mut self, id: NotificationId) -> Option<Snapshot> {
        self.remove(id).then(|| self.snapshot())
    }

    /// Sets do-not-disturb mode and returns a changed snapshot.
    pub(super) fn set_dnd(&mut self, enabled: bool) -> Option<Snapshot> {
        if self.dnd_enabled == enabled {
            return None;
        }
        self.dnd_enabled = enabled;
        if enabled {
            self.entries.clear();
        }
        Some(self.snapshot())
    }

    fn insert(&mut self, id: NotificationId, pending: Pending) {
        if self.dnd_enabled {
            return;
        }
        if let Some(replaces_id) = pending.replaces_id {
            self.remove(replaces_id);
        }
        self.remove(id);
        self.entries.insert(
            0,
            Entry {
                id,
                app: pending.app,
                message: pending.message,
                created_at_ms: pending.created_at_ms,
                urgency: pending.urgency,
            },
        );
        self.entries.truncate(MAX_ENTRIES);
    }

    fn remove(&mut self, id: NotificationId) -> bool {
        let previous_len = self.entries.len();
        self.entries.retain(|entry| entry.id != id);
        previous_len != self.entries.len()
    }

    fn snapshot(&self) -> Snapshot {
        Snapshot {
            available: true,
            entries: if self.dnd_enabled {
                Vec::new()
            } else {
                self.entries.clone()
            },
            unread_count: if self.dnd_enabled {
                0
            } else {
                self.entries.len() as u32
            },
            dnd_enabled: self.dnd_enabled,
            message: None,
        }
    }
}

fn display_app(value: &str) -> String {
    normalize_text(value).unwrap_or_else(|| "Notification".to_string())
}

fn compose_message(summary: &str, body: &str) -> String {
    let summary = normalize_text(summary);
    let body = normalize_text(body);
    match (summary, body) {
        (Some(summary), Some(body)) if summary.eq_ignore_ascii_case(&body) => summary,
        (Some(summary), Some(body)) => format!("{summary} — {body}"),
        (Some(summary), None) => summary,
        (None, Some(body)) => body,
        (None, None) => "No details".to_string(),
    }
}

fn normalize_text(value: &str) -> Option<String> {
    let stripped = strip_markup(value);
    let collapsed = stripped.split_whitespace().collect::<Vec<_>>().join(" ");
    let trimmed = collapsed.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(html_unescape(trimmed))
    }
}

fn strip_markup(value: &str) -> String {
    let mut output = String::with_capacity(value.len());
    let mut inside_tag = false;
    for ch in value.chars() {
        match ch {
            '<' => inside_tag = true,
            '>' => inside_tag = false,
            _ if !inside_tag => output.push(ch),
            _ => {}
        }
    }
    output
}

fn html_unescape(value: &str) -> String {
    value
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use super::{
        Event, Lifetime, Model, NotificationId, Pending, Urgency, compose_message, normalize_text,
    };

    #[test]
    fn lifetime_preserves_freedesktop_timeout_meaning() {
        assert_eq!(Lifetime::from_milliseconds(-1), Lifetime::ServerDefault);
        assert_eq!(Lifetime::from_milliseconds(0), Lifetime::Persistent);
        assert_eq!(
            Lifetime::from_milliseconds(2500),
            Lifetime::After(Duration::from_millis(2500))
        );
    }

    #[test]
    fn hosted_notifications_enter_the_model_without_reply_correlation() {
        let mut model = Model::default();

        let snapshot = model
            .apply(Event::Received {
                id: NotificationId::new(4),
                pending: Pending::new("Mail", "New message", "", None, 1, Urgency::Normal),
            })
            .unwrap();

        assert_eq!(snapshot.entries.len(), 1);
        assert_eq!(snapshot.entries[0].id, NotificationId::new(4));
        assert_eq!(snapshot.entries[0].app, "Mail");
    }

    #[test]
    fn compose_message_prefers_a_single_line_payload() {
        assert_eq!(
            compose_message("Slack", "Maya pinged you"),
            "Slack — Maya pinged you"
        );
        assert_eq!(compose_message("Slack", "slack"), "Slack");
        assert_eq!(compose_message("Slack", ""), "Slack");
        assert_eq!(compose_message("", "Ping"), "Ping");
        assert_eq!(compose_message("", ""), "No details");
    }

    #[test]
    fn normalize_text_strips_markup_entities_and_whitespace() {
        assert_eq!(
            normalize_text(" <b>Hello</b> &amp; <i>bye</i>\nagain "),
            Some("Hello & bye again".to_string())
        );
        assert_eq!(normalize_text("   "), None);
    }

    #[test]
    fn replacement_keeps_newest_notification_first() {
        let mut model = Model::default();
        model.apply(received(7, "Slack", "One", None, 1, Urgency::Normal));
        let snapshot = model
            .apply(received(
                8,
                "Slack",
                "Two",
                Some(NotificationId::new(7)),
                2,
                Urgency::Critical,
            ))
            .unwrap();

        assert_eq!(snapshot.entries.len(), 1);
        assert_eq!(snapshot.entries[0].id, NotificationId::new(8));
        assert_eq!(snapshot.entries[0].message, "Two");
        assert_eq!(snapshot.entries[0].urgency, Urgency::Critical);
    }

    #[test]
    fn model_truncates_to_max_entries() {
        let mut model = Model::default();
        for index in 0..30 {
            model.apply(received(
                index,
                "App",
                &format!("Notification {index}"),
                None,
                u64::from(index),
                Urgency::Normal,
            ));
        }

        let snapshot = model.snapshot();

        assert_eq!(snapshot.entries.len(), 24);
        assert_eq!(snapshot.unread_count, 24);
        assert_eq!(snapshot.entries[0].id, NotificationId::new(29));
    }

    #[test]
    fn invalidation_clears_visible_entries() {
        let mut model = Model::default();
        model.apply(received(1, "App", "Message", None, 1, Urgency::Normal));

        let snapshot = model.apply(Event::Invalidated).unwrap();

        assert!(snapshot.entries.is_empty());
        assert_eq!(snapshot.unread_count, 0);
        assert_eq!(model.apply(Event::Invalidated), None);
    }

    #[test]
    fn close_removes_one_entry_and_ignores_unknown_ids() {
        let mut model = Model::default();
        model.apply(received(1, "App", "One", None, 1, Urgency::Normal));
        model.apply(received(2, "App", "Two", None, 2, Urgency::Normal));

        let snapshot = model.dismiss(NotificationId::new(1)).unwrap();

        assert_eq!(snapshot.entries.len(), 1);
        assert_eq!(snapshot.entries[0].id, NotificationId::new(2));
        assert_eq!(model.dismiss(NotificationId::new(99)), None);
    }

    #[test]
    fn dnd_drops_visible_notifications_and_hides_status() {
        let mut model = Model::default();
        model.apply(received(1, "App", "One", None, 1, Urgency::Normal));

        let snapshot = model.set_dnd(true).unwrap();

        assert!(snapshot.dnd_enabled);
        assert!(snapshot.entries.is_empty());
        assert_eq!(snapshot.unread_count, 0);
        assert!(model.entries.is_empty());
    }

    #[test]
    fn dnd_discards_notifications_received_while_enabled() {
        let mut model = Model::default();
        model.set_dnd(true);
        let suppressed = model
            .apply(received(1, "App", "Suppressed", None, 1, Urgency::Normal))
            .unwrap();

        assert!(suppressed.entries.is_empty());
        assert_eq!(suppressed.unread_count, 0);

        let resumed = model.set_dnd(false).unwrap();

        assert!(!resumed.dnd_enabled);
        assert!(resumed.entries.is_empty());

        let visible = model
            .apply(received(2, "App", "Visible", None, 2, Urgency::Normal))
            .unwrap();

        assert_eq!(visible.entries.len(), 1);
        assert_eq!(visible.entries[0].message, "Visible");
        assert_eq!(visible.unread_count, 1);
    }

    fn received(
        id: u32,
        app: &str,
        body: &str,
        replaces_id: Option<NotificationId>,
        created_at_ms: u64,
        urgency: Urgency,
    ) -> Event {
        Event::Received {
            id: NotificationId::new(id),
            pending: Pending::new(app, body, "", replaces_id, created_at_ms, urgency),
        }
    }
}
