//! Hyprland `global` bind reconciliation.
//!
//! The shortcuts portal owns activation delivery, but Hyprland only forwards a
//! configured chord to that portal after a matching compositor bind exists.
//! This module reads compositor state, plans a safe update for a [`Spec`], and
//! lets configured Hyprbaric shortcuts claim their configured chords.

use std::collections::HashSet;

use serde::Deserialize;

mod client;

pub(super) use client::{reconcile_from, remove};

use super::{
    Error, Shortcut, Spec,
    binding::{self, Binding, Phase},
    identity::APPLICATION_ID,
};

/// The Hyprland chord shape relevant to bind reconciliation.
#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub(super) struct Chord {
    /// Hyprland's modifier mask for the chord.
    pub modmask: u32,
    /// The normalized Hyprland key label for the chord.
    pub key: String,
}

/// A `hyprctl keyword` bind ready to install.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) struct Bind {
    /// The `hyprctl keyword` name used to install the bind.
    pub keyword: &'static str,
    /// The `hyprctl keyword` payload used to install the bind.
    pub value: String,
}

impl Bind {
    /// Projects this app-owned bind into the Lua API used by modern Hyprland.
    ///
    /// Hyprbaric only creates `global` and `exec` binds, so keeping this
    /// projection next to the legacy keyword representation makes the runtime
    /// installer compatible with either config provider.
    pub(super) fn lua_expression(&self) -> Result<String, Error> {
        let mut fields = self.value.splitn(4, ", ");
        let (Some(modifiers), Some(key), Some(dispatcher), Some(argument)) =
            (fields.next(), fields.next(), fields.next(), fields.next())
        else {
            return Err(Error::InvalidBind {
                value: self.value.clone(),
            });
        };
        let modifiers = modifiers.split_whitespace().collect::<Vec<_>>().join(" + ");
        let chord = if modifiers.is_empty() {
            key.to_string()
        } else {
            format!("{modifiers} + {key}")
        };
        let dispatcher = match dispatcher {
            "global" => format!("hl.dsp.global({})", lua_string(argument)),
            "exec" => format!("hl.dsp.exec_cmd({})", lua_string(argument)),
            _ => {
                return Err(Error::InvalidBind {
                    value: self.value.clone(),
                });
            }
        };
        let options = if self.keyword == "bindr" {
            ", { release = true }"
        } else {
            ""
        };

        Ok(format!(
            "hl.bind({}, {dispatcher}{options})",
            lua_string(&chord)
        ))
    }

    /// Builds the Lua equivalent of a legacy `keyword unbind` payload.
    pub(super) fn lua_unbind_expression(value: &str) -> String {
        let chord = value
            .split(',')
            .map(str::trim)
            .filter(|part| !part.is_empty())
            .flat_map(str::split_whitespace)
            .collect::<Vec<_>>()
            .join(" + ");
        format!("hl.unbind({})", lua_string(&chord))
    }
}

fn lua_string(value: &str) -> String {
    let escaped = value
        .replace('\\', "\\\\")
        .replace('"', "\\\"")
        .replace('\n', "\\n")
        .replace('\r', "\\r");
    format!("\"{escaped}\"")
}

/// Existing Hyprland bind state relevant to one configured [`Spec`].
#[derive(Clone, Debug, PartialEq, Eq)]
struct RelevantBindEntry {
    /// The installed chord reported by Hyprland.
    chord: Chord,
    /// The installed press or release phase.
    phase: Phase,
    /// The app-owned projection that matched this entry.
    owner: OwnedBind,
}

impl RelevantBindEntry {
    /// Returns whether this existing compositor entry matches a binding.
    fn matches(&self, binding: &Binding, owner: &OwnedBind) -> bool {
        self.owner == *owner && self.chord == binding.hypr_chord() && self.phase == binding.phase()
    }
}

/// A bind Hyprbaric considers app-owned for one shortcut.
#[derive(Clone, Debug, PartialEq, Eq)]
struct OwnedBind {
    /// The dispatcher that identifies the bind boundary.
    dispatcher: Dispatcher,
    /// The dispatcher argument Hyprbaric expects for this shortcut.
    arg: String,
}

impl OwnedBind {
    /// Returns the ordinary GlobalShortcuts portal owner.
    fn global(global_arg: String) -> Self {
        Self {
            dispatcher: Dispatcher::Global,
            arg: global_arg,
        }
    }

