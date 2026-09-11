import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';

import 'audio_mixer_preview.dart';

/// A repeatable desktop lighting fixture for judging the production glass.
class AudioMixerScene extends StatelessWidget {
  const AudioMixerScene({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF070A17),
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 512,
            height: 768,
            child: Stack(
              children: <Widget>[
                const Positioned.fill(child: _DesktopLight()),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 30,
                    color: const Color(0xA8080B20),
                    padding: const EdgeInsets.only(right: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        const Icon(
                          Icons.circle,
                          color: Color(0xFFEEEFFF),
                          size: 11,
                        ),
                        const SizedBox(width: 20),
                        const Icon(
                          Icons.circle,
                          color: Color(0xFFEEEFFF),
                          size: 11,
                        ),
                        const SizedBox(width: 20),
                        Container(
                          width: 30,
                          height: 27,
                          decoration: BoxDecoration(
                            color: const Color(0x334F547B),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: const Color(0xFFADB6DB),
                              width: .5,
                            ),
                          ),
                          child: const Icon(
                            Icons.volume_up_rounded,
                            size: 19,
                            color: Color(0xFFF7F7FF),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Icon(
                          Icons.link_rounded,
                          size: 20,
                          color: Color(0xFFB8C4FF),
                        ),
                        const SizedBox(width: 17),
                        const AudioMixerIcon(
                          size: 18,
                          color: Color(0xFFB8C4FF),
                        ),
                        const SizedBox(width: 17),
                        const Icon(
                          Icons.notifications_none_rounded,
                          size: 19,
                          color: Color(0xFFB8C4FF),
                        ),
                        const SizedBox(width: 29),
                        Text(
                          'Tue, Sep 17  14:27',
                          style: HyprTypography.popRow.copyWith(
                            color: const Color(0xFFF7F6FF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  top: 43,
                  left: 79,
                  width: 354,
                  child: AudioMixerPreview(animateMeters: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopLight extends StatelessWidget {
  const _DesktopLight();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF102557),
            Color(0xFF0A1025),
            Color(0xFF27134B),
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          _Glow(alignment: Alignment(-1.2, -.82), color: Color(0xFF2350CF)),
          _Glow(alignment: Alignment(1.1, .25), color: Color(0xFF932390)),
          _Glow(alignment: Alignment(-1.1, .82), color: Color(0xFF263CB1)),
          _Glow(alignment: Alignment(.0, 1.2), color: Color(0xFF722491)),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.alignment, required this.color});

  final Alignment alignment;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: alignment,
            radius: .65,
            colors: <Color>[color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
