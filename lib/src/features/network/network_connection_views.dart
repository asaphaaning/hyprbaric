import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import '../../widgets/primitives/primitives.dart';
import 'network_console.dart';
import 'network_entry_state.dart';
import 'network_navigation.dart';

/// Pill navigation shared by all connection states.
class NetworkTabs extends StatelessWidget {
  const NetworkTabs({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final NetworkTab selected;
  final ValueChanged<NetworkTab> onSelected;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Container(
      height: 39,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0x99080B12),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0x88515D82), width: .6),
      ),
      child: Row(
        children: [
          for (final tab in NetworkTab.values)
            Expanded(
              child: Semantics(
                selected: tab == selected,
                child: HyprInteractionRegion(
                  semanticLabel: switch (tab) {
                    NetworkTab.wifi => 'Wi-Fi',
                    NetworkTab.ethernet => 'Ethernet',
                    NetworkTab.vpn => 'VPN',
                  },
                  onPressed: () => onSelected(tab),
                  builder: (context, state) => AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: tab == selected
                            ? const [Color(0xFFE0DEFF), Color(0xFF9A9FD8)]
                            : state.hovered || state.pressed
                            ? const [Color(0x22565682), Color(0x22565682)]
                            : const [Color(0x00E0DEFF), Color(0x009A9FD8)],
                      ),
                      border: Border.all(
                        color: tab == selected
                            ? const Color(0xAACECFFF)
                            : const Color(0x00CECFFF),
                        width: .5,
                      ),
                    ),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOutCubic,
                      style: NetworkConsole.label.copyWith(
                        color: tab == selected
                            ? const Color(0xFF101529)
                            : NetworkConsole.accent,
                      ),
                      child: Text(switch (tab) {
                        NetworkTab.wifi => 'WI-FI',
                        NetworkTab.ethernet => 'ETHERNET',
                        NetworkTab.vpn => 'VPN',
                      }),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Active radio summary; unavailable facts are never inferred from an SSID.
class NetworkWifiOverview extends StatelessWidget {
  const NetworkWifiOverview({
    super.key,
    required this.status,
    required this.enabled,
    required this.onToggle,
    required this.onChoose,
    required this.onSettings,
    required this.onDisconnect,
    required this.onAutoConnect,
  });
  final NetworkStatus? status;
  final bool enabled;
  final VoidCallback onToggle;
  final VoidCallback onChoose;
  final VoidCallback onSettings;
  final ValueChanged<NetworkInterface> onDisconnect;
  final void Function(NetworkInterface, {required bool enabled}) onAutoConnect;

  @override
  Widget build(BuildContext context) {
    final active = status?.networks
        .where((entry) => entry.isActive)
        .firstOrNull;
    final radios =
        status?.interfaces
            .where((entry) => entry.kind == NetworkInterfaceKind.wifi)
            .toList() ??
        const <NetworkInterface>[];
    final radio =
        radios.where((entry) => entry.active).firstOrNull ?? radios.firstOrNull;
    final frequency = radio?.frequencyMhz;
    final band = frequency == null
        ? null
        : frequency >= 5925
        ? '6 GHz'
        : frequency >= 4900
        ? '5 GHz'
        : '2.4 GHz';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NetworkCard(
          child: Row(
            children: [
              const SizedBox(width: 30),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      !enabled
                          ? 'Wi-Fi off'
                          : status?.activeSsid ?? 'Not connected',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NetworkConsole.body.copyWith(
                        fontSize: 14,
                        color: NetworkConsole.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !enabled
                          ? 'Enable Wi-Fi to discover networks'
                          : active == null
                          ? 'Choose a nearby network'
                          : [
                              ?band,
                              active.secure ? 'Secured' : 'Open',
                              '${active.strength}% signal',
                            ].join(' · '),
                      style: NetworkConsole.meta,
                    ),
                  ],
                ),
              ),
              NetworkRadioSwitch(enabled: enabled, onToggle: onToggle),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: NetworkAction(
                label: 'Choose network…',
                icon: Icons.search_rounded,
                onPressed: onChoose,
                enabled: enabled,
              ),
            ),
            if (radio != null && radio.active && enabled)
              NetworkAction(
                label: 'Disconnect',
                icon: Icons.link_off_rounded,
                onPressed: () => onDisconnect(radio),
              )
            else
              NetworkAction(
                label: 'Manage',
                icon: Icons.link_rounded,
                onPressed: onSettings,
              ),
          ],
        ),
        const SizedBox(height: 3),
        const Divider(height: 1, thickness: .5, color: NetworkConsole.line),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (radio?.autoConnect case final bool autoConnect)
                Expanded(
                  child: NetworkCheck(
                    label: 'Auto-connect',
                    checked: autoConnect,
                    onChanged: (enabled) =>
                        onAutoConnect(radio!, enabled: enabled),
                  ),
                )
              else
                Expanded(
                  child: NetworkAction(
                    label: 'Preferences',
                    icon: Icons.tune_rounded,
                    onPressed: onSettings,
                  ),
                ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: NetworkAction(
                    label: 'Connection details',
                    trailing: Icons.chevron_right_rounded,
                    compact: true,
                    onPressed: onSettings,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: .5, color: NetworkConsole.line),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
          child: Text(
            radio == null
                ? ''
                : '${radio.name} · ${enabled ? radio.address ?? "No address" : "Disconnected"}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: NetworkConsole.meta,
          ),
        ),
      ],
    );
  }
}