    /// Returns the Hyprland exec bridge owner for standalone logo shortcuts.
    fn exec_bridge(global_arg: &str) -> Self {
        Self {
            dispatcher: Dispatcher::Exec,
            arg: exec_bridge_command(global_arg),
        }
    }

    /// Returns the pre-Lua bridge accepted during the compatibility migration.
    fn legacy_exec_bridge(global_arg: &str) -> Self {
        Self {
            dispatcher: Dispatcher::Exec,
            arg: legacy_exec_bridge_command(global_arg),
        }
    }

    /// Returns whether this owner matches a raw bind entry.
    fn matches(&self, entry: &BindEntry) -> bool {
        entry.dispatcher == self.dispatcher && entry.arg == self.arg
    }
}

/// The canonical bind plus the raw ownership projections it replaces.
#[derive(Clone, Debug, PartialEq, Eq)]
struct DesiredBind {
    /// The bind command that should be installed.
    bind: Bind,
    /// The raw bind owners considered Hyprbaric-owned for reconciliation.
    owners: Owners,
}

impl DesiredBind {
    /// Returns the canonical owner that should remain after reconciliation.
    fn primary_owner(&self) -> &OwnedBind {
        &self.owners.primary
    }
}

/// The canonical bind owner and any legacy aliases it may replace.
#[derive(Clone, Debug, PartialEq, Eq)]
struct Owners {
    /// Canonical owner that should remain after reconciliation.
    primary: OwnedBind,
    /// Legacy app-owned projections accepted during migration.
    aliases: Vec<OwnedBind>,
}

impl Owners {
    fn iter(&self) -> impl Iterator<Item = &OwnedBind> {
        std::iter::once(&self.primary).chain(&self.aliases)
    }
}

/// A raw binding entry deserialized from `hyprctl binds -j`.
///
/// Raw bind snapshots stay private so planning works with typed relevant
/// entries before making any compositor changes.
#[derive(Clone, Debug, Deserialize)]
struct BindEntry {
    /// The raw modifier bitmask emitted by Hyprland.
    modmask: u32,
    /// The raw key label emitted by Hyprland.
    key: String,
    /// Whether Hyprland fires this bind on release.
    release: bool,
    /// The dispatcher relevant to shortcut ownership.
    dispatcher: Dispatcher,
    /// The dispatcher argument.
    arg: String,
}

/// The Hyprland dispatcher kinds relevant to shortcut reconciliation.
///
/// Hyprbaric owns only binds targeting Hyprland's `global` dispatcher. Every
/// other dispatcher remains in the snapshot so shared-chord checks can treat it
/// as foreign without routing reconciliation through raw strings.
#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
enum Dispatcher {
    /// The compositor dispatcher that forwards into the shortcuts portal.
    Global,
    /// The compositor dispatcher that executes a command.
    Exec,
    /// Any dispatcher outside Hyprbaric's shortcut ownership boundary.
    #[serde(other)]
    Other,
}

/// The compositor work needed to make one [`Spec`] current.
#[derive(Debug, PartialEq, Eq)]
enum Plan {
    /// Existing compositor state already matches the spec.
    Noop,
    /// Existing app-owned binds must be replaced with a canonical bind.
    Reinstall {
        /// Safe app-owned chords to unbind before installation.
        unbind_values: Vec<String>,
        /// The canonical Hyprland bind to install.
        bind: Bind,
    },
}

/// The compositor work needed to remove one app-owned shortcut bind.
#[derive(Debug, PartialEq, Eq)]
enum RemovePlan {
    /// No compositor bind currently targets this shortcut.
    Noop,
    /// Safe app-owned chords to unbind.
    Remove {
        /// Safe app-owned chords to unbind.
        unbind_values: Vec<String>,
    },
}

/// A single Hyprland binding snapshot reused across one reconciliation pass.
pub(super) struct BindSnapshot {
    bindings: Vec<BindEntry>,
}

