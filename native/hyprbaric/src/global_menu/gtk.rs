//! Join `org.gtk.Menus` items to `org.gtk.Actions`.
//!
//! GTK's own menu tracker does this in-process: the menu names an action and
//! an optional target, and the action group supplies enabled, state, and the
//! Activate parameter. The same rules apply over D-Bus. Accelerators are the
//! optional `accel` attribute; `gtk_application_set_accels_for_action` is not
//! on the bus.

use std::collections::{HashMap, HashSet};

use zbus::{
    proxy,
    zvariant::{
        LE, OwnedValue, Signature, Type, Value,
        serialized::{Context, Data},
        to_bytes,
    },
};

use super::{Item, ItemId, ItemKind, SectionId, gtk_label, gtk_link};

/// Descriptions of the `app.` and `win.` actions a GTK window exported.
#[derive(Clone, Debug, Default)]
pub(super) struct Actions {
    /// Scopes for which `DescribeAll` succeeded (`app`, `win`, or empty).
    described: HashSet<String>,
    by_name: HashMap<String, Action>,
}

/// One `org.gtk.Actions` description: `(bgav)` without the name.
#[derive(Clone, Debug)]
pub(super) struct Action {
    pub enabled: bool,
    pub parameter_type: String,
    pub state: Option<OwnedValue>,
}

enum Lookup<'a> {
    Found(&'a Action),
    Missing,
    Unknown,
}

impl Actions {
    pub(super) fn insert(&mut self, name: String, action: Action) {
        self.by_name.insert(name, action);
    }

    pub(super) fn mark_described(&mut self, scope: &str) {
        self.described.insert(scope.to_owned());
    }

    fn lookup(&self, name: &str) -> Lookup<'_> {
        if let Some(action) = self.by_name.get(name) {
            return Lookup::Found(action);
        }

        let scope = name.split_once('.').map(|(scope, _)| scope).unwrap_or("");
        if self.described.contains(scope) {
            Lookup::Missing
        } else {
            Lookup::Unknown
        }
    }
}

impl Action {
    pub(super) fn from_description(
        enabled: bool,
        parameter_type: Signature,
        mut state: Vec<OwnedValue>,
    ) -> Self {
        Self {
            enabled,
            parameter_type: parameter_type.to_string(),
            state: state.pop(),
        }
    }

    fn accepts(&self, target: Option<&OwnedValue>) -> bool {
        match (target, self.parameter_type.is_empty()) {
            (None, true) => true,
            (Some(target), false) => target.value_signature().to_string() == self.parameter_type,
            _ => false,
        }
    }
}

/// Projects one GTK menu dictionary through the action group GTK would use.
pub(super) fn item(entry: &HashMap<String, OwnedValue>, actions: &Actions) -> Item {
    let submenu = gtk_link(entry, ":submenu").map(|link| SectionId::Gtk {
        group: link.group,
        menu: link.menu,
    });
    let action_name = entry
        .get("action")
        .and_then(|value| value.downcast_ref::<&str>().ok())
        .map(str::to_owned);
    let target = entry.get("target").cloned();
    let lookup = action_name
        .as_deref()
        .map(|name| actions.lookup(name))
        .unwrap_or(Lookup::Unknown);
    let (enabled, kind) = match lookup {
        Lookup::Found(action) if action.accepts(target.as_ref()) => {
            (action.enabled, kind(action, target.as_ref()))
        }
        Lookup::Found(_) | Lookup::Missing => (false, ItemKind::Standard),
        Lookup::Unknown => (true, ItemKind::Standard),
    };

    Item {
        label: gtk_label(entry),
        enabled,
        kind,
        shortcut: shortcut(entry),
        activation: action_name.map(|action| ItemId::Gtk {
            action,
            target: target.as_ref().and_then(encode_target),
        }),
        submenu,
    }
}

/// GTK's menu tracker: target + state is a radio; boolean state is a check.
fn kind(action: &Action, target: Option<&OwnedValue>) -> ItemKind {
    match (target, action.state.as_ref()) {
        (Some(target), Some(state)) => ItemKind::Radio {
            selected: target == state,
        },
        (None, Some(state)) if is_boolean(state) => ItemKind::Checkmark {
            checked: boolean(state),
        },
        _ => ItemKind::Standard,
    }
}

fn is_boolean(value: &OwnedValue) -> bool {
    value.downcast_ref::<bool>().is_ok()
}

fn boolean(value: &OwnedValue) -> bool {
    value.downcast_ref::<bool>().unwrap_or(false)
}

fn shortcut(entry: &HashMap<String, OwnedValue>) -> Option<String> {
    let accel = entry
        .get("accel")
        .and_then(|value| value.downcast_ref::<&str>().ok())?;
    parse_accel(accel)
}