/// Nearby access points use one compact, scrollable selection surface.
class NetworkChooser extends StatelessWidget {
  const NetworkChooser({
    super.key,
    required this.networks,
    required this.scanning,
    required this.onSelect,
    required this.onScan,
    required this.onOther,
    required this.onBack,
  });
  final List<NetworkEntry> networks;
  final bool scanning;
  final ValueChanged<NetworkEntry> onSelect;
  final VoidCallback onScan;
  final VoidCallback onOther;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => NetworkCard(
    padding: const EdgeInsets.fromLTRB(7, 3, 7, 3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            NetworkAction(
              label: 'Choose network',
              icon: Icons.search_rounded,
              onPressed: onBack,
            ),
            const Spacer(),
            Tooltip(
              message: 'Scan networks',
              child: IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 17,
                color: NetworkConsole.muted,
                onPressed: onScan,
                icon: scanning
                    ? const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: NetworkConsole.accent,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ),
          ],
        ),
        const Divider(height: 1, thickness: .5, color: NetworkConsole.line),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 160),
          child: networks.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(15),
                  child: Text(
                    scanning ? 'Scanning for networks…' : 'No networks found.',
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  children: [
                    for (final entry in networks)
                      HyprInteractionRegion(
                        semanticLabel:
                            '${entry.ssid}, ${entry.isActive ? "Connected" : "${entry.strength}% signal"}',
                        onPressed: () => onSelect(entry),
                        builder: (context, state) => Container(
                          height: 43,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: state.hovered || state.pressed
                                ? const Color(0x444F428E)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: state.hovered || state.pressed
                                  ? const Color(0x444B4B83)
                                  : Colors.transparent,
                              width: .5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.ssid,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: NetworkConsole.body.copyWith(
                                        color: NetworkConsole.text,
                                      ),
                                    ),
                                    Text(
                                      entry.isConnecting
                                          ? 'Connecting…'
                                          : entry.isActive
                                          ? 'Connected'
                                          : '${entry.secure ? "Secured" : "Open"} · ${entry.strength}% signal',
                                      style: NetworkConsole.meta,
                                    ),
                                  ],
                                ),
                              ),
                              if (entry.secure && !entry.isActive)
                                const Padding(
                                  padding: EdgeInsets.only(right: 9),
                                  child: Icon(
                                    Icons.lock_rounded,
                                    size: 12,
                                    color: NetworkConsole.muted,
                                  ),
                                ),
                              Icon(
                                entry.strength >= 50
                                    ? Icons.wifi_rounded
                                    : Icons.network_wifi_2_bar_rounded,
                                size: 19,
                                color: NetworkConsole.muted,
                              ),
                              if ((state.hovered || state.pressed) &&
                                  !entry.isActive)
                                const Padding(
                                  padding: EdgeInsets.only(left: 18),
                                  child: Text(
                                    'Connect',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFFD3A1FF),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        const Divider(height: 1, thickness: .5, color: NetworkConsole.line),
        Align(
          alignment: Alignment.centerLeft,
          child: NetworkAction(
            label: 'Join other network…',
            icon: Icons.add_rounded,
            onPressed: onOther,
          ),
        ),
      ],
    ),
  );
}