/// Builds the safe compositor reconciliation plan for a spec.
///
/// Only entries targeting the same portal identifier are considered app-owned.
/// If any existing app-owned chord that must be removed is shared by another
/// dispatcher entry, the plan refuses to proceed with [`Error::UnsafeUnbind`],
/// unless that chord is the configured target for the shortcut being installed.
fn plan_reconciliation(spec: &Spec, bindings: &[BindEntry]) -> Result<Plan, Error> {
    let portal_id = spec.id().portal_id();
    let desired_arg = global_dispatch_id(&portal_id);
    let desired = desired_bind(spec, &desired_arg);
    let desired_chord = spec.binding().hypr_chord();
    let takeover_values =
        takeover_unbind_values(spec.shortcut(), &desired_chord, bindings, &desired.owners);
    let relevant_entries = bindings
        .iter()
        .filter_map(|entry| relevant_bind_entry(entry, &desired.owners))
        .collect::<Vec<_>>();

    if takeover_values.is_empty()
        && relevant_entries.len() == 1
        && relevant_entries[0].matches(spec.binding(), desired.primary_owner())
    {
        return Ok(Plan::Noop);
    }

    if relevant_entries.is_empty()
        && takeover_values.is_empty()
        && chord_is_shared_with_non_app_bind(&desired_chord, bindings, &desired.owners)
    {
        return Err(Error::UnsafeUnbind {
            shortcut: spec.shortcut(),
            bind: unbind_value(spec.shortcut(), &desired_chord)?,
        });
    }

    if relevant_entries.is_empty() {
        return Ok(Plan::Reinstall {
            unbind_values: takeover_values,
            bind: desired.bind,
        });
    }

    let relevant_chords = relevant_entries
        .iter()
        .map(|entry| entry.chord.clone())
        .collect::<HashSet<_>>();

    for chord in &relevant_chords {
        if chord_is_shared_with_non_app_bind(chord, bindings, &desired.owners)
            && !spec
                .shortcut()
                .can_take_over_foreign_bind(chord, &desired_chord)
        {
            return Err(Error::UnsafeUnbind {
                shortcut: spec.shortcut(),
                bind: unbind_value(spec.shortcut(), chord)?,
            });
        }
    }

    let mut unbind_values = takeover_values;
    unbind_values.extend(
        relevant_chords
            .iter()
            .map(|chord| unbind_value(spec.shortcut(), chord))
            .collect::<Result<Vec<_>, _>>()?,
    );
    unbind_values.sort();
    unbind_values.dedup();

    Ok(Plan::Reinstall {
        unbind_values,
        bind: desired.bind,
    })
}

/// Builds the safe compositor removal plan for one shortcut.
fn plan_removal(shortcut: Shortcut, bindings: &[BindEntry]) -> Result<RemovePlan, Error> {
    let owners = owners_for_shortcut(shortcut);
    let relevant_entries = bindings
        .iter()
        .filter_map(|entry| relevant_bind_entry(entry, &owners))
        .collect::<Vec<_>>();

    if relevant_entries.is_empty() {
        return Ok(RemovePlan::Noop);
    }

    let relevant_chords = relevant_entries
        .iter()
        .map(|entry| entry.chord.clone())
        .collect::<HashSet<_>>();

    for chord in &relevant_chords {
        if chord_is_shared_with_non_app_bind(chord, bindings, &owners) {
            return Err(Error::UnsafeUnbind {
                shortcut,
                bind: unbind_value(shortcut, chord)?,
            });
        }
    }

    let mut unbind_values = relevant_chords
        .iter()
        .map(|chord| unbind_value(shortcut, chord))
        .collect::<Result<Vec<_>, _>>()?;
    unbind_values.sort();

    Ok(RemovePlan::Remove { unbind_values })
}

/// Builds the canonical compositor bind for one configured shortcut.
fn desired_bind(spec: &Spec, global_arg: &str) -> DesiredBind {
    if matches!(spec.shortcut(), Shortcut::AppLauncher) && spec.binding().is_standalone_logo_key() {
        return DesiredBind {
            bind: spec
                .binding()
                .hypr_exec_bind(&exec_bridge_command(global_arg)),
            owners: Owners {
                primary: OwnedBind::exec_bridge(global_arg),
                aliases: vec![
                    OwnedBind::global(global_arg.to_string()),
                    OwnedBind::legacy_exec_bridge(global_arg),
                ],
            },
        };
    }

    DesiredBind {
        bind: spec.binding().hypr_bind(global_arg),
        owners: Owners {
            primary: OwnedBind::global(global_arg.to_string()),
            aliases: Vec::new(),
        },
    }
}

