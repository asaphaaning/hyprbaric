import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'controls_chrome.dart';

class ControlCapturePad extends StatelessWidget {
  const ControlCapturePad({
    super.key,
    required this.label,
    required this.shortcut,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final String shortcut;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _CapturePlate(
      semanticLabel: 'Capture $label',
      onPressed: onPressed,
      child: Stack(
        children: <Widget>[
          Positioned(top: 7, right: 7, child: _ShortcutBadge(shortcut)),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _CaptureIcon(icon),
                  const SizedBox(height: 8),
                  Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: HyprTypography.compactMonoStrong.copyWith(
                      color: ControlColors.textMuted,
                      fontSize: HyprTypography.size(9),
                      fontWeight: FontWeight.w700,
                      height: 1,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ControlRecordPad extends StatelessWidget {
  const ControlRecordPad({
    super.key,
    required this.active,
    required this.enabled,
    required this.phase,
    required this.elapsed,
    required this.shortcut,
    required this.onPressed,
  });

  final bool active;
  final bool enabled;
  final String phase;
  final String elapsed;
  final String shortcut;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return _CapturePlate(
      semanticLabel: active ? 'Stop recording' : 'Start recording',
      onPressed: onPressed,
      enabled: enabled,
      active: active,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    phase,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: HyprTypography.compactMonoStrong.copyWith(
                      color: active
                          ? ControlColors.danger
                          : ControlColors.textMuted,
                      fontSize: HyprTypography.size(9),
                      fontWeight: FontWeight.w700,
                      height: 1,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
                _ShortcutBadge(shortcut),
              ],
            ),
            const Spacer(),
            DecoratedBox(
              decoration: ShapeDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[ControlColors.well, ControlColors.wellBottom],
                ),
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text(
                  elapsed,
                  textAlign: TextAlign.center,
                  style: HyprTypography.compactMonoStrong.copyWith(
                    color: !enabled
                        ? ControlColors.textFaint
                        : active
                        ? ControlColors.danger
                        : ControlColors.textMuted,
                    fontSize: HyprTypography.size(16),
                    fontWeight: FontWeight.w600,
                    height: 1,
                    letterSpacing: 0.65,
                    fontFeatures: HyprTypography.tabularNumbers,
                    shadows: active
                        ? const <Shadow>[
                            Shadow(color: Color(0x66E16658), blurRadius: 8),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapturePlate extends StatelessWidget {
  const _CapturePlate({
    required this.semanticLabel,
    required this.onPressed,
    required this.child,
    this.enabled = true,
    this.active = false,
  });

  final String semanticLabel;
  final VoidCallback? onPressed;
  final Widget child;
  final bool enabled;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return HyprInteractionRegion(
      semanticLabel: semanticLabel,
      enabled: enabled,
      onPressed: onPressed,
      builder: (BuildContext context, HyprInteractionState state) {
        final Color color = active
            ? ControlColors.danger.withValues(alpha: 0.16)
            : state.pressed
            ? ControlColors.tilePressed
            : state.hovered
            ? ControlColors.tileHover
            : ControlColors.tile;

        return AnimatedContainer(
          duration: HyprMotion.hover,
          curve: HyprMotion.hoverCurve,
          transform: Matrix4.translationValues(0, state.pressed ? 1 : 0, 0),
          decoration: ShapeDecoration(
            color: color,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Opacity(opacity: enabled ? 1 : 0.48, child: child),
        );
      },
    );
  }
}

class _ShortcutBadge extends StatelessWidget {
  const _ShortcutBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: const Color(0xA6000000),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Color(0x66000000)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          label,
          style: HyprTypography.compactMonoStrong.copyWith(
            color: ControlColors.textFaint,
            fontSize: HyprTypography.size(8),
            fontWeight: FontWeight.w600,
            height: 1,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _CaptureIcon extends StatelessWidget {
  const _CaptureIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: ControlColors.well,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: SizedBox.square(
        dimension: 28,
        child: Icon(icon, size: 21, color: ControlColors.textFaint),
      ),
    );
  }
}
