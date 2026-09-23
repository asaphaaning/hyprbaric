import 'dart:typed_data';

import 'package:flutter/foundation.dart' as foundation;
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
            key: ValueKey<String>(item.id),
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
              Center(
                child: ColorFiltered(
                  colorFilter: _trayGrayscale,
                  child: _TrayIcon(icon: item.icon),
                ),
              ),
              if (_statusDotColor(item.status, context.hyprPalette.accentSoft)
                  case final Color color)
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

// Preserve luminance detail while lifting black to 20% gray on the dark bar.
// Each RGB channel becomes 0.8 × luminance + 51; alpha stays unchanged.
const ColorFilter _trayGrayscale = ColorFilter.matrix(<double>[
  0.17008,
  0.57216,
  0.05776,
  0,
  51,
  0.17008,
  0.57216,
  0.05776,
  0,
  51,
  0.17008,
  0.57216,
  0.05776,
  0,
  51,
  0,
  0,
  0,
  1,
  0,
]);

class _TrayIcon extends StatefulWidget {
  const _TrayIcon({required this.icon});

  /// Optical match for [HyprIconSizes.bar]. Tray art is full-bleed, so it
  /// sits a little under that em size.
  static const double extent = 14.5;

  final TrayIcon icon;

  @override
  State<_TrayIcon> createState() => _TrayIconState();
}

class _TrayIconState extends State<_TrayIcon> {
  Uint8List? _pngBytes;

  @override
  void initState() {
    super.initState();
    _syncPngBytes();
  }

  @override
  void didUpdateWidget(covariant _TrayIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPngBytes();
  }

  void _syncPngBytes() {
    final List<int>? bytes = widget.icon.kind == TrayIconKind.pngBytes
        ? widget.icon.pngBytes
        : null;
    if (bytes == null || bytes.isEmpty) {
      _pngBytes = null;
    } else if (!foundation.listEquals(_pngBytes, bytes)) {
      _pngBytes = Uint8List.fromList(bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color tint = HyprColors.textMuted;

    switch (widget.icon.kind) {
      case TrayIconKind.none:
        return Icon(Icons.apps_rounded, size: _TrayIcon.extent, color: tint);
      case TrayIconKind.themePath:
        final String? path = widget.icon.path;
        if (path == null || path.isEmpty) {
          return Icon(Icons.apps_rounded, size: _TrayIcon.extent, color: tint);
        }
        return _ThemedTrayIcon(path: path, tint: tint);
      case TrayIconKind.pngBytes:
        final Uint8List? bytes = _pngBytes;
        if (bytes == null) {
          return Icon(Icons.apps_rounded, size: _TrayIcon.extent, color: tint);
        }
        return Image.memory(
          bytes,
          width: _TrayIcon.extent,
          height: _TrayIcon.extent,
          cacheWidth:
              (_TrayIcon.extent * MediaQuery.devicePixelRatioOf(context))
                  .ceil()
                  .clamp(1, 1 << 16),
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) =>
              Icon(Icons.apps_rounded, size: _TrayIcon.extent, color: tint),
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
    final Widget fallback = Icon(
      Icons.apps_rounded,
      size: _TrayIcon.extent,
      color: tint,
    );

    if (path.toLowerCase().endsWith('.svg')) {
      return hyprLocalSvg(
        path: path,
        width: _TrayIcon.extent,
        height: _TrayIcon.extent,
        fallback: fallback,
      );
    }

    return hyprLocalImage(
      path: path,
      width: _TrayIcon.extent,
      height: _TrayIcon.extent,
      fallback: fallback,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    );
  }
}

Color? _statusDotColor(TrayItemStatus status, Color accent) {
  return switch (status) {
    TrayItemStatus.active => accent,
    TrayItemStatus.needsAttention => const Color(0xFFE5C96F),
    TrayItemStatus.unknown || TrayItemStatus.passive => null,
  };
}
