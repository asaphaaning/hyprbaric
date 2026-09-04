import 'package:flutter/material.dart';

/// The sheen falling off over the top of a glass surface.
class HyprGlassSheen {
  const HyprGlassSheen({
    required this.top,
    required this.mid,
    required this.bottom,
    this.midStop = 0.42,
  });

  /// Frames: `oklch(1 0 0 / 0.035) → 0.008 @42% → 0`.
  static const HyprGlassSheen frame = HyprGlassSheen(
    top: Color(0x09FFFFFF),
    mid: Color(0x02FFFFFF),
    bottom: Color(0x00FFFFFF),
  );

  /// Tiles at rest: `0.045 → 0.012 @45% → 0`.
  static const HyprGlassSheen tile = HyprGlassSheen(
    top: Color(0x0CFFFFFF),
    mid: Color(0x03FFFFFF),
    bottom: Color(0x00FFFFFF),
    midStop: 0.45,
  );

  /// Tiles under the pointer: `0.075 → 0.022 @45% → 0.005`.
  static const HyprGlassSheen tileHover = HyprGlassSheen(
    top: Color(0x13FFFFFF),
    mid: Color(0x06FFFFFF),
    bottom: Color(0x01FFFFFF),
    midStop: 0.45,
  );

  final Color top;
  final Color mid;
  final Color bottom;
  final double midStop;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[top, mid, bottom],
    stops: <double>[0, midStop, 1],
  );
}

/// Glassy dark surface shared by the gauge chassis, the scope frame and the
/// Wi-Fi tiles.
///
/// Every light layer is drawn as a real child rather than a `BlurStyle.inner`
/// shadow: Flutter offsets inner shadows the wrong way, which inverts the
/// reference's lit-top / shaded-bottom rim.
///
/// This sits beside [HyprGlassSurface] rather than among the control
/// primitives, because the two are the same kind of thing and were drifting
/// apart while separated: both clip a superellipse and stack light layers over
/// it, and both own a rim treatment. [HyprGlassSurface] is the panel and
/// popover shell, whose inset border is painted by [HyprInsetBorder]. This one
/// is the smaller free-standing plate, whose rim is a pair of hairlines and
/// whose fill is optional so the surface behind it shows through.
class HyprGlassFrame extends StatelessWidget {
  const HyprGlassFrame({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.fill,
    this.sheen = HyprGlassSheen.frame,
    this.rimLight = rimLightDefault,
    this.borderColor = const Color(0x8C000000),
    this.vignette = false,
    this.glow,
    this.shadows = defaultShadows,
  });

  /// `inset 1px 1px 0 oklch(1 0 0 / 0.075)`.
  static const Color rimLightDefault = Color(0x13FFFFFF);

  /// `inset 1px 1px 0 oklch(1 0 0 / 0.095)` — the hovered tile's rim.
  static const Color rimLightStrong = Color(0x18FFFFFF);

  /// `0 1px 2px oklch(0 0 0 / 0.4)`.
  static const List<BoxShadow> defaultShadows = <BoxShadow>[
    BoxShadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// `0 1px 2px oklch(0 0 0 / 0.35)` — the lighter drop the tiles use.
  static const List<BoxShadow> tileShadows = <BoxShadow>[
    BoxShadow(color: Color(0x59000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  final Widget child;
  final BorderRadius borderRadius;

  /// Base fill under the sheen. Null leaves the surface behind it showing
  /// through, which is how the Wi-Fi tiles are built.
  final Color? fill;
  final HyprGlassSheen sheen;
  final Color rimLight;
  final Color borderColor;

  /// `inset 0 0 30px oklch(0 0 0 / 0.4)`, pulling the edges down into the
  /// glass. Frames use it, tiles do not.
  final bool vignette;

  /// Inner accent wash marking the connected network.
  final Color? glow;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: fill,
        shape: RoundedSuperellipseBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: borderColor),
        ),
        shadows: shadows,
      ),
      child: ClipRSuperellipse(
        borderRadius: borderRadius,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: sheen.gradient),
              ),
            ),
            if (vignette)
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.95,
                      colors: <Color>[Color(0x00000000), Color(0x66000000)],
                      stops: <double>[0.45, 1],
                    ),
                  ),
                ),
              ),
            if (glow case final Color glow)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.9,
                      colors: <Color>[glow.withValues(alpha: 0), glow],
                      stops: const <double>[0.25, 1],
                    ),
                  ),
                ),
              ),
            child,
            // Above the child and ignoring pointers, matching how
            // [HyprGlassSurface] layers its inset border. Underneath, any
            // child that painted its own background erased the rim, which is
            // a trap for the next caller rather than a property of the design.
            Positioned.fill(
              child: IgnorePointer(child: _RimLight(color: rimLight)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The lit top and left edges of a glass plate.
///
/// Held one pixel in so the frame's own dark border stays visible outside it.
class _RimLight extends StatelessWidget {
  const _RimLight({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned(
          top: 1,
          left: 1,
          right: 1,
          child: ColoredBox(color: color, child: const SizedBox(height: 1)),
        ),
        Positioned(
          top: 1,
          left: 1,
          bottom: 1,
          child: ColoredBox(color: color, child: const SizedBox(width: 1)),
        ),
      ],
    );
  }
}
