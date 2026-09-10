import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'hypr_surface.dart';
import 'primitives/primitives.dart';

/// The focused window's title, centered in the bar.
///
/// Embeds may pass [onTap] to make the title actionable (for example, a
/// documentation site whose bar title returns home). When null the title is
/// inert text, exactly as on the desktop.
class CenterCluster extends ConsumerWidget {
  const CenterCluster({super.key, required this.maxWidth, this.onTap});

  final double maxWidth;

  /// Invoked when the title itself is activated, or null for plain text.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FocusedWindowDisplay display = ref.watch(
      currentWindowDisplayProvider,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double clusterWidth = math.min(constraints.maxWidth, maxWidth);

        return Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: clusterWidth),
            child: _WindowTitleChip(display: display, onTap: onTap),
          ),
        );
      },
    );
  }
}

class _WindowTitleChip extends StatelessWidget {
  const _WindowTitleChip({required this.display, this.onTap});

  final FocusedWindowDisplay display;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onTap = this.onTap;
    final Widget label = Semantics(
      label: display.tooltip,
      button: onTap != null,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double titleMaxWidth = math.max(0, constraints.maxWidth - 28);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: titleMaxWidth),
                child: _WindowTitleText(display: display),
              ),
            ),
          );
        },
      ),
    );

    if (onTap == null) {
      return label;
    }

    // A title link behaves like the bar's other quiet affordances: no ink,
    // just the pointer, so the desktop tree stays byte-identical without it.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: label,
      ),
    );
  }
}

class _WindowTitleText extends StatelessWidget {
  const _WindowTitleText({required this.display});

  final FocusedWindowDisplay display;

  @override
  Widget build(BuildContext context) {
    if (display.isHidden) {
      return const SizedBox.shrink();
    }
    final String? appName = display.appName;
    final String? subtitle = display.hasAppTitleSplit ? display.title : null;
    if (appName == null) {
      return _TrailingFadeMask(
        child: Text(
          display.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: HyprTypography.barStrong.copyWith(
            color: display.isFallback ? HyprColors.textMuted : HyprColors.text,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        HyprGlyphBadge(
          name: appName,
          dimension: 20,
          borderRadius: BorderRadius.circular(6),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: subtitle == null ? 220 : 180),
            child: Text(
              appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HyprTypography.barStrong,
            ),
          ),
        ),
        if (subtitle != null) ...<Widget>[
          const HyprDivider(
            height: 16,
            margin: EdgeInsets.symmetric(horizontal: 10),
          ),
          Flexible(
            flex: 2,
            child: _TrailingFadeMask(
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HyprTypography.barMono,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TrailingFadeMask extends StatelessWidget {
  const _TrailingFadeMask({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect bounds) {
        final double fadeWidth = math.min(14, bounds.width * 0.08);
        final double solidStop = bounds.width <= 0
            ? 1
            : ((bounds.width - fadeWidth) / bounds.width).clamp(0.0, 1.0);
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[Colors.black, Colors.black, Colors.transparent],
          stops: <double>[0, solidStop, 1],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}
