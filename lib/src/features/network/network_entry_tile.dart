import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'network_chrome.dart';
import 'network_entry_state.dart';
import 'network_formatting.dart';
import 'network_password_prompt.dart';
import 'network_signal_bars.dart';

class NetworkEntryTile extends StatefulWidget {
  const NetworkEntryTile({
    super.key,
    required this.entry,
    required this.expanded,
    required this.selected,
    required this.passwordController,
    required this.passwordFocusNode,
    required this.showPassword,
    required this.errorMessage,
    required this.onTap,
    required this.onTogglePasswordVisibility,
    required this.onCancel,
    required this.onSubmit,
  });

  final NetworkEntry entry;
  final bool expanded;
  final bool selected;
  final TextEditingController passwordController;
  final FocusNode passwordFocusNode;
  final bool showPassword;
  final String? errorMessage;
  final VoidCallback onTap;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  /// Height one collapsed tile occupies in the list: the 46px glass plate
  /// plus the 10px gap below it.
  static const double collapsedExtent = 56;

  @override
  State<NetworkEntryTile> createState() => NetworkEntryTileState();
}

class NetworkEntryTileState extends State<NetworkEntryTile> {
  @override
  Widget build(BuildContext context) {
    final NetworkEntry entry = widget.entry;
    final bool interactive = !entry.isConnecting;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          HyprInteractionRegion(
            enabled: interactive,
            cursor: interactive
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            semanticLabel: entry.isActive
                ? '${entry.ssid}, connected'
                : entry.ssid,
            onPressed: interactive ? widget.onTap : null,
            builder: (BuildContext context, HyprInteractionState state) {
              final bool lit = state.active || widget.selected;
              return HyprGlassFrame(
                sheen: lit ? HyprGlassSheen.tileHover : HyprGlassSheen.tile,
                rimLight: lit
                    ? HyprGlassFrame.rimLightStrong
                    : HyprGlassFrame.rimLightDefault,
                borderColor: lit
                    ? const Color(0x8C000000)
                    : const Color(0x80000000),
                shadows: HyprGlassFrame.tileShadows,
                glow: entry.isActive
                    ? context.hyprPalette.accent.withValues(alpha: 0.16)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Row(
                    children: <Widget>[
                      NetworkSignalBars(
                        strength: entry.strength,
                        active: entry.isActive,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              entry.ssid,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              // The reference drops the mono face for
                              // SSIDs: inherit, 12px, w600, no
                              // tracking.
                              style: HyprTypography.popRowStrong.copyWith(
                                color: entry.isActive
                                    ? HyprColors.text
                                    : NetworkMenuColors.fg1,
                                fontSize: HyprTypography.size(12),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            _NetworkEntryMeta(entry: entry),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (entry.secure) ...<Widget>[
                        const _NetworkSecurityBadge(secure: true),
                      ] else ...<Widget>[
                        const _NetworkSecurityBadge(secure: false),
                      ],
                      if (entry.isConnecting) ...<Widget>[
                        const SizedBox(width: 10),
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(strokeWidth: 1.4),
                        ),
                      ] else if (entry.isActive) ...<Widget>[
                        const SizedBox(width: 10),
                        const _NetworkActionBadge(label: 'live'),
                      ] else if (widget.selected) ...<Widget>[
                        const SizedBox(width: 10),
                        const _NetworkActionBadge(label: 'join'),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          if (widget.expanded)
            NetworkPasswordPrompt(
              ssid: entry.ssid,
              controller: widget.passwordController,
              focusNode: widget.passwordFocusNode,
              showPassword: widget.showPassword,
              connecting: entry.isConnecting,
              errorMessage: widget.errorMessage,
              onToggleVisibility: widget.onTogglePasswordVisibility,
              onCancel: widget.onCancel,
              onSubmit: widget.onSubmit,
            ),
        ],
      ),
    );
  }
}

class _NetworkEntryMeta extends StatelessWidget {
  const _NetworkEntryMeta({required this.entry});

  final NetworkEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          networkStrengthLabel(entry.strength),
          style: HyprTypography.compactMono.copyWith(
            color: NetworkMenuColors.fg3,
            fontSize: HyprTypography.size(9),
            letterSpacing: 0.54,
            height: 1,
          ),
        ),
        const SizedBox(width: 5),
        const DecoratedBox(
          decoration: BoxDecoration(
            color: NetworkMenuColors.fg3,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(dimension: 2),
        ),
        const SizedBox(width: 5),
        Text(
          entry.secure ? 'WPA' : 'OPEN',
          style: HyprTypography.compactMono.copyWith(
            color: NetworkMenuColors.fg3,
            fontSize: HyprTypography.size(9),
            letterSpacing: 0.54,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _NetworkSecurityBadge extends StatelessWidget {
  const _NetworkSecurityBadge({required this.secure});

  final bool secure;

  @override
  Widget build(BuildContext context) {
    return HyprInlineTag(
      label: secure ? '⊠' : '◌',
      color: Colors.black.withValues(alpha: 0.45),
      borderColor: const Color(0x993C4652),
      textColor: NetworkMenuColors.fg3,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      borderRadius: BorderRadius.circular(2),
      uppercase: false,
      style: HyprTypography.compactMonoStrong.copyWith(
        fontSize: HyprTypography.size(8.5),
        letterSpacing: 0.85,
        height: 1,
      ),
    );
  }
}

class _NetworkActionBadge extends StatelessWidget {
  const _NetworkActionBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return HyprInlineTag(
      label: label,
      color: Colors.transparent,
      padding: HyprSpacing.none,
      borderRadius: HyprRadii.zero,
      textColor: context.hyprPalette.accentSoft,
      style: HyprTypography.compactMonoStrong.copyWith(
        fontSize: HyprTypography.size(9),
        letterSpacing: 0.9,
        height: 1,
      ),
    );
  }
}
