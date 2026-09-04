import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'controls_chrome.dart';

/// Formats the wall-clock age of a recording as `MM:SS`.
///
/// The start stamp comes from the compositor's clock, so it can sit slightly
/// in the future relative to ours. Clamping the whole duration keeps that from
/// rendering as `00:-7`, and saturates a very long capture at `99:59` rather
/// than letting the minutes field grow the readout.
String formatRecordingElapsed(int? startedAtMs) {
  if (startedAtMs == null) {
    return '00:00';
  }
  final DateTime startedAt = DateTime.fromMillisecondsSinceEpoch(startedAtMs);
  final int totalSeconds = DateTime.now()
      .difference(startedAt)
      .inSeconds
      .clamp(0, 99 * 60 + 59);
  final String minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final String seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class ControlCapturePad extends StatelessWidget {
  const ControlCapturePad({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.shortcut,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  /// The user's configured chord, or null when the binding is unknown or
  /// disabled. A guessed chord is worse than none at all.
  final String? shortcut;

  @override
  Widget build(BuildContext context) {
    return ControlPlate(
      semanticLabel: 'Capture $label',
      onPressed: onPressed,
      builder: (BuildContext context, HyprInteractionState state) {
        final bool lit = state.enabled && state.active;

        return Padding(
          padding: const EdgeInsets.all(HyprSpacing.lg + 1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    if (shortcut case final String chord)
                      Flexible(child: ControlShortcutBadge(chord)),
                  ],
                ),
              ),
              const Spacer(),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _CaptureIcon(icon, lit: lit),
                    const SizedBox(height: HyprSpacing.xl),
                    Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: HyprTypography.consoleCaptionTight.copyWith(
                        color: lit
                            ? HyprConsoleColors.text
                            : HyprConsoleColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        );
      },
    );
  }
}

/// The recording pad, which owns its own once-a-second repaint.
///
/// The ticker lives here rather than on the panel so a running capture
/// repaints one pad instead of every superellipse-clipped tray above it.
class ControlRecordPad extends StatefulWidget {
  const ControlRecordPad({
    super.key,
    required this.active,
    required this.availability,
    required this.phase,
    required this.startedAtMs,
    required this.onPressed,
    this.shortcut,
  });

  final bool active;
  final ControlAvailability availability;
  final String phase;

  /// Wall-clock start of the running capture, or null when it is not running.
  /// Non-null is what drives the ticker.
  final int? startedAtMs;

  final VoidCallback? onPressed;
  final String? shortcut;

  bool get enabled => availability.isAvailable;

  @override
  State<ControlRecordPad> createState() => _ControlRecordPadState();
}

class _ControlRecordPadState extends State<ControlRecordPad> {
  @override
  Widget build(BuildContext context) {
    // Only while a recording is running does the elapsed label change.
    return HyprIntervalRebuild(
      enabled: widget.startedAtMs != null,
      builder: _buildPad,
    );
  }

  Widget _buildPad(BuildContext context) {
    final bool enabled = widget.enabled;

    return RepaintBoundary(
      child: ControlPlate(
        semanticLabel: widget.active ? 'Stop recording' : 'Start recording',
        onPressed: widget.onPressed,
        availability: widget.availability,
        active: widget.active,
        builder: (BuildContext context, HyprInteractionState state) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              HyprSpacing.xxl,
              HyprSpacing.xxl,
              HyprSpacing.xxl,
              HyprSpacing.panel - HyprSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        widget.phase,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: HyprTypography.consoleCaptionTight.copyWith(
                          color: widget.active
                              ? HyprColors.danger
                              : HyprConsoleColors.textMuted,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                    if (widget.shortcut case final String chord)
                      Flexible(child: ControlShortcutBadge(chord)),
                  ],
                ),
                const Spacer(),
                DecoratedBox(
                  decoration: controlWellDecoration(
                    borderRadius: HyprRadii.cardRadius,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: HyprSpacing.md,
                    ),
                    child: Text(
                      formatRecordingElapsed(widget.startedAtMs),
                      textAlign: TextAlign.center,
                      style: HyprTypography.consoleReadout.copyWith(
                        color: !enabled
                            ? HyprConsoleColors.textFaint
                            : widget.active
                            ? HyprColors.danger
                            : HyprConsoleColors.textMuted,
                        shadows: widget.active
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
          );
        },
      ),
    );
  }
}

/// A raised pad in the capture tray.
///
/// The child is built from the interaction state so its contents can respond
/// to hover, not just the plate underneath them.
class ControlPlate extends StatelessWidget {
  const ControlPlate({
    super.key,
    required this.semanticLabel,
    required this.onPressed,
    required this.builder,
    this.availability = const ControlAvailability.available(),
    this.active = false,
  });

  final String semanticLabel;
  final VoidCallback? onPressed;
  final HyprInteractionRegionBuilder builder;
  final ControlAvailability availability;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bool enabled = availability.isAvailable;

    return HyprInteractionRegion(
      semanticLabel: enabled ? semanticLabel : '$semanticLabel, unavailable',
      onPressed: onPressed,
      builder: (BuildContext context, HyprInteractionState rawState) {
        // The region stays tappable while unavailable so a tap can surface
        // the reason, but the face must not light up as though it were live.
        final HyprInteractionState state = HyprInteractionState(
          hovered: rawState.hovered,
          pressed: rawState.pressed,
          enabled: enabled && rawState.enabled,
        );
        final Color color = active && enabled
            ? HyprColors.danger.withValues(alpha: 0.16)
            : controlFaceColor(state);

        return AnimatedContainer(
          duration: HyprMotion.hover,
          curve: HyprMotion.hoverCurve,
          transform: controlPressTransform(state),
          decoration: ShapeDecoration(
            color: color,
            shape: const RoundedSuperellipseBorder(
              borderRadius: HyprRadii.fieldRadius,
            ),
          ),
          child: Opacity(
            opacity: enabled ? 1 : ControlAvailability.dimmed,
            child: builder(context, state),
          ),
        );
      },
    );
  }
}

class _CaptureIcon extends StatelessWidget {
  const _CaptureIcon(this.icon, {required this.lit});

  final IconData icon;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: HyprConsoleColors.well,
        shape: RoundedSuperellipseBorder(borderRadius: HyprRadii.controlRadius),
      ),
      child: SizedBox.square(
        dimension: 28,
        child: Icon(
          icon,
          size: 21,
          color: lit
              ? HyprConsoleColors.textMuted
              : HyprConsoleColors.textFaint,
        ),
      ),
    );
  }
}
