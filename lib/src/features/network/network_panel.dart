import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../../layer_shell_controller.dart';
import '../../state/layer_shell.dart';
import 'network_connection_views.dart';
import 'network_console.dart';
import 'network_controller.dart';
import 'network_entry_state.dart';
import 'network_formatting.dart';
import 'network_join_form.dart';
import 'network_navigation.dart';
import 'network_password_prompt.dart';
import 'network_traffic_history.dart';
import 'network_traffic_ring.dart';

/// The production network console, also rendered directly by Widgetbook.
class NetworkPanel extends ConsumerStatefulWidget {
  const NetworkPanel({
    super.key,
    this.borderRadius = radius,
    required this.status,
    required this.latestResult,
    required this.onSetWifiEnabled,
    required this.onConnect,
    required this.onOpenSettings,
    this.onScan,
    this.onJoin,
    this.onDisconnect,
    this.onAutoConnect,
    this.history,
    this.initialTab = NetworkTab.wifi,
    this.initialPage = const WifiOverview(),
  });

  static const double width = 396;
  static const BorderRadius radius = BorderRadius.all(Radius.circular(13));
  final BorderRadius borderRadius;
  final AsyncValue<NetworkStatus> status;
  final NetworkCommandResult? latestResult;
  final ValueChanged<bool> onSetWifiEnabled;
  final void Function(NetworkEntry entry, String? password) onConnect;
  final VoidCallback onOpenSettings;
  final VoidCallback? onScan;
  final ValueChanged<NetworkJoinRequest>? onJoin;
  final ValueChanged<NetworkInterface>? onDisconnect;
  final void Function(NetworkInterface, {required bool enabled})? onAutoConnect;

  /// Optional externally collected history, useful for replay and previews.
  final TrafficHistory? history;
  final NetworkTab initialTab;
  final WifiPage initialPage;

  @override
  ConsumerState<NetworkPanel> createState() => NetworkPanelState();
}