/// Spells a GTK accelerator the way D-BusMenu shortcuts are spelled.
///
/// `<Primary>q` becomes `Ctrl+Q`. This is `gtk_accelerator_parse` on Linux,
/// where Primary is Control.
pub(super) fn parse_accel(raw: &str) -> Option<String> {
    let mut rest = raw.trim();
    if rest.is_empty() {
        return None;
    }

    let mut chord = Vec::new();
    while let Some(token) = rest.strip_prefix('<') {
        let end = token.find('>')?;
        let modifier = &token[..end];
        rest = token[end + 1..].trim_start();
        if let Some(name) = modifier_name(modifier) {
            if !chord.iter().any(|part| part == name) {
                chord.push(name.to_owned());
            }
        }
    }

    chord.push(key_name(rest.trim())?);
    Some(chord.join("+"))
}

fn modifier_name(token: &str) -> Option<&'static str> {
    match token.to_ascii_lowercase().as_str() {
        "primary" | "control" | "ctrl" | "ctl" => Some("Ctrl"),
        "shift" => Some("Shift"),
        "alt" | "mod1" => Some("Alt"),
        "meta" | "super" | "hyper" | "mod4" => Some("Super"),
        "release" => None,
        _ => None,
    }
}

fn key_name(token: &str) -> Option<String> {
    if token.is_empty() {
        return None;
    }

    let lower = token.to_ascii_lowercase();
    let mapped = match lower.as_str() {
        "return" | "kp_enter" => return Some("Enter".to_owned()),
        "backspace" => return Some("Backspace".to_owned()),
        "escape" | "esc" => return Some("Esc".to_owned()),
        "delete" | "del" => return Some("Delete".to_owned()),
        "tab" => return Some("Tab".to_owned()),
        "space" => return Some("Space".to_owned()),
        "plus" | "kp_add" => return Some("+".to_owned()),
        "minus" | "kp_subtract" => return Some("-".to_owned()),
        "equal" => return Some("=".to_owned()),
        "comma" => return Some(",".to_owned()),
        "period" => return Some(".".to_owned()),
        "slash" => return Some("/".to_owned()),
        "asterisk" => return Some("*".to_owned()),
        "left" => return Some("Left".to_owned()),
        "right" => return Some("Right".to_owned()),
        "up" => return Some("Up".to_owned()),
        "down" => return Some("Down".to_owned()),
        _ => token,
    };

    if mapped.len() == 1 {
        return Some(mapped.to_ascii_uppercase());
    }

    if lower
        .strip_prefix('f')
        .is_some_and(|rest| rest.chars().all(|ch| ch.is_ascii_digit()))
    {
        return Some(lower.to_ascii_uppercase());
    }

    let mut name = mapped.to_owned();
    if let Some(first) = name.get_mut(..1) {
        first.make_ascii_uppercase();
    }
    Some(name)
}

pub(super) fn encode_target(value: &OwnedValue) -> Option<Vec<u8>> {
    let encoded = to_bytes(Context::new_dbus(LE, 0), value).ok()?;
    Some(encoded.bytes().to_vec())
}

pub(super) fn decode_target(bytes: &[u8]) -> Option<OwnedValue> {
    let data = Data::new(bytes, Context::new_dbus(LE, 0));
    data.deserialize().ok().map(|(value, _)| value)
}

#[derive(Clone, Debug, Type, serde::Deserialize)]
pub(super) struct Description {
    pub enabled: bool,
    pub parameter_type: Signature,
    pub state: Vec<OwnedValue>,
}

#[proxy(interface = "org.gtk.Actions", assume_defaults = true)]
pub(super) trait GtkActions {
    fn describe_all(&self) -> zbus::Result<HashMap<String, Description>>;

    fn activate(
        &self,
        action: &str,
        parameter: &[Value<'_>],
        platform_data: HashMap<&str, Value<'_>>,
    ) -> zbus::Result<()>;

    #[zbus(signal)]
    fn changed(
        &self,
        removals: Vec<String>,
        enable_changes: HashMap<String, bool>,
        state_changes: HashMap<String, OwnedValue>,
        additions: HashMap<String, Description>,
    ) -> zbus::Result<()>;
}

#[cfg(test)]
mod tests {
    use super::{Action, Actions, Description, decode_target, encode_target, item, parse_accel};
    use crate::global_menu::{ItemId, ItemKind};
    use std::collections::HashMap;
    use zbus::zvariant::{OwnedValue, Type, Value};

