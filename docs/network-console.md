# Network console

The bar and Widgetbook share `NetworkPanel`. The panel uses translucent charcoal
sections and the same corner-safe glass frame as the audio mixer. Hyprland
supplies desktop blur. A blue radial backlight fades beneath the lower traffic
arcs while the surrounding glass retains its charcoal tone. Panel width and native hit-region radius come from the
component's canonical geometry; shorter screens scroll inside that frame.

The outer violet ring shows download and the inner pink ring shows upload.
Both record the last 60 seconds, with the newest observation at twelve o'clock
and older observations clockwise: 15 seconds right, 30 below, 45 left. A newly
started collector has an empty unrecorded arc. The fixed visual scales are
60 Mbps download and 10 Mbps upload. The numeric readouts remain accurate above
those scales. Histories retain idle observations and survive popover closure.

Traffic and byte totals aggregate non-loopback system interfaces. Totals are
system counters, not daily usage, and virtual interfaces may count traffic also
seen on a physical interface. Latency is the existing best-effort reachability
measurement. Packet loss is not measured. Selecting a connection tab does not
turn the aggregate ring into a per-interface measurement.

Wi-Fi supports nearby-network selection, password entry, radio enablement,
interface autoconnect, and device-scoped disconnect. “Join other network” can
create a hidden or broadcast profile using open or WPA/WPA2 Personal security.
SSID limits use UTF-8 bytes; credentials retain meaningful whitespace and are
redacted from dispatch logging. Personal keys accept 8–63 ASCII characters or
a 64-digit hexadecimal PSK. Enterprise and additional security configurations
remain available through Network Settings.

Ethernet and tunnel views use device families supplied by NetworkManager. They
show reported addresses and link speeds rather than guessing from interface
names. Configure, profile import, and advanced settings open the system network
settings application. Disconnect uses the selected NetworkManager device path.

The Widgetbook reference uses simulated observations and local action callbacks.
Its chronology stories show 4, 27, and 58 seconds of recorded history. None of
those preview values or simulated actions are used by the production bar.

Interaction painting is isolated from the traffic backlight and trace. Hovering
action buttons or animating tab plates does not repaint the large radial wash;
the complex trace is eligible for Flutter raster caching between observations.
Tab foreground and background share a transition curve and fixed border geometry.
Widgetbook anchors the reference at the top, matching the bar, so changes in
connection-card height do not move the tab targets under the pointer.

The documentation landing embed starts with a full simulated minute of traffic.
Its independent download/upload bursts stay within the real ring scales, then
advance the same history at no more than ten updates per second. Reduced motion
and inactive ticker views pause updates without clearing the pre-roll. This
simulation is defined in Widgetbook and never feeds the production bar.

Typography follows the mixer's contrast hierarchy: 13 px medium action text,
11.5 px secondary facts, and brighter violet/pink readouts. A dark central disc
separates numeric values from the blue radial glow. Time labels sit outside the
dotted perimeter with dedicated lower clearance, rather than sharing its edge.
