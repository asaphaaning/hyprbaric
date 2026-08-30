//! Freedesktop notification monitor boundary.

use std::{
    collections::HashMap,
    sync::Arc,
    thread,
    time::{Duration, SystemTime, UNIX_EPOCH},
};

use dbus::{
    Message, MessageType,
    arg::{PropMap, RefArg},
    blocking::Connection,
    channel::MatchingReceiver,
    message::MatchRule,
};
use tracing::instrument;

use super::{
    Error,
    domain::{Event, NotificationId, Pending, Urgency},
};

const DBUS_BUS: &str = "org.freedesktop.DBus";
const DBUS_PATH: &str = "/org/freedesktop/DBus";
const NOTIFICATIONS_INTERFACE: &str = "org.freedesktop.Notifications";
const NOTIFICATIONS_PATH: &str = "/org/freedesktop/Notifications";
const PROCESS_TIMEOUT: Duration = Duration::from_secs(5);

/// Identity of one client method call on the monitored bus.
#[derive(Clone, Debug, PartialEq, Eq, Hash)]
struct Call {
    client: String,
    serial: u32,
}

/// Correlates observed `Notify` calls with their daemon replies.
#[derive(Default)]
struct Correlation {
    pending: HashMap<Call, Pending>,
}

/// Starts the D-Bus monitor thread.
#[instrument(skip_all, err)]
pub(super) fn spawn(on_event: impl Fn(Event) + Send + Sync + 'static) -> Result<(), Error> {
    let connection = Connection::new_session().map_err(Error::ConnectSessionBus)?;
    become_monitor(&connection)?;

    let on_event = Arc::new(on_event);
    let mut correlation = Correlation::default();
    connection.start_receive(
        MatchRule::new().static_clone(),
        Box::new(move |message, _| {
            if let Some(event) = correlation.accept(&message) {
                on_event(event);
            }
            true
        }),
    );

    thread::Builder::new()
        .name("hyprbaric-notifications".to_string())
        .spawn(move || run(connection))
        .map_err(Error::SpawnWatcher)?;

    Ok(())
}

#[instrument(skip_all, err)]
fn become_monitor(connection: &Connection) -> Result<(), Error> {
    let proxy = connection.with_proxy(DBUS_BUS, DBUS_PATH, PROCESS_TIMEOUT);
    proxy
        .method_call(
            "org.freedesktop.DBus.Monitoring",
            "BecomeMonitor",
            (vec![MatchRule::new().match_str()], 0u32),
        )
        .map_err(Error::BecomeMonitor)
}

#[instrument(skip_all)]
fn run(connection: Connection) {
    loop {
        if let Err(error) = connection.process(PROCESS_TIMEOUT) {
            tracing::warn!("Notification monitor failed: {error}");
        }
    }
}

impl Correlation {
    fn accept(&mut self, message: &Message) -> Option<Event> {
        match message.msg_type() {
            MessageType::MethodCall => {
                let (call, pending) = parse_notify(message)?;
                self.request(call, pending);
                None
            }
            MessageType::MethodReturn => {
                let (call, id) = parse_notify_return(message)?;
                self.assign(call, id)
            }
            MessageType::Signal => self.accept_signal(message),
            MessageType::Error => {
                let call = reply_call(message)?;
                self.pending.remove(&call);
                None
            }
        }
    }

    fn accept_signal(&mut self, message: &Message) -> Option<Event> {
        if message.path().as_deref() == Some(NOTIFICATIONS_PATH)
            && message.interface().as_deref() == Some(NOTIFICATIONS_INTERFACE)
            && message.member().as_deref() == Some("NotificationClosed")
        {
            let (notification_id, _) = message.get2::<u32, u32>();
            return notification_id.map(|id| Event::Closed(NotificationId::new(id)));
        }

        if message.path().as_deref() == Some(DBUS_PATH)
            && message.interface().as_deref() == Some(DBUS_BUS)
            && message.member().as_deref() == Some("NameOwnerChanged")
        {
            let (bus_name, _old_owner, new_owner) = message.get3::<String, String, String>();
            if bus_name.as_deref() == Some(NOTIFICATIONS_INTERFACE) {
                self.invalidate();
                return new_owner
                    .as_deref()
                    .is_some_and(str::is_empty)
                    .then_some(Event::Invalidated);
            }
        }

        None
    }

    fn request(&mut self, call: Call, pending: Pending) {
        self.pending.insert(call, pending);
    }

    fn assign(&mut self, call: Call, id: NotificationId) -> Option<Event> {
        let pending = self.pending.remove(&call)?;
        Some(Event::Received { id, pending })
    }

    fn invalidate(&mut self) {
        self.pending.clear();
    }
}

fn parse_notify(message: &Message) -> Option<(Call, Pending)> {
    if message.path().as_deref() != Some(NOTIFICATIONS_PATH)
        || message.interface().as_deref() != Some(NOTIFICATIONS_INTERFACE)
        || message.member().as_deref() != Some("Notify")
    {
        return None;
    }

    let call = Call {
        client: message.sender()?.to_string(),
        serial: message.get_serial()?,
    };
    let (app_name, replaces_id, _app_icon, summary, body, _actions, hints, _expire_timeout): (
        String,
        u32,
        String,
        String,
        String,
        Vec<String>,
        PropMap,
        i32,
    ) = message.read_all().ok()?;

    Some((
        call,
        Pending::new(
            app_name,
            &summary,
            &body,
            (replaces_id != 0).then(|| NotificationId::new(replaces_id)),
            now_unix_ms(),
            urgency_from_hints(&hints),
        ),
    ))
}

fn parse_notify_return(message: &Message) -> Option<(Call, NotificationId)> {
    Some((
        reply_call(message)?,
        NotificationId::new(message.get1::<u32>()?),
    ))
}

fn reply_call(message: &Message) -> Option<Call> {
    Some(Call {
        client: message.destination()?.to_string(),
        serial: message.get_reply_serial()?,
    })
}

fn urgency_from_hints(hints: &PropMap) -> Urgency {
    hints
        .get("urgency")
        .and_then(|variant| refarg_u8(&*variant.0))
        .map(Urgency::from_hint)
        .unwrap_or_default()
}

fn refarg_u8(value: &dyn RefArg) -> Option<u8> {
    value
        .as_u64()
        .and_then(|value| u8::try_from(value).ok())
        .or_else(|| value.as_i64().and_then(|value| u8::try_from(value).ok()))
}

fn now_unix_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64
}

#[cfg(test)]
mod tests {
    use super::{Call, Correlation, Event, NotificationId, Pending, Urgency};

    #[test]
    fn correlation_distinguishes_clients_with_the_same_serial() {
        let mut correlation = Correlation::default();
        let first = call(":1.10", 4);
        let second = call(":1.11", 4);
        correlation.pending.insert(first.clone(), pending("First"));
        correlation
            .pending
            .insert(second.clone(), pending("Second"));

        let event = correlation.assign(first, NotificationId::new(8)).unwrap();

        assert!(matches!(event, Event::Received { id, .. } if id == NotificationId::new(8)));
        assert!(correlation.pending.contains_key(&second));
    }

    #[test]
    fn invalidation_discards_unanswered_calls() {
        let mut correlation = Correlation::default();
        correlation
            .pending
            .insert(call(":1.10", 4), pending("First"));

        correlation.invalidate();

        assert!(correlation.pending.is_empty());
    }

    fn call(client: &str, serial: u32) -> Call {
        Call {
            client: client.to_owned(),
            serial,
        }
    }

    fn pending(message: &str) -> Pending {
        Pending::new("App", message, "", None, 1, Urgency::Normal)
    }
}
