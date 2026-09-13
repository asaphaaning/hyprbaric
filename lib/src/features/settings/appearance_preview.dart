import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import 'settings_primitives.dart';

/// A lightweight desktop illustration reflecting the real appearance draft.
class AppearancePreview extends StatelessWidget {
  const AppearancePreview({super.key, required this.status});

  final AppearanceStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = HyprPalette.fromAppearance(status);
    return SettingsCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR DESKTOP',
                  style: HyprInstrumentText.title.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A bar that feels at home.',
                  style: HyprInstrumentText.body,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Preview your appearance changes.',
                  style: HyprInstrumentText.meta,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox(
                height: 100,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF3D4665),
                            Color(0xFF171F32),
                            Color(0xFF4D3654),
                          ],
                        ),
                      ),
                    ),
                    const CustomPaint(painter: _Mountains()),
                    Align(
                      alignment: status.position == AppearancePosition.top
                          ? Alignment.topCenter
                          : Alignment.bottomCenter,
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        height: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF101218,
                          ).withValues(alpha: status.opacity / 100),
                          borderRadius: BorderRadius.circular(
                            status.cornerRadius / 3,
                          ),
                          border: Border.all(
                            color: HyprInstrumentColors.border.withValues(
                              alpha: .45,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            for (final width in [10.0, 22.0]) ...[
                              Container(
                                width: width,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: palette.accentSoft,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            const Spacer(),
                            for (var index = 0; index < 3; index++) ...[
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: HyprInstrumentColors.secondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Mountains extends CustomPainter {
  const _Mountains();

  @override
  void paint(Canvas canvas, Size size) {
    final ridge = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * .28, size.height * .45)
      ..lineTo(size.width * .4, size.height * .62)
      ..lineTo(size.width * .62, size.height * .2)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(ridge, Paint()..color = const Color(0xFF192336));
    final face = Path()
      ..moveTo(size.width * .62, size.height * .2)
      ..lineTo(size.width * .52, size.height * .72)
      ..lineTo(size.width * .75, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(face, Paint()..color = const Color(0xFF29364D));
  }

  @override
  bool shouldRepaint(_Mountains oldDelegate) => false;
}
