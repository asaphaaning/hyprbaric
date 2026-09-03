import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'power_colors.dart';
import 'power_formatting.dart';

class PowerProfilePad extends StatelessWidget {
  const PowerProfilePad({
    super.key,
    required this.profile,
    required this.active,
    required this.enabled,
    required this.onPressed,
  });

  final PowerProfile profile;
  final bool active;
  final bool enabled;
  final ValueChanged<PowerProfile> onPressed;

  @override
  Widget build(BuildContext context) {
    final _ProfilePalette palette = _ProfilePalette(profile);
    return HyprInteractiveTile(
      semanticLabel: '${profileLabel(profile)} power profile',
      enabled: enabled,
      selected: active,
      onPressed: () => onPressed(profile),
      height: 122,
      borderRadius: BorderRadius.circular(7),
      color: const Color(0xFF101920),
      hoverColor: const Color(0xFF141F27),
      selectedColor: const Color(0xFF111B23),
      borderColor: Colors.black.withValues(alpha: 0.56),
      hoverBorderColor: HyprColors.borderSoft,
      selectedBorderColor: Colors.black.withValues(alpha: 0.62),
      pressedScale: 0.985,
      shadowsBuilder: (HyprInteractiveTileState state) => <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.38),
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
      ],
      builder: (BuildContext context, HyprInteractiveTileState state) {
        final bool vivid = state.hovered || active;
        return Opacity(
          opacity: enabled ? 1 : 0.42,
          child: Column(
            children: <Widget>[
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: active ? palette.activeDisc : palette.disc,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.black.withValues(alpha: 0.55),
                          ),
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                            blurStyle: BlurStyle.inner,
                          ),
                        ],
                      ),
                    ),
                    CustomPaint(
                      painter: _ProfileSpectrumPainter(
                        profile: profile,
                        color: active ? palette.activeMotif : palette.motif,
                        highlight: palette.highlight,
                        vivid: vivid,
                      ),
                    ),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: active
                        ? <Color>[
                            Color.alphaBlend(
                              palette.accent.withValues(alpha: 0.11),
                              const Color(0xFF1B242C),
                            ),
                            Color.alphaBlend(
                              palette.accent.withValues(alpha: 0.04),
                              const Color(0xFF111920),
                            ),
                          ]
                        : const <Color>[Color(0xFF1A232B), Color(0xFF111920)],
                  ),
                ),
                child: SizedBox(
                  height: 44,
                  width: double.infinity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        profileLabel(profile).toUpperCase(),
                        textAlign: TextAlign.center,
                        style: HyprTypography.compactMonoStrong.copyWith(
                          color: active
                              ? Color.alphaBlend(
                                  palette.accent.withValues(alpha: 0.45),
                                  HyprColors.text,
                                )
                              : HyprColors.text,
                          fontSize: HyprTypography.size(11),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.42,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        profileSubtitle(profile).toUpperCase(),
                        textAlign: TextAlign.center,
                        style: HyprTypography.compactMono.copyWith(
                          color: HyprColors.textFaint.withValues(alpha: 0.7),
                          fontSize: HyprTypography.size(8),
                          letterSpacing: 1.28,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileSpectrumPainter extends CustomPainter {
  const _ProfileSpectrumPainter({
    required this.profile,
    required this.color,
    required this.highlight,
    required this.vivid,
  });

  final PowerProfile profile;
  final Color color;
  final Color highlight;
  final bool vivid;

  @override
  void paint(Canvas canvas, Size size) {
    final List<double> heights = _heights(profile);
    final List<double> peaks = _peaks(profile, heights);
    final Paint grid = Paint()
      ..color = color.withValues(alpha: vivid ? 0.24 : 0.16)
      ..strokeWidth = 0.45;
    final Paint bar = Paint()
      ..color = color.withValues(alpha: vivid ? 0.95 : 0.78)
      ..style = PaintingStyle.fill;
    final Paint hi = Paint()
      ..color = highlight.withValues(alpha: vivid ? 0.32 : 0.18)
      ..strokeWidth = 1;

    for (final double fraction in <double>[0.25, 0.5, 0.75]) {
      final double y = 6 + (size.height - 12) * fraction;
      _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), grid);
    }

    final double baseline = size.height - 5;
    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      grid..strokeWidth = 0.6,
    );

    final double gap = 1.0;
    final double barWidth =
        (size.width - gap * (heights.length - 1)) / heights.length;
    final double usableHeight = size.height - 11;
    for (int index = 0; index < heights.length; index += 1) {
      final double x = index * (barWidth + gap);
      final double barHeight = (heights[index] * usableHeight).clamp(
        1.4,
        usableHeight,
      );
      final double y = baseline - barHeight;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          Radius.circular(barWidth / 2),
        ),
        bar,
      );
      final double peakY = baseline - peaks[index] * usableHeight - 0.8;
      canvas.drawRect(Rect.fromLTWH(x, peakY, barWidth, 0.7), bar);
    }

    final int dotIndex = switch (profile) {
      PowerProfile.saver => 1,
      PowerProfile.balanced => 6,
      PowerProfile.performance => 13,
    };
    final double dotX = dotIndex * (barWidth + gap) + barWidth / 2;
    final double dotY = baseline - heights[dotIndex] * usableHeight - 5;
    canvas.drawCircle(Offset(dotX, dotY), 2.1, Paint()..color = highlight);
    canvas.drawLine(
      Offset(0, baseline + 1),
      Offset(size.width, baseline + 1),
      hi,
    );
  }

  @override
  bool shouldRepaint(covariant _ProfileSpectrumPainter oldDelegate) {
    return oldDelegate.profile != profile ||
        oldDelegate.color != color ||
        oldDelegate.highlight != highlight ||
        oldDelegate.vivid != vivid;
  }
}

