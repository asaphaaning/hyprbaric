import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../../layer_shell_controller.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'network_entry_state.dart';
import 'network_formatting.dart';
import 'network_interfaces.dart';
import 'network_settings_row.dart';
import 'network_spectrum.dart';
import 'network_wifi_section.dart';

class NetworkPanel extends StatefulWidget {
  const NetworkPanel({
    super.key,
    required this.borderRadius,
    required this.status,
    required this.latestResult,
    required this.onSetWifiEnabled,
    required this.onConnect,
    required this.onOpenSettings,
  });

  final BorderRadius borderRadius;
  final AsyncValue<NetworkStatus> status;
  final NetworkCommandResult? latestResult;
  final ValueChanged<bool> onSetWifiEnabled;
  final void Function(NetworkEntry entry, String? password) onConnect;
  final VoidCallback onOpenSettings;

  @override
  State<NetworkPanel> createState() => NetworkPanelState();
}

class NetworkPanelState extends State<NetworkPanel> {
  static const int _trafficHistoryLength = 50;
  static const String _keyboardOwner = 'network-password';
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode(
    debugLabel: 'network-password',
  );
  // Rebuilt rather than mutated on every sample. The painter holds these
  // lists and compares them to decide whether to repaint, so a buffer edited
  // in place would leave it comparing one list against itself and the trace
  // would never advance past its first frame.
  List<double> _uploadHistory = const <double>[];
  List<double> _downloadHistory = const <double>[];
  List<DateTime> _sampleTimes = const <DateTime>[];
  String? _expandedSsid;
  String? _selectedSsid;
  String? _inlineError;
  NetworkStatus? _lastSampledStatus;
  bool? _pendingWifiEnabled;
  bool _passwordKeyboardActive = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _recordTraffic(widget.status.asData?.value);
  }

  @override
  void didUpdateWidget(covariant NetworkPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final NetworkStatus? status = widget.status.asData?.value;
    final NetworkStatus? oldStatus = oldWidget.status.asData?.value;
    _recordTraffic(status);
    if (_pendingWifiEnabled != null &&
        status != null &&
        status != oldStatus &&
        status.wifiEnabled == _pendingWifiEnabled) {
      _pendingWifiEnabled = null;
    }

    final NetworkCommandResult? result = widget.latestResult;
    if (!identical(result, oldWidget.latestResult)) {
      if (result case NetworkCommandResultFailed(
        command: NetworkCommandSetWifiEnabled(),
      )) {
        _pendingWifiEnabled = null;
      }
    }

    final bool wifiEnabled =
        _pendingWifiEnabled ?? status?.wifiEnabled ?? false;
    if (!wifiEnabled || status?.devicePresent == false) {
      _clearNetworkEntryState();
      _setPasswordKeyboardActive(false);
    }

    if (identical(result, oldWidget.latestResult)) {
      return;
    }

    switch (result) {
      case NetworkCommandResultFailed(
            command: NetworkCommandConnect(:final ssid),
            :final message,
          )
          when ssid == _expandedSsid || ssid == _selectedSsid:
        if (ssid == _expandedSsid) {
          setState(() => _inlineError = message);
        }
      case NetworkCommandResultStarted(
            command: NetworkCommandConnect(:final ssid),
          )
          when ssid == _expandedSsid || ssid == _selectedSsid:
        setState(() {
          _expandedSsid = null;
          _selectedSsid = null;
          _inlineError = null;
          _showPassword = false;
          _passwordController.clear();
        });
        _setPasswordKeyboardActive(false);
      case _:
        return;
    }
  }

  @override
  void dispose() {
    _setPasswordKeyboardActive(false);
    _passwordFocusNode.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _setPasswordKeyboardActive(bool active) {
    if (_passwordKeyboardActive == active) {
      return;
    }
    _passwordKeyboardActive = active;
    if (!active && _passwordFocusNode.hasFocus) {
      _passwordFocusNode.unfocus();
    }
    unawaited(
      active
          ? LayerShellController.claimKeyboard(_keyboardOwner)
          : LayerShellController.releaseKeyboard(_keyboardOwner),
    );
  }

  void _focusPasswordFieldIfExpanded(String ssid) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _expandedSsid != ssid) {
        return;
      }
      _passwordFocusNode.requestFocus();
    });
  }

  void _clearNetworkEntryState() {
    _expandedSsid = null;
    _selectedSsid = null;
    _inlineError = null;
    _showPassword = false;
    _passwordController.clear();
  }

  void _setWifiEnabled(bool enabled) {
    _setPasswordKeyboardActive(false);
    setState(() {
      _pendingWifiEnabled = enabled;
      if (!enabled) {
        _clearNetworkEntryState();
      }
    });
    widget.onSetWifiEnabled(enabled);
  }

  void _toggleEntry(NetworkEntry entry) {
    if (entry.isActive || entry.isConnecting) {
      return;
    }
    if (!entry.secure) {
      _setPasswordKeyboardActive(false);
      setState(() {
        _selectedSsid = entry.ssid;
        _expandedSsid = null;
        _inlineError = null;
        _passwordController.clear();
      });
      widget.onConnect(entry, null);
      return;
    }
    final bool closing = _expandedSsid == entry.ssid;
    _setPasswordKeyboardActive(!closing);
    setState(() {
      _expandedSsid = closing ? null : entry.ssid;
      _selectedSsid = closing ? null : entry.ssid;
      _inlineError = null;
      _showPassword = false;
      _passwordController.clear();
    });
    if (!closing) {
      _focusPasswordFieldIfExpanded(entry.ssid);
    }
  }

  void _submit(NetworkEntry entry) {
    final String password = _passwordController.text.trim();
    if (entry.secure && password.isEmpty) {
      setState(() => _inlineError = 'Password required.');
      return;
    }
    setState(() => _inlineError = null);
    widget.onConnect(entry, password);
  }

  void _cancelPasswordPrompt() {
    _setPasswordKeyboardActive(false);
    setState(_clearNetworkEntryState);
  }

  /// Records one sample per snapshot that arrives from Rust.
  ///
  /// Sampling is keyed on the snapshot rather than on the byte counts. An idle
  /// link reports the same rate every tick, and skipping those readings froze
  /// the trace instead of scrolling a flat line across it.
  ///
  /// No `setState` here on purpose: both callers already sit inside a build
  /// pass for this element, so the new series is picked up by the build that
  /// follows.
  void _recordTraffic(NetworkStatus? status) {
    if (identical(status, _lastSampledStatus)) {
      return;
    }
    _lastSampledStatus = status;

    final NetworkTraffic traffic = status?.traffic ?? _emptyTraffic();
    final double upload = megabytesPerSecond(traffic.upload.bytesPerSecond);
    final double download = megabytesPerSecond(traffic.download.bytesPerSecond);

    _uploadHistory = _appendTrafficSample(_uploadHistory, upload);
    _downloadHistory = _appendTrafficSample(_downloadHistory, download);
    _sampleTimes = _appendSample<DateTime>(_sampleTimes, DateTime.now());
  }

  List<double> _appendTrafficSample(List<double> samples, double value) {
    // The window opens already full so the trace spans the scope from the
    // first sample rather than growing in from the left edge.
    if (samples.isEmpty) {
      return List<double>.filled(_trafficHistoryLength, value, growable: false);
    }
    return _appendSample<double>(samples, value);
  }

  List<T> _appendSample<T>(List<T> samples, T value) {
    final int start = samples.length >= _trafficHistoryLength
        ? samples.length - _trafficHistoryLength + 1
        : 0;
    return <T>[...samples.sublist(start), value];
  }

  /// The time the full scope width represents.
  ///
  /// The poll cadence is configurable in TOML, so this cannot be assumed from
  /// the sample count. The observed cadence is measured and multiplied out
  /// across the window, which is correct once the buffer has filled and stays
  /// correct while it is still warming up behind the opening prefill.
  Duration? get _trafficWindow {
    if (_sampleTimes.length < 2) {
      return null;
    }
    final int spanMicroseconds = _sampleTimes.last
        .difference(_sampleTimes.first)
        .inMicroseconds;
    final double cadence = spanMicroseconds / (_sampleTimes.length - 1);

    return Duration(
      microseconds: (cadence * (_trafficHistoryLength - 1)).round(),
    );
  }

  NetworkTraffic _emptyTraffic() {
    return NetworkTraffic(
      upload: NetworkTransfer(
        bytesPerSecond: Uint64(BigInt.zero),
        totalBytes: Uint64(BigInt.zero),
      ),
      download: NetworkTransfer(
        bytesPerSecond: Uint64(BigInt.zero),
        totalBytes: Uint64(BigInt.zero),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final NetworkStatus? status = widget.status.asData?.value;
    final bool wifiEnabled =
        _pendingWifiEnabled ?? status?.wifiEnabled ?? false;
    final bool devicePresent = status?.devicePresent ?? false;
    final bool scanning = status?.scanning ?? widget.status.isLoading;
    final List<NetworkEntry> networks = status?.networks ?? const [];
    final List<NetworkInterface> interfaces = status?.interfaces ?? const [];
    final NetworkTraffic traffic = status?.traffic ?? _emptyTraffic();
    final String? message = status?.message;

    return HyprPopoverPanel(
      borderRadius: widget.borderRadius,
      constraints: const BoxConstraints(
        minWidth: 340,
        maxWidth: 340,
        // Only a safety net for short screens: it has to clear the fixed
        // sections plus four Wi-Fi rows, or it, rather than the list's own
        // cap, decides how many rows are visible.
        maxHeight: 900,
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          NetworkSpectrumPanel(
            uploadHistory: _uploadHistory,
            downloadHistory: _downloadHistory,
            window: _trafficWindow,
          ),
          const SizedBox(height: 10),
          NetworkParameterBank(
            traffic: traffic,
            interface: interfaces.isEmpty ? null : interfaces.first,
          ),
          const HyprSectionBreak(),
          // The Wi-Fi section is what gives way when the popover is short.
          Flexible(
            child: NetworkWifiSection(
              devicePresent: devicePresent,
              wifiEnabled: wifiEnabled,
              scanning: scanning,
              networks: networks,
              expandedSsid: _expandedSsid,
              selectedSsid: _selectedSsid,
              passwordController: _passwordController,
              passwordFocusNode: _passwordFocusNode,
              showPassword: _showPassword,
              inlineError: _inlineError,
              onToggleWifiEnabled: () => _setWifiEnabled(!wifiEnabled),
              onToggleEntry: _toggleEntry,
              onTogglePasswordVisibility: () {
                setState(() => _showPassword = !_showPassword);
              },
              onCancelPasswordPrompt: _cancelPasswordPrompt,
              onSubmit: _submit,
            ),
          ),
          const HyprSectionBreak(),
          NetworkInterfacesSection(interfaces: interfaces),
          if (message != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              message,
              style: HyprTypography.popRow.copyWith(color: HyprColors.danger),
            ),
          ],
          const HyprSectionBreak(),
          NetworkSettingsRow(onPressed: widget.onOpenSettings),
        ],
      ),
    );
  }
}