/// Returns every compositor owner Hyprbaric may remove for a shortcut.
fn owners_for_shortcut(shortcut: Shortcut) -> Owners {
    let global_arg = global_dispatch_id(&shortcut.id().portal_id());
    Owners {
        primary: OwnedBind::global(global_arg.clone()),
        aliases: if matches!(shortcut, Shortcut::AppLauncher) {
            vec![
                OwnedBind::exec_bridge(&global_arg),
                OwnedBind::legacy_exec_bridge(&global_arg),
            ]
        } else {
            Vec::new()
        },
    }
}

/// Formats the exec bridge that works with both Lua and legacy config providers.
fn exec_bridge_command(global_arg: &str) -> String {
    format!(
        "hyprctl dispatch \"hl.dsp.global('{global_arg}')\" || {}",
        legacy_exec_bridge_command(global_arg)
    )
}

/// Formats the pre-Lua exec bridge retained as a migration alias.
fn legacy_exec_bridge_command(global_arg: &str) -> String {
    format!("hyprctl dispatch global {global_arg}")
}

/// Returns foreign chord unbinds a shortcut is explicitly allowed to take over.
fn takeover_unbind_values(
    shortcut: Shortcut,
    desired_chord: &Chord,
    bindings: &[BindEntry],
    owners: &Owners,
) -> Vec<String> {
    if !shortcut.can_take_over_foreign_bind(desired_chord, desired_chord)
        || !chord_is_shared_with_non_app_bind(desired_chord, bindings, owners)
    {
        return Vec::new();
    }

    unbind_value(shortcut, desired_chord)
        .map(|value| vec![value])
        .unwrap_or_default()
}

/// Returns whether a chord is already owned by a non-Hyprbaric bind.
fn chord_is_shared_with_non_app_bind(
    chord: &Chord,
    bindings: &[BindEntry],
    owners: &Owners,
) -> bool {
    bindings
        .iter()
        .any(|entry| raw_chord(entry) == *chord && relevant_bind_entry(entry, owners).is_none())
}

/// Projects a raw bind entry into its normalized chord.
fn raw_chord(entry: &BindEntry) -> Chord {
    Chord {
        modmask: entry.modmask,
        key: binding::normalize_key_label(&entry.key),
    }
}

/// Extracts typed relevant state from a raw Hyprland bind entry.
fn relevant_bind_entry(entry: &BindEntry, owners: &Owners) -> Option<RelevantBindEntry> {
    let owner = owners.iter().find(|owner| owner.matches(entry))?.clone();

    Some(RelevantBindEntry {
        chord: raw_chord(entry),
        phase: Phase::from_release(entry.release),
        owner,
    })
}

impl Shortcut {
    /// Returns whether this shortcut may replace a foreign bind on `chord`.
    fn can_take_over_foreign_bind(self, chord: &Chord, desired_chord: &Chord) -> bool {
        chord == desired_chord
    }
}

/// Formats the `hyprctl keyword unbind` payload for a chord.
fn unbind_value(shortcut: Shortcut, chord: &Chord) -> Result<String, Error> {
    let mods = binding::format_hyprland_modmask(chord.modmask).ok_or(Error::UnsafeUnbind {
        shortcut,
        bind: format!("{}, {}", chord.modmask, chord.key),
    })?;
    if mods.is_empty() {
        Ok(format!(", {}", chord.key))
    } else {
        Ok(format!("{mods}, {}", chord.key))
    }
}

/// Formats a portal identifier for Hyprland's `global` dispatcher.
///
/// Hyprland's GlobalShortcuts backend scopes registered shortcuts under the
/// desktop app ID it reports through `hyprctl globalshortcuts`.
fn global_dispatch_id(shortcut_id: &str) -> String {
    if shortcut_id.contains(':') {
        shortcut_id.to_string()
    } else {
        format!("{APPLICATION_ID}:{shortcut_id}")
    }
}

#[cfg(test)]
mod tests {
    use super::{
        BindEntry, Chord, Dispatcher, Plan, RemovePlan, exec_bridge_command, global_dispatch_id,
        legacy_exec_bridge_command, plan_reconciliation, plan_removal, unbind_value,
    };
    use crate::shortcuts::{Configuration, Shortcut};

    fn spec(shortcut: Shortcut) -> super::Spec {
        Configuration::default()
            .specs()
            .find(|spec| spec.shortcut() == shortcut)
            .expect("default shortcuts should be bound")
    }