void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
  const double dash = 2.0;
  const double gap = 2.4;
  double x = start.dx;
  while (x < end.dx) {
    canvas.drawLine(Offset(x, start.dy), Offset(x + dash, end.dy), paint);
    x += dash + gap;
  }
}

List<double> _heights(PowerProfile profile) => switch (profile) {
  PowerProfile.saver => const <double>[
    0.42,
    0.55,
    0.48,
    0.36,
    0.30,
    0.22,
    0.18,
    0.15,
    0.13,
    0.10,
    0.09,
    0.08,
    0.07,
    0.06,
    0.06,
    0.05,
    0.05,
  ],
  PowerProfile.balanced => const <double>[
    0.18,
    0.28,
    0.40,
    0.54,
    0.66,
    0.74,
    0.80,
    0.78,
    0.72,
    0.65,
    0.55,
    0.45,
    0.36,
    0.28,
    0.20,
    0.15,
    0.12,
  ],
  PowerProfile.performance => const <double>[
    0.62,
    0.78,
    0.70,
    0.85,
    0.95,
    0.88,
    0.92,
    0.84,
    0.95,
    0.90,
    0.86,
    0.92,
    0.82,
    0.96,
    0.88,
    0.80,
    0.76,
  ],
};

List<double> _peaks(PowerProfile profile, List<double> heights) {
  return heights
      .map(
        (double height) => switch (profile) {
          PowerProfile.performance => (height + 0.06).clamp(0, 0.98).toDouble(),
          _ => height + 0.08,
        },
      )
      .toList(growable: false);
}

class _ProfilePalette {
  factory _ProfilePalette(PowerProfile profile) {
    return switch (profile) {
      PowerProfile.saver => const _ProfilePalette.values(
        disc: Color(0xFF17402B),
        activeDisc: Color(0xFF28A35D),
        motif: Color(0xFF33875B),
        activeMotif: Color(0xFF145C34),
        highlight: Color(0xFF66D98A),
        accent: PowerColors.healthy,
      ),
      PowerProfile.balanced => const _ProfilePalette.values(
        disc: Color(0xFF49361A),
        activeDisc: Color(0xFFC98622),
        motif: Color(0xFF8E6230),
        activeMotif: Color(0xFF683710),
        highlight: Color(0xFFE4B548),
        accent: PowerColors.low,
      ),
      PowerProfile.performance => const _ProfilePalette.values(
        disc: Color(0xFF352353),
        activeDisc: Color(0xFF8541B6),
        motif: Color(0xFF6D459A),
        activeMotif: Color(0xFF3E1E6E),
        highlight: Color(0xFFB277E8),
        accent: Color(0xFFB164F0),
      ),
    };
  }

  const _ProfilePalette.values({
    required this.disc,
    required this.activeDisc,
    required this.motif,
    required this.activeMotif,
    required this.highlight,
    required this.accent,
  });

  final Color disc;
  final Color activeDisc;
  final Color motif;
  final Color activeMotif;
  final Color highlight;
  final Color accent;
}
