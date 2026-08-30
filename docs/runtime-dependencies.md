# Runtime Dependencies

Hyprbaric is Linux-only and targets Hyprland. The packaging source of truth is
[`packaging/runtime_capabilities.yaml`](../packaging/runtime_capabilities.yaml);
the Rust runtime mirrors that contract when it probes the host at startup.

Core dependencies should be installed by distro packages. Optional dependencies
enable specific widgets or actions; when an optional backend is missing,
Hyprbaric should keep the UI visible but disable or degrade only that feature.

## Core

| Capability | Arch / Pacman | Debian / Ubuntu | RPM |
| --- | --- | --- | --- |
| Hyprland compositor | `hyprland` | `hyprland` | `hyprland` |
| GTK layer-shell host | `gtk3`, `gtk-layer-shell`, `wayland` | `libgtk-3-0`, `libgtk-layer-shell0`, `libwayland-client0` | `gtk3`, `gtk-layer-shell`, `wayland` |

## Services

| Capability | Arch / Pacman | Debian / Ubuntu | RPM |
| --- | --- | --- | --- |
| Global shortcuts portal | `xdg-desktop-portal-hyprland` | `xdg-desktop-portal-hyprland` | `xdg-desktop-portal-hyprland` |

## Optional Features

| Feature | Arch / Pacman | Debian / Ubuntu | RPM |
| --- | --- | --- | --- |
| Audio controls | `wireplumber` | `wireplumber` | `wireplumber` |
| Brightness controls | `ddcutil` for external displays; native backlight otherwise | `ddcutil` for external displays; native backlight otherwise | `ddcutil` for external displays; native backlight otherwise |
| Network controls | `networkmanager` | `network-manager` | `NetworkManager` |
| App launcher desktop entries | `gtk3` | `libgtk-3-bin` | `gtk3` |
| Screenshots | `grim`, `slurp` | `grim`, `slurp` | `grim`, `slurp` |
| Clipboard integration | `wl-clipboard` | `wl-clipboard` | `wl-clipboard` |
| Color picker | `hyprpicker` | `hyprpicker` | `hyprpicker` |
| Screen recording | `wf-recorder`, `slurp` | `wf-recorder`, `slurp` | `wf-recorder`, `slurp` |
| Night light | `hyprsunset` | `hyprsunset` | `hyprsunset` |
| Caffeine inhibitor | `systemd` | `systemd` | `systemd` |
| Power status and profiles | `systemd`, `power-profiles-daemon`, `upower` | `systemd`, `power-profiles-daemon`, `upower` | `systemd`, `power-profiles-daemon`, `upower` |
| User directory resolution | `xdg-user-dirs` | `xdg-user-dirs` | `xdg-user-dirs` |

## Notifications

Hyprbaric includes its own Freedesktop notification server and normally claims
`org.freedesktop.Notifications` on the user session bus. No separate
notification daemon is required. If another server already owns that name,
Hyprbaric leaves it in place and falls back to observing its notifications.

Sandboxed applications commonly send notifications through XDG Desktop Portal.
Those applications also need a selected portal backend that implements the
Notification portal; this is separate from the desktop notification server
itself.

## Package Policy

AppImage, DEB, RPM, Pacman, and AUR packaging should all install the core and
service dependencies as hard dependencies. Optional dependencies should stay
recommended or optional package metadata so users can install a lean bar and add
feature backends as needed.

Hyprbaric probes optional backends at startup and reports them in
Settings > About > System. The intended behavior is:

- Missing core dependencies are packaging errors.
- Missing service dependencies should leave the affected integration pending or
  unavailable without crashing the bar.
- Missing optional dependencies should gray out only the related feature.
