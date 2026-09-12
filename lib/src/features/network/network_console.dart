import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';

/// The network instrument's materials; opacity is owned by the glass itself.
abstract final class NetworkConsole {
  static const text = Color(0xFFF7F6FF);
  static const muted = Color(0xFFB8C4FF);
  static const accent = Color(0xFFB2BDFF);
  static const download = Color(0xFFB94BFF);
  static const upload = Color(0xFFFF2CAB);

  /// Brighter readout colors preserve the trace identities against dark glass.
  static const downloadText = Color(0xFFC978FF);
  static const uploadText = Color(0xFFFF62C2);
  static const line = Color(0x484B536E);
  static const amber = Color(0xFFFFAF32);
  static const body = TextStyle(
    fontFamily: 'Roboto Condensed',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: muted,
    letterSpacing: .25,
  );

  /// Secondary facts use the mixer's clear lavender, with a readable minimum.
  static const meta = TextStyle(
    fontFamily: 'Roboto Condensed',
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: muted,
    letterSpacing: .3,
  );
  static const label = TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.1,
    color: accent,
    height: 1.25,
  );
}

/// Corner-safe translucent charcoal, with the compositor supplying blur.
class NetworkSurface extends StatelessWidget {
  const NetworkSurface({super.key, required this.radius, required this.child});

  final BorderRadius radius;
  final Widget child;

  @override
  Widget build(BuildContext context) => HyprGlassSurface(
    borderRadius: radius,
    color: Colors.white,
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xC914171E), Color(0xBC101218), Color(0xD00B0E13)],
      stops: [0, .55, 1],
    ),
    borderColor: const Color(0x887E86B4),
    frame: HyprSurfaceFrame.popover,
    inset: false,
    child: DefaultTextStyle(style: NetworkConsole.body, child: child),
  );
}

/// Blue radial light beneath the traffic arcs, fading into charcoal glass.
class NetworkTrafficBacklight extends StatelessWidget {
  const NetworkTrafficBacklight({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, .55),
          radius: .62,
          colors: [
            Color(0xA02E66DF),
            Color(0x582451B5),
            Color(0x1020418D),
            Color(0x0020418D),
          ],
          stops: [0, .32, .70, 1],
        ),
      ),
      child: child,
    ),
  );
}

/// A softly recessed grouping, shared by every connection view.
class NetworkCard extends StatelessWidget {
  const NetworkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0x3410131B),
      border: Border.all(color: NetworkConsole.line, width: .6),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Padding(padding: padding, child: child),
  );
}

/// Consistent keyboard, pointer and focus treatment for console commands.
class NetworkAction extends StatelessWidget {
  const NetworkAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailing,
    this.primary = false,
    this.enabled = true,
    this.compact = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final IconData? trailing;
  final bool primary;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: HyprInteractionRegion(
      semanticLabel: label,
      enabled: enabled,
      onPressed: onPressed,
      builder: (context, state) => AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: primary
              ? const Color(0xFF8434F5).withValues(alpha: enabled ? 1 : .35)
              : state.hovered || state.pressed
              ? const Color(0x228F83DA)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: primary
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17, color: NetworkConsole.accent),
              const SizedBox(width: 9),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NetworkConsole.body.copyWith(
                  color: primary ? NetworkConsole.text : NetworkConsole.muted,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 5),
              Icon(trailing, size: 15, color: NetworkConsole.accent),
            ],
          ],
        ),
      ),
    ),
  );
}

/// A compact amber radio switch, distinct from the violet traffic accents.
class NetworkRadioSwitch extends StatelessWidget {
  const NetworkRadioSwitch({
    super.key,
    required this.enabled,
    required this.onToggle,
  });

  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: enabled,
    child: HyprInteractionRegion(
      semanticLabel: enabled ? 'Disable Wi-Fi' : 'Enable Wi-Fi',
      onPressed: onToggle,
      builder: (context, state) => Container(
        width: 44,
        height: 25,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0x44121115),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: enabled ? const Color(0x665F421B) : NetworkConsole.line,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? const Color(0xFFFFF1D8) : NetworkConsole.muted,
              border: Border.all(
                color: enabled ? NetworkConsole.amber : NetworkConsole.line,
              ),
              boxShadow: enabled
                  ? const [BoxShadow(color: Color(0x88FF9C12), blurRadius: 10)]
                  : null,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Amber policy checkbox, shared by connection and join forms.
class NetworkCheck extends StatelessWidget {
  const NetworkCheck({
    super.key,
    required this.label,
    required this.checked,
    required this.onChanged,
  });
  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => HyprInteractionRegion(
    semanticLabel: label,
    semanticToggled: checked,
    onPressed: () => onChanged(!checked),
    builder: (context, state) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: checked ? NetworkConsole.amber : const Color(0x660D111A),
              border: Border.all(
                color: checked ? const Color(0xFFFFCC74) : NetworkConsole.line,
                width: .6,
              ),
              boxShadow: checked
                  ? const [BoxShadow(color: Color(0x55FFAA33), blurRadius: 6)]
                  : null,
            ),
            child: checked
                ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    ),
  );
}

/// The reference's three-node network topology glyph.
class NetworkTopologyIcon extends StatelessWidget {
  const NetworkTopologyIcon({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 21,
    height: 22,
    child: CustomPaint(painter: _TopologyPainter()),
  );
}

class _TopologyPainter extends CustomPainter {
  const _TopologyPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = NetworkConsole.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(10.5, 4), 2.7, paint);
    canvas.drawCircle(const Offset(3.5, 17), 2.7, paint);
    canvas.drawCircle(const Offset(17.5, 17), 2.7, paint);
    canvas.drawLine(const Offset(8.7, 8.5), const Offset(5, 13.5), paint);
    canvas.drawLine(const Offset(12.3, 8.5), const Offset(16, 13.5), paint);
  }

  @override
  bool shouldRepaint(_TopologyPainter oldDelegate) => false;
}
