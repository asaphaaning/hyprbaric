import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../bindings/bindings.dart';
import '../state/monitor_workspace.dart';
import 'hypr_surface.dart';
import 'primitives/primitives.dart';

class WorkspaceStrip extends StatelessWidget {
  const WorkspaceStrip({
    super.key,
    required this.status,
    required this.settings,
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
    required this.resolution,
  });

  final WorkspaceStatus status;
  final WorkspaceSettingsStatus settings;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onSelect;

  /// The workspace this bar's own output is displaying, which differs from the
  /// compositor-wide focus whenever another output holds focus.
  final MonitorWorkspaceResolution resolution;

  @override
  Widget build(BuildContext context) {
    final int active = resolution.activeWorkspaceId;
    final List<int> visibleWorkspaces = _visibleWorkspaceRange(
      active,
      settings.visibleCount,
    );
    return Row(
      key: const ValueKey<String>('workspace-strip'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        WorkspaceNavButton(
          icon: Icons.chevron_left_rounded,
          label: 'Previous workspace',
          onPressed: onPrevious,
        ),
        const SizedBox(width: HyprSpacing.xl),
        for (final int index in visibleWorkspaces) ...<Widget>[
          WorkspaceButton(
            key: ValueKey<String>('workspace-indicator-$index'),
            label: _workspaceIndicatorLabel(
              index,
              status,
              settings,
              resolution,
            ),
            active: !resolution.isSpecial && index == active,
            occupied: status.occupiedWorkspaceIds.contains(index),
            onPressed: settings.clickable ? () => onSelect(index) : null,
          ),
          if (index != visibleWorkspaces.last)
            const SizedBox(width: HyprSpacing.md),
        ],
        const SizedBox(width: HyprSpacing.xl),
        WorkspaceNavButton(
          icon: Icons.chevron_right_rounded,
          label: 'Next workspace',
          onPressed: onNext,
        ),
      ],
    );
  }
}

class WorkspaceStripPlaceholder extends StatelessWidget {
  const WorkspaceStripPlaceholder({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const WorkspaceNavButton(
          icon: Icons.chevron_left_rounded,
          label: 'Previous workspace',
        ),
        const SizedBox(width: HyprSpacing.xl - HyprSpacing.hairline),
        WorkspaceButton(label: label, active: true, occupied: false),
      ],
    );
  }
}

class WorkspaceNavButton extends StatelessWidget {
  const WorkspaceNavButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        key: ValueKey<String>('workspace-nav-$label'),
        onPressed: onPressed,
        style: _workspaceNavButtonStyle(),
        icon: Icon(icon, size: HyprIconSizes.bar),
      ),
    );
  }
}

class WorkspaceButton extends StatelessWidget {
  const WorkspaceButton({
    super.key,
    required this.label,
    required this.active,
    required this.occupied,
    this.onPressed,
  });

  final String label;
  final bool active;
  final bool occupied;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool active = this.active;
    final bool occupied = this.occupied;
    final HyprPalette palette = context.hyprPalette;
    final Color foreground = active ? palette.accentSoft : HyprColors.textFaint;
    final BorderSide border = active
        ? BorderSide(
            color: palette.accentSoft.withValues(alpha: 0.40),
            width: 1,
          )
        : BorderSide.none;
    final List<BoxShadow> shadows = <BoxShadow>[
      BoxShadow(
        color: active
            ? palette.accentSoft.withValues(alpha: 0.13)
            : Colors.transparent,
        blurRadius: active ? 8 : 0,
        spreadRadius: 0,
      ),
    ];

    return HyprInteractiveTile(
      semanticLabel: 'Workspace $label',
      onPressed: onPressed,
      width: 31,
      height: 18,
      color: Colors.transparent,
      hoverColor: Colors.transparent,
      borderColor: Colors.transparent,
      hoverBorderColor: Colors.transparent,
      clipBehavior: Clip.none,
      duration: HyprMotion.workspace,
      curve: HyprMotion.workspaceCurve,
      pressedScale: 0.9,
      scaleBuilder: (HyprInteractiveTileState state) {
        if (state.pressed) {
          return 0.9;
        }
        if (state.hovered) {
          return 1.16;
        }
        return 1;
      },
      builder: (BuildContext context, HyprInteractiveTileState state) {
        return Center(
          child: AnimatedContainer(
            duration: HyprMotion.workspace,
            curve: HyprMotion.workspaceCurve,
            width: 31,
            height: 18,
            decoration: ShapeDecoration(
              color: active ? palette.fill : Colors.transparent,
              shadows: shadows,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(
                  active ? HyprRadii.compact : HyprRadii.card,
                ),
                side: border,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: HyprTypography.workspace.copyWith(
                    color: foreground,
                    fontSize: 10.5,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),
                if (occupied && !active)
                  Positioned(
                    bottom: -3,
                    child: DecoratedBox(
                      key: ValueKey<String>('workspace-occupancy-dot-$label'),
                      decoration: BoxDecoration(
                        color: palette.accentSoft,
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: palette.accentSoft.withValues(alpha: 0.45),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      child: const SizedBox.square(dimension: 3),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

List<int> _visibleWorkspaceRange(int active, int visibleCount) {
  final int count = math.max(1, visibleCount);
  final int clampedActive = math.max(1, active);
  final int start = math.max(1, clampedActive - (count ~/ 2));
  return List<int>.generate(count, (int offset) => start + offset);
}

String _workspaceIndicatorLabel(
  int index,
  WorkspaceStatus status,
  WorkspaceSettingsStatus settings,
  MonitorWorkspaceResolution resolution,
) {
  if (resolution.isSpecial && index == 1) {
    // Only the focused output reports a special workspace name; elsewhere the
    // generic badge is the best available label.
    final String name = resolution.isFallback || status.isSpecial
        ? status.name.trim()
        : '';
    return name.isEmpty ? 'S' : name;
  }
  if (settings.indicatorStyle == WorkspaceIndicatorStyle.numeric) {
    return '$index';
  }
  return _romanNumeral(index);
}

String _romanNumeral(int value) {
  if (value <= 0) {
    return '$value';
  }

  const List<(int, String)> numerals = <(int, String)>[
    (1000, 'M'),
    (900, 'CM'),
    (500, 'D'),
    (400, 'CD'),
    (100, 'C'),
    (90, 'XC'),
    (50, 'L'),
    (40, 'XL'),
    (10, 'X'),
    (9, 'IX'),
    (5, 'V'),
    (4, 'IV'),
    (1, 'I'),
  ];
  final StringBuffer buffer = StringBuffer();
  int remaining = value;
  for (final (int number, String numeral) in numerals) {
    while (remaining >= number) {
      buffer.write(numeral);
      remaining -= number;
    }
  }
  return buffer.toString();
}

ButtonStyle _workspaceNavButtonStyle() {
  return hyprCompactIconButtonStyle(
    size: HyprIconSizes.navigationButton,
    radius: HyprRadii.panel,
    foregroundColor: HyprColors.textFaint,
    hoverForegroundColor: HyprColors.textMuted,
  );
}
