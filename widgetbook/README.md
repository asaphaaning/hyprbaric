# Hyprbaric Widgetbook

This sibling Flutter app catalogs production Hyprbaric widgets without booting
the layer-shell runner or Rust backend. It imports the root package through a
local path dependency, so use cases exercise the same widgets shipped in the
bar.

From this directory:

```sh
flutter pub get
dart run build_runner build
flutter run -d linux
```

Use `flutter run -d chrome` for the web catalog. After adding or renaming an
annotated use case, rerun the generator command.

The first catalog slice includes shared badges, toggles, and action rows;
bar-level battery states, profile pads, and the fully composed power panel; the
notification button, header, count pill, row, list, empty state, and fully
composed notification panel; and the full controls console with its capture,
recording, inspect, rocker, tray, and settings atoms.
The audio catalog similarly covers the complete mixer panel, its output and
input strips, faders, readouts, mute controls, brightness deck, and supporting
header, rail, footer, divider, and unavailable message atoms.
The bar slice adds the workspace indicator strip across its roman, numeric,
read-only, special-workspace, and unfocused-output states, its button, nav
button, and placeholder atoms, and the left and center clusters driven by
overridden compositor signals.
The setup slice presents the first-run guide card at every step, plus its stage
preview and control column in isolation.
Every widget the catalog exports now has a story: the OSD header, readout,
meter, scale, and segment atoms, the toast app tag and corner brackets, and the
settings sidebar, tab button, content header, tab body, and keybinding row.
