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

  /// Height one collapsed plate and its reference 8px list gap occupy.
  static const double collapsedExtent = 60;

  @override
  State<NetworkEntryTile> createState() => NetworkEntryTileState();
}

class NetworkEntryTileState extends State<NetworkEntryTile> {
  @override
  Widget build(BuildContext context) {
    final NetworkEntry entry = widget.entry;
    final bool interactive = !entry.isConnecting;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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

  NetworkWifiTilePhase _phaseFor({
    required NetworkEntry entry,
    required bool hovered,
    required bool pressed,
  }) {
    if (widget.expanded) {
      return NetworkWifiTilePhase.expanded;
    }
    if (entry.isActive) {
      return NetworkWifiTilePhase.active;
    }
    if (pressed) {
      return NetworkWifiTilePhase.pressed;
    }
    if (hovered) {
      return NetworkWifiTilePhase.hovered;
    }
    return NetworkWifiTilePhase.idle;
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
          networkBandLabel(entry),
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
          entry.secure ? 'WPA2' : 'OPEN',
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
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: NetworkWifiColors.badge,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: Text(
          secure ? 'WPA2' : 'OPEN',
          style: HyprTypography.compactMonoStrong.copyWith(
            color: NetworkMenuColors.fg3,
            fontSize: HyprTypography.size(8),
            letterSpacing: 0.8,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _NetworkWifiTileSurface extends StatelessWidget {
  const _NetworkWifiTileSurface({
    required this.radius,
    required this.phase,
    required this.style,
    required this.child,
  });

  final BorderRadius radius;
  final NetworkWifiTilePhase phase;
  final NetworkWifiTileStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool pressed = phase == NetworkWifiTilePhase.pressed;

    return AnimatedContainer(
      duration: HyprMotion.hover,
      curve: HyprMotion.hoverCurve,
      decoration: ShapeDecoration(
        color: style.fill,
        shape: RoundedSuperellipseBorder(borderRadius: radius),
        shadows: pressed
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: style.cast,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
                BoxShadow(
                  color: NetworkWifiColors.castStrong,
                  blurRadius: phase == NetworkWifiTilePhase.hovered ? 11 : 7,
                  offset: const Offset(0, 3),
                  spreadRadius: -3,
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          if (style.glow case final Color glow)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.65, 0),
                      radius: 1.25,
                      colors: <Color>[glow, Colors.transparent],
                      stops: const <double>[0, 1],
                    ),
                  ),
                ),
              ),
            ),
          if (!pressed)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _NetworkWifiTileRimPainter(
                    borderRadius: radius,
                    color: style.rim,
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _NetworkWifiTileRimPainter extends CustomPainter {
  const _NetworkWifiTileRimPainter({
    required this.borderRadius,
    required this.color,
  });

  final BorderRadius borderRadius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 2 || size.height <= 4) {
      return;
    }

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, 4));
    canvas.drawRSuperellipse(
      borderRadius.toRSuperellipse((Offset.zero & size).deflate(0.5)),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NetworkWifiTileRimPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.color != color;
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