    fn global_entry(modmask: u32, key: &str, release: bool, shortcut_id: &str) -> BindEntry {
        BindEntry {
            modmask,
            key: key.to_string(),
            release,
            dispatcher: Dispatcher::Global,
            arg: global_dispatch_id(shortcut_id),
        }
    }

    fn exec_entry(modmask: u32, key: &str, release: bool, arg: &str) -> BindEntry {
        BindEntry {
            modmask,
            key: key.to_string(),
            release,
            dispatcher: Dispatcher::Exec,
            arg: arg.to_string(),
        }
    }

    fn launcher_bridge_arg() -> String {
        exec_bridge_command("com.hyprbaric.Hyprbaric:com.shortcut.hyprbaric.open_app_launcher")
    }

    fn legacy_launcher_bridge_arg() -> String {
        legacy_exec_bridge_command(
            "com.hyprbaric.Hyprbaric:com.shortcut.hyprbaric.open_app_launcher",
        )
    }

    #[test]
    fn parses_known_exec_dispatcher_from_snapshot_state() {
        let entry = serde_json::from_str::<BindEntry>(
            r#"
            {
                "modmask": 64,
                "key": "A",
                "release": false,
                "dispatcher": "exec",
                "arg": "alacritty"
            }
            "#,
        )
        .expect("exec bind snapshots should deserialize");

        assert!(matches!(entry.dispatcher, Dispatcher::Exec));
    }

    #[test]
    fn parses_unknown_dispatchers_as_foreign_snapshot_state() {
        let entry = serde_json::from_str::<BindEntry>(
            r#"
            {
                "modmask": 64,
                "key": "A",
                "release": false,
                "dispatcher": "movewindow",
                "arg": "l"
            }
            "#,
        )
        .expect("foreign bind snapshots should deserialize");

        assert!(matches!(entry.dispatcher, Dispatcher::Other));
    }

    #[test]
    fn scopes_unscoped_ids_for_hyprland_global_dispatch() {
        assert_eq!(
            global_dispatch_id("com.shortcut.hyprbaric.open_app_launcher"),
            String::from("com.hyprbaric.Hyprbaric:com.shortcut.hyprbaric.open_app_launcher")
        );
    }

    #[test]
    fn keeps_scoped_ids_for_hyprland_global_dispatch() {
        assert_eq!(
            global_dispatch_id("coolApp:myToggle"),
            String::from("coolApp:myToggle")
        );
    }

    #[test]
    fn projects_global_binds_into_lua() {
        let bind = super::Bind {
            keyword: "bind",
            value: "SUPER SHIFT, S, global, com.hyprbaric.Hyprbaric:controls".to_string(),
        };

        assert_eq!(
            bind.lua_expression().expect("valid app-owned bind"),
            "hl.bind(\"SUPER + SHIFT + S\", hl.dsp.global(\"com.hyprbaric.Hyprbaric:controls\"))"
        );
    }

    #[test]
    fn rejects_incomplete_and_unsupported_lua_binds() {
        for value in ["SUPER, S", "SUPER, S, movewindow, l"] {
            let bind = super::Bind {
                keyword: "bind",
                value: value.to_owned(),
            };
            assert!(matches!(
                bind.lua_expression(),
                Err(super::Error::InvalidBind { .. })
            ));
        }
    }

    #[test]
    fn projects_release_exec_binds_and_unbinds_into_lua() {
        let bind = super::Bind {
            keyword: "bindr",
            value: "SUPER, Super_L, exec, hyprctl dispatch \"hl.dsp.global('launcher')\" || hyprctl dispatch global launcher".to_string(),
        };

        assert_eq!(
            bind.lua_expression().expect("valid app-owned bind"),
            "hl.bind(\"SUPER + Super_L\", hl.dsp.exec_cmd(\"hyprctl dispatch \\\"hl.dsp.global('launcher')\\\" || hyprctl dispatch global launcher\"), { release = true })"
        );
        assert_eq!(
            super::Bind::lua_unbind_expression("SUPER, Super_L"),
            "hl.unbind(\"SUPER + Super_L\")"
        );
        assert_eq!(
            super::Bind::lua_unbind_expression("SUPER SHIFT, S"),
            "hl.unbind(\"SUPER + SHIFT + S\")"
        );
    }

