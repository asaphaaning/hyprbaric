import 'package:flutter/material.dart';

import '../../theme/hypr_motion.dart';

/// Hardware-style rocker switch: a sunk track with a raised cap that carries a
/// centre seam, matching the reference `.mini-toggle` / `.wifi-toggle-switch`.
class HyprHardwareToggle extends StatelessWidget {
  const HyprHardwareToggle({
    super.key,
    required this.value,
    this.width = 36,
    this.height = 20,
    this.capWidth = 22.5,
    this.capHeight = 16,
  });

  final bool value;
  final double width;
  final double height;
  final double capWidth;
  final double capHeight;

  static const Color _trackOff = Color(0xFF060709);
  static const List<Color> _trackOn = <Color>[
    Color(0xFF0070CC),
    Color(0xFF0063B8),
    Color(0xFF004D92),
    Color(0xFF00396F),
  ];
  static const Color _seam = Color(0x80A2A5AA);

  @override
  Widget build(BuildContext context) {
    const double inset = 2;
    final double travel = width - capWidth - inset * 2;

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: value ? null : _trackOff,
          gradient: value
              ? const LinearGradient(
                  colors: _trackOn,
                  stops: <double>[0, 0.46, 0.78, 1],
                )
              : null,
          shape: const StadiumBorder(),
          // `0 1px 0 oklch(1 0 0 / 0.055)` under the track.
          shadows: <BoxShadow>[
            const BoxShadow(color: Color(0x0EFFFFFF), offset: Offset(0, 1)),
            if (value)
              const BoxShadow(
                color: Color(0x66138ADB),
                blurRadius: 10,
                spreadRadius: -3,
                offset: Offset(0, 3),
              ),
          ],
        ),
        child: ClipPath(
          clipper: const ShapeBorderClipper(shape: StadiumBorder()),
          child: Stack(
            children: <Widget>[
              // Track well: dark at the top, faint rim light along the bottom.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Color(value ? 0x52000000 : 0x8C000000),
                        const Color(0x00000000),
                      ],
                      stops: const <double>[0, 0.42],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ColoredBox(
                  color: value
                      ? const Color(0x4747A8E8)
                      : const Color(0x0BFFFFFF),
                  child: const SizedBox(height: 1),
                ),
              ),
              AnimatedPositioned(
                duration: HyprMotion.switcher,
                curve: HyprMotion.switchInCurve,
                left: inset + (value ? travel : 0),
                top: (height - capHeight) / 2,
                child: _ToggleCap(width: capWidth, height: capHeight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleCap extends StatelessWidget {
  const _ToggleCap({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: const ShapeDecoration(
          gradient: LinearGradient(
            // `linear-gradient(158deg, …)`.
            begin: Alignment(-0.37, -1),
            end: Alignment(0.37, 1),
            colors: <Color>[
              Color(0xFF595C63),
              Color(0xFF474A4F),
              Color(0xFF393B40),
            ],
            stops: <double>[0, 0.46, 1],
          ),
          shape: StadiumBorder(),
          shadows: <BoxShadow>[
            BoxShadow(
              color: Color(0x8C000000),
              blurRadius: 4,
              spreadRadius: -1,
              offset: Offset(0, 2),
            ),
            BoxShadow(
              color: Color(0x80000000),
              blurRadius: 10,
              spreadRadius: -4,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: ClipPath(
          clipper: const ShapeBorderClipper(shape: StadiumBorder()),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Rim light along the cap's top edge.
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ColoredBox(
                  color: Color(0x29FFFFFF),
                  child: SizedBox(height: 1),
                ),
              ),
              // Centre seam: 1.5px tall bar over the middle 52% of the cap.
              SizedBox(
                width: 1.5,
                height: height * 0.52,
                child: const ColoredBox(color: HyprHardwareToggle._seam),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
