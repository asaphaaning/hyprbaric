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

When built through `flutter build linux` on a host providing `hyprland.pc`, the production plugin is installed as
`lib/hyprbaric-appmenu.so` inside the relocatable Hyprbaric bundle, and the
source for that plugin is always copied to `data/hyprland-appmenu`. Generic
release builders without the Hyprland SDK ship source without a prebuilt plugin.
The runtime compiles it against the user's installed Hyprland headers, or falls
back to hyprpm. Global menus therefore need a matching SDK and CMake (or a
configured hyprpm installation); the rest of the bar does not need build tools.
The CMake option `HYPRBARIC_BUILD_APPMENU=ON` requires a prebuilt companion and
fails if its SDK is missing; `OFF` explicitly selects source-only packaging.
Enable the boot
loader with:

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
renders its File, Edit, and View sections. File has New, Quit (`Ctrl+Q` from
the `accel` attribute), and a parameterized `notes.txt` row. Edit has a
disabled Undo. View has a checked Fullscreen toggle and a Left/Center/Right
radio group. New also registers `<Primary>n` through
`gtk_application_set_accels_for_action`; that table is not on D-Bus, so New
shows no shortcut. GTK often calls `set_dbus_properties` before Hyprland has
created a window for that surface; the snapshot resolves the address live, and
`present` fills it in if the first lookup missed. The companion holds a weak
handle to Hyprland's surface object rather than a raw `wl_resource*`, so a
client that destroys the surface while leaving the AppMenu object alive cannot
crash the compositor. The last resolved window address is kept until then. Headerbar-first GTK
applications that do not set a menubar correctly yield no global-menu
sections; that is a property of the application export, not a plugin failure.

GTK3 can also call `gtk_application_set_app_menu` next to the menubar. The
companion then emits both `path` (the menubar) and `app_menu_path`. Hyprbaric
prepends that application menu as one heading. Prove it with:

```sh
GDK_BACKEND=wayland hyprland-appmenu/build/hyprbaric-gtk3-dual-menu-probe &
hyprctl hyprbaric-appmenu -j
```

The GTK row should name both `/menus/menubar` and `/menus/appmenu`. Focus the
probe and the bar shows the window title, then File and Edit.

Traditional `GtkMenuBar` applications (GIMP and similar) never call
`gtk_shell1`. On Wayland they need the GTK AppMenu module
(`GTK_MODULES=appmenu-gtk-module` and `UBUNTU_MENUPROXY=1` in Hyprland) so they
export a menu the companion can capture. On XWayland they register with
`com.canonical.AppMenu.Registrar`; Hyprbaric matches that table to the focused
window by X11 id. See `website/docs/global-menu.mdx` for the user-facing setup.

Unload the proof after testing:

```sh
hyprctl plugin unload "$PWD/hyprland-appmenu/build/hyprbaric-appmenu.so"
```

The protocol XML is the version-1 AppMenu contract currently distributed with
Qt Wayland. Version 1 contains every request needed for this proof.
