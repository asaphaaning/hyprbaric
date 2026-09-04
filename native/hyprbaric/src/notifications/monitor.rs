//! Freedesktop notification monitor boundary.

use std::{
    collections::{HashMap, VecDeque},
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

/// How many observed `Notify` calls may await a daemon reply at once.
///
/// A reply lands within milliseconds, so this is only a ceiling for calls that
/// will never get one: a sender that set NO_REPLY_EXPECTED, or a reply the
/// monitor never saw. Without it the map grows for the life of the process.
const MAX_PENDING_CALLS: usize = 64;

/// How long the monitor waits after a failed dispatch before trying again.
const RETRY_BACKOFF: Duration = Duration::from_secs(1);

/// How many consecutive dispatch failures end observation.
///
/// `process` returns immediately once the bus is gone, so retrying forever
/// spins a core at full tilt and floods the log.
const MAX_CONSECUTIVE_FAILURES: u32 = 5;

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
    order: VecDeque<Call>,
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
    let mut failures = 0;

    loop {
        match connection.process(PROCESS_TIMEOUT) {
            Ok(_) => failures = 0,
            Err(error) => {
                failures += 1;
                tracing::warn!(failures, "Notification monitor failed: {error}");
                if failures >= MAX_CONSECUTIVE_FAILURES {
                    tracing::error!(
                        "Notification monitor gave up after {failures} consecutive failures"
                    );
                    return;
                }
                // A dead connection fails instantly, so without this the retry
                // loop would busy-spin instead of waiting for the bus.
                thread::sleep(RETRY_BACKOFF);
            }
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
                self.forget(&call);
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
            let (bus_name, old_owner, _new_owner) = message.get3::<String, String, String>();
            if bus_name.as_deref() == Some(NOTIFICATIONS_INTERFACE) {
                self.invalidate();
                // Every visible entry belongs to the owner that just left, so
                // its IDs are meaningless now whether the name was released or
                // handed straight to a replacement. Keeping them would let a
                // dismissal close an unrelated notification on the new daemon.
                return old_owner
                    .as_deref()
                    .is_some_and(|owner| !owner.is_empty())
                    .then_some(Event::Invalidated);
            }
        }

        None
    }

    fn request(&mut self, call: Call, pending: Pending) {
        if self.pending.insert(call.clone(), pending).is_none() {
            self.order.push_back(call);
        }
        while self.order.len() > MAX_PENDING_CALLS {
            if let Some(oldest) = self.order.pop_front() {
                self.pending.remove(&oldest);
            }
        }
    }

    fn assign(&mut self, call: Call, id: NotificationId) -> Option<Event> {
        let pending = self.pending.remove(&call)?;
        self.order.retain(|queued| queued != &call);
        Some(Event::Received { id, pending })
    }

    fn forget(&mut self, call: &Call) {
        self.pending.remove(call);
        self.order.retain(|queued| queued != call);
    }

    fn invalidate(&mut self) {
        self.pending.clear();
        self.order.clear();
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

    #[test]
    fn unanswered_calls_cannot_grow_without_bound() {
        let mut correlation = Correlation::default();

        for serial in 0..(super::MAX_PENDING_CALLS as u32 * 2) {
            correlation.request(call(":1.10", serial), pending("Unanswered"));
        }

        assert_eq!(correlation.pending.len(), super::MAX_PENDING_CALLS);
        assert_eq!(correlation.order.len(), super::MAX_PENDING_CALLS);
        // The oldest is the one that goes.
        assert!(!correlation.pending.contains_key(&call(":1.10", 0)));
        assert!(correlation.pending.contains_key(&call(":1.10", 127)));
    }

    #[test]
    fn answering_a_call_releases_its_queue_slot() {
        let mut correlation = Correlation::default();
        correlation.request(call(":1.10", 4), pending("First"));

        correlation.assign(call(":1.10", 4), NotificationId::new(8));

        assert!(correlation.pending.is_empty());
        assert!(correlation.order.is_empty());
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
