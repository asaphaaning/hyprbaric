//! Stable capability labels and packaging metadata.

use super::{Capability, Entry, State, Tier, probe::Probe};

pub(super) struct Definition {
    capability: Capability,
    label: &'static str,
    detail: &'static str,
    tier: Tier,
    probes: &'static [Probe],
    features: &'static [&'static str],
    commands: &'static [&'static str],
    arch_packages: &'static [&'static str],
    debian_packages: &'static [&'static str],
    rpm_packages: &'static [&'static str],
}

impl Definition {
    pub(super) fn entry(&self) -> Entry {
        Entry {
            capability: self.capability,
            label: self.label,
            detail: self.detail,
            tier: self.tier,
            state: self.state(),
            features: self.features,
            commands: self.commands,
            arch_packages: self.arch_packages,
            debian_packages: self.debian_packages,
            rpm_packages: self.rpm_packages,
        }
    }

    fn state(&self) -> State {
        let failures = self
            .probes
            .iter()
            .filter_map(|probe| probe.failure())
            .collect::<Vec<_>>();

        if failures.is_empty() {
            State::Available
        } else if self.tier == Tier::Optional || failures.len() == 1 {
            State::Missing {
                message: failures.join("; "),
            }
        } else {
            State::Degraded {
                message: failures.join("; "),
            }
        }
    }
}