    #[test]
    fn skips_reinstall_when_canonical_bind_already_exists() {
        let spec = spec(Shortcut::AppLauncher);
        let bridge = launcher_bridge_arg();
        let plan = plan_reconciliation(&spec, &[exec_entry(64, "Super_L", true, &bridge)])
            .expect("reconciliation should succeed");

        assert!(matches!(plan, Plan::Noop));
    }

    #[test]
    fn upgrades_legacy_app_launcher_bridge() {
        let spec = spec(Shortcut::AppLauncher);
        let legacy_bridge = legacy_launcher_bridge_arg();
        let plan = plan_reconciliation(&spec, &[exec_entry(64, "Super_L", true, &legacy_bridge)])
            .expect("legacy bridge should be recognized as app-owned");

        match plan {
            Plan::Reinstall {
                unbind_values,
                bind,
            } => {
                assert_eq!(unbind_values, vec!["SUPER, Super_L".to_string()]);
                assert_eq!(bind.keyword, "bindr");
                assert_eq!(
                    bind.value,
                    format!("SUPER, Super_L, exec, {}", launcher_bridge_arg())
                );
            }
            Plan::Noop => panic!("legacy bridge should be upgraded"),
        }
    }

    #[test]
    fn app_launcher_takes_over_foreign_super_bind() {
        let spec = spec(Shortcut::AppLauncher);
        let shortcut_id = spec.id().portal_id();
        let plan = plan_reconciliation(
            &spec,
            &[
                BindEntry {
                    modmask: 64,
                    key: "Super_L".to_string(),
                    release: true,
                    dispatcher: Dispatcher::Exec,
                    arg: "foreign-launcher-command".to_string(),
                },
                global_entry(64, "Super_L", true, &shortcut_id),
            ],
        )
        .expect("app launcher should take over the standalone super chord");

        match plan {
            Plan::Reinstall {
                unbind_values,
                bind,
            } => {
                assert_eq!(unbind_values, vec!["SUPER, Super_L".to_string()]);
                assert_eq!(bind.keyword, "bindr");
                assert_eq!(
                    bind.value,
                    format!("SUPER, Super_L, exec, {}", launcher_bridge_arg())
                );
            }
            Plan::Noop => panic!("expected takeover reinstall plan"),
        }
    }

    #[test]
    fn reinstalls_canonical_bind_when_foreign_bind_shares_desired_chord() {
        let spec = spec(Shortcut::VolumeUp);
        let shortcut_id = spec.id().portal_id();
        let plan = plan_reconciliation(
            &spec,
            &[
                global_entry(0, "XF86AudioRaiseVolume", false, &shortcut_id),
                BindEntry {
                    modmask: 0,
                    key: "XF86AudioRaiseVolume".to_string(),
                    release: false,
                    dispatcher: Dispatcher::Other,
                    arg: "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%+".to_string(),
                },
            ],
        )
        .expect("configured shortcut should take over the desired chord");

        match plan {
            Plan::Reinstall {
                unbind_values,
                bind,
            } => {
                assert_eq!(unbind_values, vec![", XF86AudioRaiseVolume".to_string()]);
                assert_eq!(bind.keyword, "bind");
                assert_eq!(
                    bind.value,
                    ", XF86AudioRaiseVolume, global, com.hyprbaric.Hyprbaric:com.shortcut.hyprbaric.volume_up"
                );
            }
            Plan::Noop => panic!("expected takeover reinstall plan"),
        }
    }

    #[test]
    fn takes_over_foreign_bind_on_desired_chord() {
        let spec = spec(Shortcut::CaptureRegion);
        let plan = plan_reconciliation(
            &spec,
            &[BindEntry {
                modmask: 65,
                key: "S".to_string(),
                release: false,
                dispatcher: Dispatcher::Exec,
                arg: "foreign-screenshot-command".to_string(),
            }],
        )
        .expect("configured shortcut should take over the desired chord");

        match plan {
            Plan::Reinstall {
                unbind_values,
                bind,
            } => {
                assert_eq!(unbind_values, vec!["SUPER SHIFT, S".to_string()]);
                assert_eq!(bind.keyword, "bind");
                assert_eq!(
                    bind.value,
                    "SUPER SHIFT, S, global, com.hyprbaric.Hyprbaric:com.shortcut.hyprbaric.capture_region"
                );
            }
            Plan::Noop => panic!("expected takeover reinstall plan"),
        }
    }

