# Battery console

`PowerPanel` is the shared battery popover used by the bar and Widgetbook. Its 600 logical-pixel width is also used by the dropdown input region and landing preview registry. The existing Rust power status and profile commands remain the source of truth.

The charcoal glass shell uses `HyprGlassSurface`, including its matching corner clip and frame. Translucent battery and telemetry bays retain different tones; Hyprland supplies desktop blur. `PowerBay` and `PowerMetric` compose the detail strip, while `PowerProfilePad` uses the shared `HyprInteractiveTile` interaction primitive. Each profile is isolated by a repaint boundary.

The charge rail represents the reported percentage across 29 segments. Missing charge is not interpreted as zero. The readouts preserve unavailable telemetry as dashes; desktop systems retain profile selection without pretending to contain a battery. Charging, discharging, full, empty, pending and unknown states have explicit header labels. The header is a status indicator, not a selector for hardware-controlled battery states.

Profile silhouettes illustrate the intent of each policy, not measured history: saver falls, balanced peaks, and performance rises. Only backend-advertised profiles are interactive. Selection callbacks, confirmation from status, and command failures retain the existing power-controller behavior.

Widgetbook's **Power / PowerPanel / Reference** story shows the supplied 12%, 35-minute scenario with interactive profiles. Charging, full, loading, unavailable and command-failure stories remain available alongside it.