/// Device-specific detail cards use typed families supplied by NetworkManager.
class NetworkProfileView extends StatelessWidget {
  const NetworkProfileView({
    super.key,
    required this.tab,
    required this.interfaces,
    required this.onSettings,
    required this.onDisconnect,
  });
  final NetworkTab tab;
  final List<NetworkInterface> interfaces;
  final VoidCallback onSettings;
  final ValueChanged<NetworkInterface> onDisconnect;

  @override
  Widget build(BuildContext context) {
    final kind = tab == NetworkTab.vpn
        ? NetworkInterfaceKind.tunnel
        : NetworkInterfaceKind.ethernet;
    final devices = interfaces.where((entry) => entry.kind == kind).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (devices.isEmpty)
          NetworkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tab == NetworkTab.vpn
                      ? 'No tunnel interfaces'
                      : 'No Ethernet adapter',
                  style: NetworkConsole.body.copyWith(
                    fontSize: 14,
                    color: NetworkConsole.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tab == NetworkTab.vpn
                      ? 'Add or activate a VPN profile in Network Settings.'
                      : 'Connect an Ethernet adapter to view its link details.',
                ),
                const SizedBox(height: 12),
                NetworkAction(
                  label: tab == NetworkTab.vpn
                      ? 'Configure VPN…'
                      : 'Configure…',
                  onPressed: onSettings,
                ),
              ],
            ),
          ),
        for (final device in devices)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: NetworkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tab == NetworkTab.vpn
                                  ? 'Tunnel connection'
                                  : 'Wired connection',
                              style: NetworkConsole.body.copyWith(
                                fontSize: 14,
                                color: NetworkConsole.text,
                              ),
                            ),
                            Text(
                              '${device.name} · ${device.active ? "Connected" : "Disconnected"}',
                              style: NetworkConsole.meta,
                            ),
                          ],
                        ),
                      ),
                      if (device.active)
                        NetworkAction(
                          label: 'Disconnect',
                          compact: true,
                          onPressed: () => onDisconnect(device),
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  const Divider(
                    height: 1,
                    thickness: .5,
                    color: NetworkConsole.line,
                  ),
                  const SizedBox(height: 6),
                  if (tab == NetworkTab.ethernet)
                    NetworkDetail(
                      label: 'Link speed',
                      value: device.speedMbps == null
                          ? 'Unavailable'
                          : device.speedMbps! >= 1000
                          ? '${(device.speedMbps! / 1000).toStringAsFixed(1)} Gbps'
                          : '${device.speedMbps} Mbps',
                    ),
                  NetworkDetail(
                    label: tab == NetworkTab.vpn
                        ? 'Tunnel address'
                        : 'IP address',
                    value: device.address ?? 'Not assigned',
                  ),
                  NetworkDetail(label: 'Interface', value: device.name),
                  const SizedBox(height: 7),
                  const Divider(
                    height: 1,
                    thickness: .5,
                    color: NetworkConsole.line,
                  ),
                  const SizedBox(height: 3),
                  Align(
                    alignment: Alignment.centerRight,
                    child: NetworkAction(
                      label: tab == NetworkTab.vpn
                          ? 'Edit profile…'
                          : 'Configure…',
                      onPressed: onSettings,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Aligned label/value facts shared by Ethernet and tunnel cards.
class NetworkDetail extends StatelessWidget {
  const NetworkDetail({super.key, required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label, style: NetworkConsole.meta)),
        Expanded(
          child: Text(
            value,
            style: NetworkConsole.meta,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