pub(super) const DEFINITIONS: &[Definition] = &[
    Definition {
        capability: Capability::Hyprland,
        label: "Hyprland session",
        detail: "Workspaces, focused windows, global binds, and compositor actions.",
        tier: Tier::Core,
        probes: &[Probe::Command("hyprctl"), Probe::HyprlandSession],
        features: &["workspaces", "active window", "global shortcuts"],
        commands: &["hyprctl"],
        arch_packages: &["hyprland"],
        debian_packages: &["hyprland"],
        rpm_packages: &["hyprland"],
    },
    Definition {
        capability: Capability::LayerShell,
        label: "GTK layer shell",
        detail: "Native runner support for Wayland layer surfaces and hit regions.",
        tier: Tier::Core,
        probes: &[Probe::AlwaysAvailable],
        features: &["bar window", "transparency", "input regions"],
        commands: &[],
        arch_packages: &["gtk3", "gtk-layer-shell", "wayland"],
        debian_packages: &["libgtk-3-0", "libgtk-layer-shell0", "libwayland-client0"],
        rpm_packages: &["gtk3", "gtk-layer-shell", "wayland"],
    },
    Definition {
        capability: Capability::GlobalShortcuts,
        label: "Global shortcuts portal",
        detail: "XDG portal backend used with Hyprland global binds.",
        tier: Tier::Service,
        probes: &[
            Probe::Command("hyprctl"),
            Probe::AnyPath(&[
                "/usr/share/xdg-desktop-portal/portals/hyprland.portal",
                "/usr/lib/xdg-desktop-portal-hyprland",
                "/usr/libexec/xdg-desktop-portal-hyprland",
            ]),
        ],
        features: &["hotkeys"],
        commands: &["hyprctl"],
        arch_packages: &["xdg-desktop-portal-hyprland"],
        debian_packages: &["xdg-desktop-portal-hyprland"],
        rpm_packages: &["xdg-desktop-portal-hyprland"],
    },
    Definition {
        capability: Capability::Audio,
        label: "Audio controls",
        detail: "Volume, mute, and endpoint display through PipeWire.",
        tier: Tier::Optional,
        probes: &[Probe::Command("wpctl")],
        features: &["volume", "mute", "audio devices"],
        commands: &["wpctl"],
        arch_packages: &["wireplumber"],
        debian_packages: &["wireplumber"],
        rpm_packages: &["wireplumber"],
    },
    Definition {
        capability: Capability::Brightness,
        label: "Brightness controls",
        detail: "Native Linux backlight and external DDC/CI display brightness.",
        tier: Tier::Optional,
        probes: &[Probe::Brightness],
        features: &["brightness", "display control"],
        commands: &["ddcutil"],
        arch_packages: &["ddcutil"],
        debian_packages: &["ddcutil"],
        rpm_packages: &["ddcutil"],
    },
    Definition {
        capability: Capability::Network,
        label: "NetworkManager",
        detail: "Wi-Fi status, scanning, and connection control over NetworkManager D-Bus.",
        tier: Tier::Optional,
        probes: &[Probe::AnyPath(&[
            "/run/NetworkManager",
            "/var/run/NetworkManager",
        ])],
        features: &["network", "wifi"],
        commands: &[],
        arch_packages: &["networkmanager"],
        debian_packages: &["network-manager"],
        rpm_packages: &["NetworkManager"],
    },
    Definition {
        capability: Capability::Notifications,
        label: "Desktop notifications",
        detail: "Freedesktop notification server hosted by Hyprbaric, with observer fallback for an existing server.",
        tier: Tier::Optional,
        probes: &[Probe::AlwaysAvailable],
        features: &["notifications", "do not disturb"],
        commands: &[],
        arch_packages: &[],
        debian_packages: &[],
        rpm_packages: &[],
    },
    Definition {
        capability: Capability::SystemTray,
        label: "StatusNotifier tray",
        detail: "D-Bus StatusNotifier/AppIndicator item discovery and menus.",
        tier: Tier::Optional,
        probes: &[Probe::AlwaysAvailable],
        features: &["system tray"],
        commands: &[],
        arch_packages: &[],
        debian_packages: &[],
        rpm_packages: &[],
    },
    Definition {
        capability: Capability::Launcher,
        label: "App launching",
        detail: "XDG desktop entry discovery and launch helpers.",
        tier: Tier::Optional,
        probes: &[Probe::Command("gtk-launch")],
        features: &["launcher"],
        commands: &["gtk-launch"],
        arch_packages: &["gtk3"],
        debian_packages: &["libgtk-3-bin"],
        rpm_packages: &["gtk3"],
    },
    Definition {
        capability: Capability::Screenshot,
        label: "Screenshots",
        detail: "Region capture through Hyprland/Wayland screenshot tools.",
        tier: Tier::Optional,
        probes: &[
            Probe::AnyCommand(&["grimblast", "grim"]),
            Probe::Command("slurp"),
        ],
        features: &["screenshots"],
        commands: &["grimblast", "grim", "slurp"],
        arch_packages: &["grim", "slurp"],
        debian_packages: &["grim", "slurp"],
        rpm_packages: &["grim", "slurp"],
    },
    Definition {
        capability: Capability::Clipboard,
        label: "Clipboard",
        detail: "Copying screenshot paths and picked colors to the Wayland clipboard.",
        tier: Tier::Optional,
        probes: &[Probe::Command("wl-copy")],
        features: &["clipboard"],
        commands: &["wl-copy"],
        arch_packages: &["wl-clipboard"],
        debian_packages: &["wl-clipboard"],
        rpm_packages: &["wl-clipboard"],
    },
    Definition {
        capability: Capability::ColorPicker,
        label: "Color picker",
        detail: "Screen color sampling through hyprpicker.",
        tier: Tier::Optional,
        probes: &[Probe::Command("hyprpicker")],
        features: &["color picker"],
        commands: &["hyprpicker"],
        arch_packages: &["hyprpicker"],
        debian_packages: &["hyprpicker"],
        rpm_packages: &["hyprpicker"],
    },
    Definition {
        capability: Capability::Recording,
        label: "Screen recording",
        detail: "Region recording through wf-recorder and slurp.",
        tier: Tier::Optional,
        probes: &[Probe::AllCommands(&["wf-recorder", "slurp"])],
        features: &["screen recording"],
        commands: &["wf-recorder", "slurp"],
        arch_packages: &["wf-recorder", "slurp"],
        debian_packages: &["wf-recorder", "slurp"],
        rpm_packages: &["wf-recorder", "slurp"],
    },
    Definition {
        capability: Capability::NightLight,
        label: "Night light",
        detail: "Hyprland screen temperature control through hyprsunset.",
        tier: Tier::Optional,
        probes: &[Probe::AllCommands(&["hyprctl", "hyprsunset"])],
        features: &["night light", "schedule"],
        commands: &["hyprctl", "hyprsunset"],
        arch_packages: &["hyprsunset"],
        debian_packages: &["hyprsunset"],
        rpm_packages: &["hyprsunset"],
    },
    Definition {
        capability: Capability::Caffeine,
        label: "Caffeine",
        detail: "Sleep and idle inhibition through systemd-logind.",
        tier: Tier::Optional,
        probes: &[Probe::SystemdLogin],
        features: &["caffeine"],
        commands: &[],
        arch_packages: &["systemd"],
        debian_packages: &["systemd"],
        rpm_packages: &["systemd"],
    },
    Definition {
        capability: Capability::Power,
        label: "Power actions",
        detail: "Session, power profile, and firmware action support.",
        tier: Tier::Optional,
        probes: &[Probe::SystemdLogin],
        features: &["session actions", "power profiles"],
        commands: &[],
        arch_packages: &["systemd", "power-profiles-daemon", "upower"],
        debian_packages: &["systemd", "power-profiles-daemon", "upower"],
        rpm_packages: &["systemd", "power-profiles-daemon", "upower"],
    },
    Definition {
        capability: Capability::UserDirectories,
        label: "XDG user directories",
        detail: "Downloads, videos, screenshots, and config path resolution.",
        tier: Tier::Optional,
        probes: &[Probe::Command("xdg-user-dir")],
        features: &["file destinations"],
        commands: &["xdg-user-dir"],
        arch_packages: &["xdg-user-dirs"],
        debian_packages: &["xdg-user-dirs"],
        rpm_packages: &["xdg-user-dirs"],
    },
];
