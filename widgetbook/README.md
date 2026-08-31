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