    fn entry(attributes: &[(&str, Value<'static>)]) -> HashMap<String, OwnedValue> {
        attributes
            .iter()
            .map(|(key, value)| {
                (
                    (*key).to_owned(),
                    OwnedValue::try_from(value.clone()).expect("attribute should convert"),
                )
            })
            .collect()
    }

    fn owned(value: Value<'static>) -> OwnedValue {
        OwnedValue::try_from(value).expect("value should convert")
    }

    fn described(name: &str, action: Action) -> Actions {
        let mut actions = Actions::default();
        actions.mark_described(name.split_once('.').map(|(scope, _)| scope).unwrap_or(""));
        actions.insert(name.to_owned(), action);
        actions
    }

    fn stateless(enabled: bool) -> Action {
        Action {
            enabled,
            parameter_type: String::new(),
            state: None,
        }
    }

    #[test]
    fn describe_all_uses_glibs_action_tuple() {
        assert_eq!(Description::SIGNATURE.to_string(), "(bgav)");
    }

    #[test]
    fn a_boolean_state_without_a_target_is_a_checkmark() {
        let actions = described(
            "win.fullscreen",
            Action {
                enabled: true,
                parameter_type: String::new(),
                state: Some(owned(Value::from(true))),
            },
        );
        let row = item(
            &entry(&[
                ("label", Value::from("_Fullscreen")),
                ("action", Value::from("win.fullscreen")),
            ]),
            &actions,
        );

        assert_eq!(row.kind, ItemKind::Checkmark { checked: true });
        assert!(row.enabled);
        assert_eq!(
            row.activation,
            Some(ItemId::Gtk {
                action: "win.fullscreen".to_owned(),
                target: None,
            })
        );
    }

    #[test]
    fn a_target_that_matches_state_is_the_selected_radio() {
        let actions = described(
            "app.justify",
            Action {
                enabled: true,
                parameter_type: "s".to_owned(),
                state: Some(owned(Value::from("left"))),
            },
        );
        let selected = item(
            &entry(&[
                ("label", Value::from("_Left")),
                ("action", Value::from("app.justify")),
                ("target", Value::from("left")),
            ]),
            &actions,
        );
        let other = item(
            &entry(&[
                ("label", Value::from("_Right")),
                ("action", Value::from("app.justify")),
                ("target", Value::from("right")),
            ]),
            &actions,
        );

        assert_eq!(selected.kind, ItemKind::Radio { selected: true });
        assert_eq!(other.kind, ItemKind::Radio { selected: false });
        match selected.activation {
            Some(ItemId::Gtk { action, target }) => {
                assert_eq!(action, "app.justify");
                let decoded = decode_target(&target.expect("radio carries a target"))
                    .expect("target should decode");
                assert_eq!(decoded.downcast_ref::<&str>().expect("string"), "left");
            }
            other => panic!("expected a GTK activation, got {other:?}"),
        }
    }

    #[test]
    fn a_disabled_action_disables_the_row() {
        let actions = described("app.undo", stateless(false));
        let row = item(
            &entry(&[
                ("label", Value::from("_Undo")),
                ("action", Value::from("app.undo")),
            ]),
            &actions,
        );

        assert!(!row.enabled);
        assert_eq!(row.kind, ItemKind::Standard);
    }

    #[test]
    fn a_described_group_with_no_such_action_disables_the_row() {
        let mut actions = Actions::default();
        actions.mark_described("app");
        let row = item(
            &entry(&[
                ("label", Value::from("_Missing")),
                ("action", Value::from("app.missing")),
            ]),
            &actions,
        );

        assert!(!row.enabled);
    }

    #[test]
    fn an_undescribed_group_keeps_the_row_available() {
        let row = item(
            &entry(&[
                ("label", Value::from("_New")),
                ("action", Value::from("app.new")),
            ]),
            &Actions::default(),
        );

        assert!(row.enabled);
        assert_eq!(row.kind, ItemKind::Standard);
    }

    #[test]
    fn a_target_that_does_not_match_the_parameter_type_cannot_activate() {
        let actions = described(
            "app.open",
            Action {
                enabled: true,
                parameter_type: "s".to_owned(),
                state: None,
            },
        );
        let row = item(
            &entry(&[
                ("label", Value::from("Broken")),
                ("action", Value::from("app.open")),
            ]),
            &actions,
        );

        assert!(!row.enabled);
        assert_eq!(row.kind, ItemKind::Standard);
    }

    #[test]
    fn gtk_accelerators_are_spelled_like_the_rest_of_the_bar() {
        assert_eq!(parse_accel("<Primary>q").as_deref(), Some("Ctrl+Q"));
        assert_eq!(
            parse_accel("<Control><Shift>n").as_deref(),
            Some("Ctrl+Shift+N")
        );
        assert_eq!(parse_accel("<Alt>F4").as_deref(), Some("Alt+F4"));
        assert_eq!(parse_accel("<Primary>plus").as_deref(), Some("Ctrl++"));
        assert_eq!(parse_accel(""), None);
    }

    #[test]
    fn the_accel_attribute_becomes_the_row_shortcut() {
        let row = item(
            &entry(&[
                ("label", Value::from("_Quit")),
                ("action", Value::from("app.quit")),
                ("accel", Value::from("<Primary>q")),
            ]),
            &Actions::default(),
        );

        assert_eq!(row.shortcut.as_deref(), Some("Ctrl+Q"));
    }

    #[test]
    fn a_target_round_trips_through_the_activation_payload() {
        let original = owned(Value::from("notes.txt"));
        let encoded = encode_target(&original).expect("encode");
        let decoded = decode_target(&encoded).expect("decode");

        assert_eq!(decoded.downcast_ref::<&str>().expect("string"), "notes.txt");
    }
}