    #[test]
    fn reinstalls_when_same_shortcut_id_has_wrong_chord() {
        let spec = spec(Shortcut::AppLauncher);
        let shortcut_id = spec.id().portal_id();
        let plan = plan_reconciliation(&spec, &[global_entry(4, "A", false, &shortcut_id)])
            .expect("reconciliation should succeed");

        match plan {
            Plan::Reinstall {
                unbind_values,
                bind,
            } => {
                assert_eq!(unbind_values, vec!["CTRL, A".to_string()]);
                assert_eq!(bind.keyword, "bindr");
                assert_eq!(
                    bind.value,
                    format!("SUPER, Super_L, exec, {}", launcher_bridge_arg())
                );
            }
            Plan::Noop => panic!("expected reinstall plan"),
        }
    }

    #[test]
    fn removes_app_launcher_exec_bridge_for_disabled_shortcut() {
        let shortcut = Shortcut::AppLauncher;
        let bridge = launcher_bridge_arg();
        let plan = plan_removal(shortcut, &[exec_entry(64, "Super_L", true, &bridge)])
            .expect("removal should succeed");

        match plan {
            RemovePlan::Remove { unbind_values } => {
                assert_eq!(unbind_values, vec!["SUPER, Super_L".to_string()]);
            }
            RemovePlan::Noop => panic!("expected app launcher bridge removal"),
        }
    }

    #[test]
    fn removes_legacy_app_launcher_bridge_for_disabled_shortcut() {
        let shortcut = Shortcut::AppLauncher;
        let legacy_bridge = legacy_launcher_bridge_arg();
        let plan = plan_removal(shortcut, &[exec_entry(64, "Super_L", true, &legacy_bridge)])
            .expect("legacy bridge should remain removable");

        match plan {
            RemovePlan::Remove { unbind_values } => {
                assert_eq!(unbind_values, vec!["SUPER, Super_L".to_string()]);
            }
            RemovePlan::Noop => panic!("expected legacy app launcher bridge removal"),
        }
    }

    #[test]
    fn removes_app_owned_global_bind_for_disabled_shortcut() {
        let shortcut = Shortcut::Controls;
        let shortcut_id = shortcut.id().portal_id();
        let plan = plan_removal(shortcut, &[global_entry(64, "S", false, &shortcut_id)])
            .expect("removal should succeed");

        match plan {
            RemovePlan::Remove { unbind_values } => {
                assert_eq!(unbind_values, vec!["SUPER, S".to_string()]);
            }
            RemovePlan::Noop => panic!("expected app-owned bind removal"),
        }
    }

    #[test]
    fn refuses_to_remove_shared_foreign_chord() {
        let shortcut = Shortcut::Controls;
        let shortcut_id = shortcut.id().portal_id();
        let error = plan_removal(
            shortcut,
            &[
                global_entry(64, "S", false, &shortcut_id),
                BindEntry {
                    modmask: 64,
                    key: "S".to_string(),
                    release: false,
                    dispatcher: Dispatcher::Other,
                    arg: "special-workspace".to_string(),
                },
            ],
        )
        .expect_err("shared foreign chord should block removal");

        assert!(matches!(error, super::Error::UnsafeUnbind { .. }));
    }

    #[test]
    fn refuses_to_unbind_when_chord_is_shared_with_non_app_bind() {
        let spec = spec(Shortcut::AppLauncher);
        let shortcut_id = spec.id().portal_id();
        let error = plan_reconciliation(
            &spec,
            &[
                global_entry(4, "A", false, &shortcut_id),
                BindEntry {
                    modmask: 4,
                    key: "A".to_string(),
                    release: false,
                    dispatcher: Dispatcher::Other,
                    arg: "alacritty".to_string(),
                },
            ],
        )
        .expect_err("shared chord should be rejected");

        assert!(matches!(error, super::Error::UnsafeUnbind { .. }));
    }

    #[test]
    fn formats_unbind_values_using_hyprland_mod_order() {
        let value = unbind_value(
            Shortcut::BarSettings,
            &Chord {
                modmask: 65,
                key: "C".to_string(),
            },
        )
        .expect("modmask should be supported");
        assert_eq!(value, "SUPER SHIFT, C");
    }
}
