import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'network_chrome.dart';
import 'network_entry_state.dart';
import 'network_entry_tile.dart';

/// SSIDs shown before the list starts scrolling.
const int _visibleEntries = 4;

class NetworkWifiSection extends StatefulWidget {
  const NetworkWifiSection({
    super.key,
    required this.devicePresent,
    required this.wifiEnabled,
    required this.scanning,
    required this.networks,
    required this.expandedSsid,
    required this.selectedSsid,
    required this.passwordController,
    required this.passwordFocusNode,
    required this.showPassword,
    required this.inlineError,
    required this.onToggleWifiEnabled,
    required this.onToggleEntry,
    required this.onTogglePasswordVisibility,
    required this.onCancelPasswordPrompt,
    required this.onSubmit,
  });

  final bool devicePresent;
  final bool wifiEnabled;
  final bool scanning;
  final List<NetworkEntry> networks;
  final String? expandedSsid;
  final String? selectedSsid;
  final TextEditingController passwordController;
  final FocusNode passwordFocusNode;
  final bool showPassword;
  final String? inlineError;
  final VoidCallback onToggleWifiEnabled;
  final ValueChanged<NetworkEntry> onToggleEntry;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onCancelPasswordPrompt;
  final ValueChanged<NetworkEntry> onSubmit;

  @override
  State<NetworkWifiSection> createState() => _NetworkWifiSectionState();
}

class _NetworkWifiSectionState extends State<NetworkWifiSection> {
  /// Measured from the first rendered tile rather than assumed: the tile's
  /// height follows the real font metrics, which differ from the estimate.
  double _entryExtent = NetworkEntryTile.collapsedExtent;
  final GlobalKey _firstEntryKey = GlobalKey();

  /// Guards the measurement against feeding itself.
  ///
  /// `_measureEntry` calls `setState`, which schedules the frame that would
  /// arm the next measurement. Without this the pair is a loop held open only
  /// by a tolerance, and any content that settles more than half a pixel from
  /// where it started pins the UI at the frame rate.
  bool _measurePending = false;
  bool _measured = false;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(NetworkWifiSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Font metrics decide the height, so one settled measurement holds for
    // every later list. Only a text scale change can invalidate it.
    if (!_measured) {
      _scheduleMeasure();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final double scale = MediaQuery.textScalerOf(context).scale(12);
    if (_textScale != scale) {
      _textScale = scale;
      _measured = false;
      _scheduleMeasure();
    }
  }

  double? _textScale;

  void _scheduleMeasure() {
    if (_measurePending) {
      return;
    }
    _measurePending = true;
    WidgetsBinding.instance.addPostFrameCallback(_measureEntry);
  }

  void _measureEntry(Duration _) {
    _measurePending = false;
    if (!mounted) {
      return;
    }
    // An expanded tile carries the password prompt, so it cannot stand in for
    // a collapsed row's height.
    final List<NetworkEntry> networks = widget.networks;
    if (networks.isEmpty || widget.expandedSsid == networks.first.ssid) {
      return;
    }
    final RenderObject? box = _firstEntryKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return;
    }
    final double extent = box.size.height;
    if (extent <= 0) {
      return;
    }
    _measured = true;
    if ((extent - _entryExtent).abs() < 0.5) {
      return;
    }
    setState(() => _entryExtent = extent);
  }

  @override
  Widget build(BuildContext context) {
    final bool devicePresent = widget.devicePresent;
    final bool wifiEnabled = widget.wifiEnabled;
    final bool scanning = widget.scanning;
    final List<NetworkEntry> networks = widget.networks;
    final String? expandedSsid = widget.expandedSsid;
    final String? selectedSsid = widget.selectedSsid;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const NetworkSectionTitle('Wi-Fi'),
            const Spacer(),
            Material(
              color: Colors.transparent,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(7),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: devicePresent ? widget.onToggleWifiEnabled : null,
                hoverColor: HyprColors.hover,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        wifiEnabled ? 'on' : 'off',
                        style: HyprTypography.compactMonoStrong.copyWith(
                          color: NetworkMenuColors.fg2,
                          fontSize: HyprTypography.size(11),
                          letterSpacing: 0.66,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _NetworkWifiSwitch(value: wifiEnabled && devicePresent),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Only the SSID list scrolls; everything around it stays put.
        Flexible(
          child: _NetworkWifiList(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: _entryExtent * _visibleEntries,
              ),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: <Widget>[
                  if (!devicePresent)
                    const NetworkEmptyState(message: 'No Wi-Fi device found.')
                  else if (!wifiEnabled)
                    const NetworkEmptyState(message: 'Wi-Fi is turned off.')
                  else if (networks.isEmpty)
                    NetworkEmptyState(
                      message: scanning
                          ? 'Scanning for networks...'
                          : 'No networks found.',
                    )
                  else
                    for (final NetworkEntry entry in networks)
                      NetworkEntryTile(
                        key: entry.ssid == networks.first.ssid
                            ? _firstEntryKey
                            : null,
                        entry: entry,
                        expanded: expandedSsid == entry.ssid,
                        selected:
                            selectedSsid == entry.ssid &&
                            !entry.isActive &&
                            !entry.isConnecting,
                        passwordController: widget.passwordController,
                        passwordFocusNode: widget.passwordFocusNode,
                        showPassword: widget.showPassword,
                        errorMessage: expandedSsid == entry.ssid
                            ? widget.inlineError
                            : null,
                        onTap: () => widget.onToggleEntry(entry),
                        onTogglePasswordVisibility:
                            widget.onTogglePasswordVisibility,
                        onCancel: widget.onCancelPasswordPrompt,
                        onSubmit: () => widget.onSubmit(entry),
                      ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NetworkWifiSwitch extends StatelessWidget {
  const _NetworkWifiSwitch({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return HyprHardwareToggle(value: value);
  }
}

class _NetworkWifiList extends StatelessWidget {
  const _NetworkWifiList({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The list itself is bare: each tile carries its own glass frame.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: child,
    );
  }
}
