import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';
import 'audio_chrome.dart';

/// Cool charcoal glass shared by the mixer and isolated instrument previews.
///
/// Uses the same translucent fill and corner-safe chrome as other popovers.
/// Hyprland supplies desktop blur: a Flutter backdrop filter can only sample
/// this window, and filtering a shadow beneath the fill makes it nearly opaque.
class AudioMixerSurface extends StatelessWidget {
  const AudioMixerSurface({
    super.key,
    required this.borderRadius,
    required this.child,
  });

  /// Shared clipping and border geometry.
  final BorderRadius borderRadius;

  /// Instruments rendered on the glass.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return HyprInstrumentSurface(
      borderRadius: borderRadius,
      borderColor: AudioMixerColors.border.withValues(alpha: .45),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-.7, -.15),
            radius: 1,
            colors: <Color>[Color(0x182C303A), Color(0x002C303A)],
          ),
        ),
        child: child,
      ),
    );
  }
}
