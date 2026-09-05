# Hyprbaric AppMenu proof

This is a deliberately small Hyprland plugin that provides the compositor-side
association for Hyprbaric's global menu. It advertises both
`org_kde_kwin_appmenu_manager` for Qt/KDE applications and `gtk_shell1` for
GTK applications. Each protocol supplies the otherwise-unavailable
`wl_surface → D-Bus endpoint` association; the plugin resolves that surface to
its Hyprland window address and exposes the captured values through a read-only
Hyprland IPC command.

Hyprbaric's Rust runtime consumes that IPC projection, reads Qt menus through
`com.canonical.dbusmenu` and GTK menus through `org.gtk.Menus`, then sends a
compact menu model to the Flutter bar. The plugin deliberately does not parse
either D-Bus protocol itself: it keeps the compositor boundary limited to the
Wayland association it alone can know.

## Build

The plugin must be compiled with headers and ABI-compatible dependencies from
the installed Hyprland version:

```sh
cmake -S hyprland-appmenu -B hyprland-appmenu/build
cmake --build hyprland-appmenu/build
```

When built through `flutter build linux`, the production plugin is installed as
`lib/hyprbaric-appmenu.so` inside the relocatable Hyprbaric bundle. Enable the
boot loader with:

```toml
[global_menu]
enabled = true
```

For a development build outside that bundle, point `plugin_path` at the shared
object produced by this CMake project.

## Prove the protocol

Load the built plugin into a running Hyprland session:

```sh
hyprctl plugin load "$PWD/hyprland-appmenu/build/hyprbaric-appmenu.so"
hyprctl hyprbaric-appmenu -j
```

Start or restart a Wayland-native AppMenu-capable application, then query the
mapping again. A successful capture looks like:

```json
[
  {
    "surface": 42,
    "address": "0x123456789abc",
    "service": "org.kde.kate-12345",
    "path": "/MenuBar/1"
  }
]
```

`surface` is a client-local protocol ID, while `address` is the matching
Hyprland window address used by the focused-window reader.

## Protocol probe

The build also produces `hyprbaric-appmenu-probe`, a minimal Wayland client that
creates a real `wl_surface` and publishes a known endpoint. It separates
protocol-server validation from toolkit-specific AppMenu configuration:

```sh
hyprland-appmenu/build/hyprbaric-appmenu-probe --hold-ms 10000 &
hyprctl hyprbaric-appmenu -j
```

The query should contain `org.hyprbaric.AppMenuProbe` while the probe is still
running, then return an empty list after it exits.

## KWrite integration probe

Qt/KDE applications publish their AppMenu endpoint only when a compatible
registrar name is present on the session bus. The build therefore also produces
`hyprbaric-kappmenuview-probe`, which owns the names required for a local
KWrite integration test:

```sh
hyprland-appmenu/build/hyprbaric-kappmenuview-probe &
QT_QPA_PLATFORM=wayland kwrite &
hyprctl hyprbaric-appmenu -j
```

After KWrite starts, the query should show its D-Bus service and `/MenuBar/*`
path alongside its Hyprland address. The Hyprbaric bar can then render its
File, Edit, View, and other top-level menus.

## GTK integration probe

The build also produces `hyprbaric-gtk-menu-probe`, a real GTK4
`GtkApplication` which publishes a `GMenuModel` menubar through GTK's Wayland
shell protocol:

```sh
GDK_BACKEND=wayland hyprland-appmenu/build/hyprbaric-gtk-menu-probe &
hyprctl hyprbaric-appmenu -j
```

Its endpoint has `"kind": "gtk"` and a `path` beneath
`/org/hyprbaric/GtkMenuProbe/menus/menubar`. Focus the probe and Hyprbaric
renders its File, Edit, and View sections. Headerbar-first GTK applications
that do not set a menubar correctly yield no global-menu sections; that is a
property of the application export, not a plugin failure.

This proof reads the direct menu level; nested submenu navigation and item
activation remain follow-up work.

Unload the proof after testing:

```sh
hyprctl plugin unload "$PWD/hyprland-appmenu/build/hyprbaric-appmenu.so"
```

The protocol XML is the version-1 AppMenu contract currently distributed with
Qt Wayland. Version 1 contains every request needed for this proof.
