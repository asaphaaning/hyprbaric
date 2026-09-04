import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';

typedef TrayActivateCallback = void Function(String id, Offset position);

class TrayStrip extends StatelessWidget {
  const TrayStrip({
    super.key,
    required this.status,
    required this.onActivate,
    required this.onContextMenu,
  });

  final TrayStatus status;
  final TrayActivateCallback onActivate;
  final TrayActivateCallback onContextMenu;

  @override
  Widget build(BuildContext context) {
    if (status.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      key: const ValueKey<String>('tray-strip'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final TrayItem item in status.items)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: _TrayCell(
              item: item,
              onActivate: onActivate,
              onContextMenu: onContextMenu,
            ),
          ),
      ],
    );
  }
}

class _TrayCell extends StatelessWidget {
  const _TrayCell({
    required this.item,
    required this.onActivate,
    required this.onContextMenu,
  });

  final TrayItem item;
  final TrayActivateCallback onActivate;
  final TrayActivateCallback onContextMenu;

  @override
  Widget build(BuildContext context) {
    final String semanticsLabel = [
      item.title,
      if ((item.description ?? '').trim().isNotEmpty) item.description!.trim(),
    ].join(', ');

    return HyprInteractionRegion(
      semanticLabel: semanticsLabel,
      onTapUp: (TapUpDetails details) =>
          onActivate(item.id, details.globalPosition),
      onSecondaryTapUp: (TapUpDetails details) =>
          onContextMenu(item.id, details.globalPosition),
      builder: (BuildContext context, HyprInteractionState state) {
        return TweenAnimationBuilder<double>(
          duration: HyprMotion.hover,
          curve: HyprMotion.hoverCurve,
          tween: Tween<double>(end: state.hovered ? 1 : 0),
          builder: (BuildContext context, double value, Widget? child) {
            return Transform.translate(
              offset: Offset(0, -0.5 * value),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: Color.lerp(
                    Colors.transparent,
                    HyprColors.hover,
                    value,
                  ),
                  shape: const RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                  ),
                ),
                child: SizedBox.square(dimension: 22, child: child),
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: <Widget>[
              Center(child: _TrayIcon(icon: item.icon)),
              if (_statusDotColor(item.status) case final Color color)
                Positioned(
                  right: 1.5,
                  bottom: 1.5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xAA08131C),
                        width: 1,
                      ),
                    ),
                    child: const SizedBox(width: 6, height: 6),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TrayIcon extends StatelessWidget {
  const _TrayIcon({required this.icon});

  final TrayIcon icon;

  @override
  Widget build(BuildContext context) {
    final Color tint = HyprColors.textMuted;

    switch (icon.kind) {
      case TrayIconKind.none:
        return Icon(Icons.apps_rounded, size: 13, color: tint);
      case TrayIconKind.themePath:
        final String? path = icon.path;
        if (path == null || path.isEmpty) {
          return Icon(Icons.apps_rounded, size: 13, color: tint);
        }
        return _ThemedTrayIcon(path: path, tint: tint);
      case TrayIconKind.pngBytes:
        final List<int>? bytes = icon.pngBytes;
        if (bytes == null || bytes.isEmpty) {
          return Icon(Icons.apps_rounded, size: 13, color: tint);
        }
        return Image.memory(
          Uint8List.fromList(bytes),
          width: 13,
          height: 13,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          color: tint,
          colorBlendMode: BlendMode.srcIn,
          errorBuilder: (_, _, _) =>
              Icon(Icons.apps_rounded, size: 13, color: tint),
        );
    }
  }
}

class _ThemedTrayIcon extends StatelessWidget {
  const _ThemedTrayIcon({required this.path, required this.tint});

  final String path;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Icon(Icons.apps_rounded, size: 13, color: tint);

    if (path.toLowerCase().endsWith('.svg')) {
      return hyprLocalSvg(
        path: path,
        width: 13,
        height: 13,
        fallback: fallback,
        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      );
    }

    return hyprLocalImage(
      path: path,
      width: 13,
      height: 13,
      fallback: fallback,
      filterQuality: FilterQuality.medium,
      color: tint,
      colorBlendMode: BlendMode.srcIn,
      gaplessPlayback: true,
    );
  }
}

Color? _statusDotColor(TrayItemStatus status) {
  return switch (status) {
    TrayItemStatus.active => HyprColors.accentSoft,
    TrayItemStatus.needsAttention => const Color(0xFFE5C96F),
    TrayItemStatus.unknown || TrayItemStatus.passive => null,
  };
}