class NetworkPanelState extends ConsumerState<NetworkPanel> {
  static const _keyboardOwner = 'network-password';
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode(debugLabel: _keyboardOwner);
  final _clock = Stopwatch();
  Timer? _joinDeadline;
  late final LayerShellController _layerShellController;
  late NetworkTab _tab;
  late WifiPage _page;
  TrafficHistory _history = const TrafficHistory.empty();
  NetworkStatus? _lastSampledStatus;
  bool? _pendingWifiEnabled;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _layerShellController = ref.read(layerShellControllerProvider);
    _tab = widget.initialTab;
    _page = widget.initialPage;
    _clock.start();
    _recordTraffic(widget.status.asData?.value);
    if (_page is WifiCredentials || _page is WifiOther) _claimKeyboard();
  }

  @override
  void didUpdateWidget(covariant NetworkPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final status = widget.status.asData?.value;
    _recordTraffic(status);
    if (status != null &&
        status != oldWidget.status.asData?.value &&
        status.wifiEnabled == _pendingWifiEnabled) {
      _pendingWifiEnabled = null;
    }
    final result = widget.latestResult;
    if (!identical(result, oldWidget.latestResult) &&
        result is NetworkCommandResultFailed &&
        result.command is NetworkCommandSetWifiEnabled) {
      _pendingWifiEnabled = null;
    }
    if (!(_pendingWifiEnabled ?? status?.wifiEnabled ?? false) ||
        status?.devicePresent == false) {
      _navigate(const WifiOverview());
      return;
    }
    final selected = switch (_page) {
      WifiCredentials(:final entry) || WifiJoining(:final entry) => entry,
      _ => null,
    };
    if (selected == null) return;
    if (status?.activeSsid == selected.ssid &&
        status!.networks.any(
          (entry) =>
              entry.ssid == selected.ssid &&
              entry.state == NetworkEntryState.active,
        )) {
      _navigate(const WifiOverview());
    } else if (!identical(result, oldWidget.latestResult)) {
      switch (result) {
        case NetworkCommandResultFailed(
              command: NetworkCommandConnect(:final ssid),
              :final message,
            )
            when ssid == selected.ssid:
          _navigate(
            selected.secure
                ? WifiCredentials(selected, error: message)
                : WifiFailure(selected, message),
          );
        case NetworkCommandResultStarted(
              command: NetworkCommandConnect(:final ssid),
            )
            when ssid == selected.ssid:
          _navigate(WifiJoining(selected));
        case _:
          break;
      }
    }
  }

  void _claimKeyboard() {
    unawaited(_layerShellController.claimKeyboard(_keyboardOwner));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _page is WifiCredentials) {
        _passwordFocusNode.requestFocus();
      }
    });
  }

  void _navigate(WifiPage next) {
    if (_page is WifiJoining &&
        next is WifiJoining &&
        (_page as WifiJoining).entry.ssid == next.entry.ssid) {
      return;
    }
    _joinDeadline?.cancel();
    if (next case WifiJoining(:final entry)) {
      _joinDeadline = Timer(const Duration(seconds: 45), () {
        if (!mounted || !identical(_page, next)) return;
        const message = 'Connection not confirmed. Try again.';
        setState(
          () => _navigate(
            entry.secure
                ? WifiCredentials(entry, error: message)
                : WifiFailure(entry, message),
          ),
        );
      });
    }
    final wasEditing = _page is WifiCredentials || _page is WifiOther;
    final editing = next is WifiCredentials || next is WifiOther;
    _page = next;
    if (wasEditing && !editing) {
      _passwordFocusNode.unfocus();
      _passwordController.clear();
      _showPassword = false;
      unawaited(_layerShellController.releaseKeyboard(_keyboardOwner));
    } else if (!wasEditing && editing) {
      _claimKeyboard();
    }
  }

  void _choose(NetworkEntry entry) {
    if (entry.isActive) return;
    if (entry.secure) {
      setState(() => _navigate(WifiCredentials(entry)));
    } else {
      setState(() => _navigate(WifiJoining(entry)));
      widget.onConnect(entry, null);
    }
  }

  void _submit(NetworkEntry entry) {
    final password = _passwordController.text;
    if (entry.secure && password.isEmpty) {
      setState(
        () => _navigate(WifiCredentials(entry, error: 'Password required.')),
      );
      return;
    }
    setState(() => _navigate(WifiJoining(entry)));
    widget.onConnect(entry, entry.secure ? password : null);
  }

  void _recordTraffic(NetworkStatus? status) {
    if (status == null || identical(status, _lastSampledStatus)) return;
    _lastSampledStatus = status;
    _history = _history.record(
      TrafficSample(
        at: _clock.elapsed,
        download: status.traffic.download.bytesPerSecond.toInt() * 8 / 1000000,
        upload: status.traffic.upload.bytesPerSecond.toInt() * 8 / 1000000,
      ),
    );
  }

  @override
  void dispose() {
    if (_page is WifiCredentials || _page is WifiOther) {
      unawaited(_layerShellController.releaseKeyboard(_keyboardOwner));
    }
    _joinDeadline?.cancel();
    _clock.stop();
    _passwordFocusNode.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status.asData?.value;
    final enabled = _pendingWifiEnabled ?? status?.wifiEnabled ?? false;
    final online =
        status?.interfaces.any((entry) => entry.active && entry.name != 'lo') ??
        false;
    final message =
        status?.message ??
        switch (widget.latestResult) {
          NetworkCommandResultFailed(
            command: NetworkCommandDisconnect() ||
                NetworkCommandSetAutoConnect() ||
                NetworkCommandSetWifiEnabled() ||
                NetworkCommandOpenSettings() ||
                NetworkCommandScan(),
            :final message,
          ) =>
            message,
          _ => widget.status.hasError ? 'Network service unavailable.' : null,
        };
    return SizedBox(
      width: NetworkPanel.width,
      child: NetworkSurface(
        radius: widget.borderRadius,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(13),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0x20464A57),
                      Color(0x0C282D3A),
                      Color(0x163D4355),
                    ],
                  ),
                ),
                child: NetworkTrafficBacklight(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 9, 12, 2),
                        child: Row(
                          children: [
                            const NetworkTopologyIcon(),
                            const SizedBox(width: 11),
                            Text(
                              'NETWORK',
                              style: NetworkConsole.label.copyWith(
                                fontSize: 13,
                                letterSpacing: 2.2,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              widget.status.isLoading
                                  ? 'LOADING'
                                  : online
                                  ? 'ONLINE'
                                  : 'OFFLINE',
                              style: NetworkConsole.label.copyWith(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Network options',
                              onPressed: widget.onOpenSettings,
                              icon: const Icon(Icons.more_horiz_rounded),
                              iconSize: 19,
                              color: NetworkConsole.accent,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                      NetworkTrafficRing(history: widget.history ?? _history),
                      _TrafficTotals(traffic: status?.traffic),
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0x22474A59),
                      Color(0x102B2F3B),
                      Color(0x263E3C53),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 11, 11, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      NetworkTabs(
                        selected: _tab,
                        onSelected: (tab) => setState(() {
                          _tab = tab;
                          _navigate(const WifiOverview());
                        }),
                      ),
                      const SizedBox(height: 17),
                      if (_tab != NetworkTab.wifi)
                        NetworkProfileView(
                          onDisconnect:
                              widget.onDisconnect ??
                              ref
                                  .read(networkControllerProvider.notifier)
                                  .disconnect,
                          tab: _tab,
                          interfaces: status?.interfaces ?? const [],
                          onSettings: widget.onOpenSettings,
                        )
                      else if (status?.devicePresent == false)
                        const NetworkCard(child: Text('No Wi-Fi device found.'))
                      else
                        switch (_page) {
                          WifiOverview() => NetworkWifiOverview(
                            onDisconnect:
                                widget.onDisconnect ??
                                ref
                                    .read(networkControllerProvider.notifier)
                                    .disconnect,
                            onAutoConnect:
                                widget.onAutoConnect ??
                                ref
                                    .read(networkControllerProvider.notifier)
                                    .setAutoConnect,
                            status: status,
                            enabled: enabled,
                            onToggle: () {
                              setState(() {
                                _pendingWifiEnabled = !enabled;
                                if (enabled) _navigate(const WifiOverview());
                              });
                              widget.onSetWifiEnabled(!enabled);
                            },
                            onChoose: () =>
                                setState(() => _navigate(const WifiChoosing())),
                            onSettings: widget.onOpenSettings,
                          ),
                          WifiChoosing() => NetworkChooser(
                            networks: enabled
                                ? status?.networks ?? const []
                                : const [],
                            scanning: status?.scanning ?? false,
                            onSelect: _choose,
                            onScan:
                                widget.onScan ??
                                ref
                                    .read(networkControllerProvider.notifier)
                                    .scan,
                            onOther: () =>
                                setState(() => _navigate(const WifiOther())),
                            onBack: () =>
                                setState(() => _navigate(const WifiOverview())),
                          ),
                          WifiOther() => NetworkJoinForm(
                            result: widget.latestResult,
                            activeSsid: status?.activeSsid,
                            onJoin:
                                widget.onJoin ??
                                ref
                                    .read(networkControllerProvider.notifier)
                                    .join,
                            onCancel: () =>
                                setState(() => _navigate(const WifiChoosing())),
                            onConnected: () =>
                                setState(() => _navigate(const WifiOverview())),
                          ),
                          WifiCredentials(:final entry, :final error) =>
                            NetworkPasswordPrompt(
                              ssid: entry.ssid,
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              showPassword: _showPassword,
                              connecting: false,
                              errorMessage: error,
                              onToggleVisibility: () => setState(
                                () => _showPassword = !_showPassword,
                              ),
                              onCancel: () => setState(
                                () => _navigate(const WifiChoosing()),
                              ),
                              onSubmit: () => _submit(entry),
                            ),
                          WifiFailure(:final entry, :final message) =>
                            NetworkCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message,
                                    style: NetworkConsole.body.copyWith(
                                      color: const Color(0xFFFFAC97),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      NetworkAction(
                                        label: 'Back',
                                        onPressed: () => setState(
                                          () => _navigate(const WifiChoosing()),
                                        ),
                                      ),
                                      NetworkAction(
                                        label: 'Try again',
                                        primary: true,
                                        onPressed: () => _choose(entry),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          WifiJoining(:final entry) => NetworkCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Connecting to ${entry.ssid}…',
                                  style: NetworkConsole.body.copyWith(
                                    color: NetworkConsole.text,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const LinearProgressIndicator(
                                  minHeight: 2,
                                  color: NetworkConsole.downloadText,
                                  backgroundColor: NetworkConsole.line,
                                ),
                                const SizedBox(height: 8),
                                NetworkAction(
                                  label: 'Back to networks',
                                  onPressed: () => setState(
                                    () => _navigate(const WifiChoosing()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        },
                      if (message != null)
                        Padding(
                          padding: const EdgeInsets.all(9),
                          child: Text(
                            message,
                            style: NetworkConsole.body.copyWith(
                              color: const Color(0xFFFFAC97),
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      const Divider(
                        height: 1,
                        thickness: .5,
                        color: NetworkConsole.line,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: NetworkAction(
                              label: _tab == NetworkTab.vpn
                                  ? 'Import profile'
                                  : 'Add connection',
                              icon: Icons.add_rounded,
                              compact: true,
                              onPressed: widget.onOpenSettings,
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: NetworkAction(
                                label: 'Network Settings',
                                trailing: Icons.north_east_rounded,
                                compact: true,
                                onPressed: widget.onOpenSettings,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrafficTotals extends StatelessWidget {
  const _TrafficTotals({required this.traffic});
  final NetworkTraffic? traffic;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
    child: Column(
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: traffic == null
                    ? '—'
                    : formatBytes(traffic!.download.totalBytes),
                style: NetworkConsole.body.copyWith(
                  fontSize: 15,
                  color: NetworkConsole.downloadText,
                ),
              ),
              const TextSpan(text: ' received  ·  '),
              TextSpan(
                text: traffic == null
                    ? '—'
                    : formatBytes(traffic!.upload.totalBytes),
                style: NetworkConsole.body.copyWith(
                  fontSize: 15,
                  color: NetworkConsole.uploadText,
                ),
              ),
              const TextSpan(text: ' sent'),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          traffic?.pingMs == null
              ? 'Latency unavailable · System totals'
              : '${traffic!.pingMs} ms latency · System totals',
          style: NetworkConsole.meta,
        ),
      ],
    ),
  );
}
