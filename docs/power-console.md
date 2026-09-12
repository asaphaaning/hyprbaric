# Battery console

`PowerPanel` is the shared battery popover used by the bar and Widgetbook. Its 450 logical-pixel width is also used by the dropdown input region and landing preview registry. The existing Rust power status and profile commands remain the source of truth.

The charcoal glass shell uses `HyprInstrumentSurface`, shared directly with the mixer and network panel. It owns their common translucent gradient, text palette and corner-safe `HyprGlassSurface` frame. Translucent battery and telemetry bays retain different tones; Hyprland supplies desktop blur. `PowerBay` and `PowerMetric` compose the detail strip; `PowerIcon` supplies outlined measurement symbols and `PowerReadout` shares the highlighted numbers and smaller units, while `PowerProfilePad` uses the shared `HyprInteractiveTile` interaction primitive. Each profile is isolated by a repaint boundary.

The charge rail represents the reported percentage across 29 segments. Missing charge is not interpreted as zero. The readouts preserve unavailable telemetry as dashes; desktop systems show a SYSTEM POWER heading and profile selection, omitting the charge stage and battery telemetry entirely. Charging, discharging, full, empty, pending and unknown states have explicit header labels. The header is a text-only status indicator, not a selector for hardware-controlled battery states.

Profile silhouettes illustrate the intent of each policy, not measured history: saver falls, balanced peaks, and performance rises. Only backend-advertised profiles are interactive. Selection callbacks, confirmation from status, and command failures retain the existing power-controller behavior.

Widgetbook's **Power / PowerPanel / Reference** story shows the supplied 12%, 35-minute scenario with interactive profiles. Charging, full, loading, unavailable and command-failure stories remain available alongside it.

The header uses the shared 13px Inter title and normalized 24px icon bounds. Power sections use the common metadata role; profile labels are 13.5px and telemetry values 14.5px. Charge and time share a 40px preferred readout, with smaller unit suffixes. A fixed 128px time bay prevents hour estimates from moving the heading toward the notch, and unusually long estimates scale down within that bay. The notch shoulders are inset 12px from the fixed readout columns, keeping their labels clear of the curved background. Widgetbook includes a 12h 59m estimate alongside the minutes and desktop cases.
