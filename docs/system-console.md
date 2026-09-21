# System occupancy console

`SystemChip` and `SystemPanel` are the shared CPU and memory instrument used by
the bar and Widgetbook. The chip is on by default. Turn it off with
`[modules.system_occupancy]` or the Settings Modules toggle. It sits to the left of the tray.
Opening it reveals a 480-pixel charcoal glass popover. Rust `/proc`, hwmon, and
root `statvfs` snapshots remain the source of truth.

The panel reuses `HyprInstrumentSurface` and `HyprInstrumentHeader`. The analog
CPU gauge is the centrepiece: occupancy is mapped through `20 · log10(ratio)`
onto a −30 dB to 0 dB VU face, so a 12% reading sits near −18 dB. The needle
glides into each new sample rather than stepping with the poll. Segmented
CPU, memory, and disk meters are the mixer channel ladder turned on its side. Footer wells match
the battery strip: uptime, package temperature, and process count. Missing
telemetry is shown as dashes rather than zero.

Widgetbook ships Reference, High load, Idle, Loading, Unavailable, Interactive,
and Chip and popover stories, plus isolated gauge, meter, sparkline, and symbol
atoms. The live bar renders the same widgets as the catalog.
