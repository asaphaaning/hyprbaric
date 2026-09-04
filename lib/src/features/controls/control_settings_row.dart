import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';

class ControlSettingsRow extends StatelessWidget {
  const ControlSettingsRow({super.key, required this.onPressed, this.shortcut});

  final VoidCallback onPressed;

  /// The user's configured chord, or null when the binding is unknown or
  /// disabled.
  final String? shortcut;

  /// The row's fixed height, exposed so layout tests do not have to hardcode
  /// it as a magic number.
  static const double height = HyprPlateButton.height;

  @override
  Widget build(BuildContext context) {
    return HyprPlateButton(
      label: 'BAR SETTINGS',
      icon: Iconsax.setting_2_copy,
      semanticLabel: 'Bar settings',
      onPressed: onPressed,
      shortcut: shortcut,
      labelColor: HyprConsoleColors.text,
      iconColor: HyprConsoleColors.textMuted,
      trailingColor: HyprConsoleColors.textFaint,
      frameKey: const ValueKey<String>('control-settings-frame'),
      faceKey: const ValueKey<String>('control-settings-face'),
    );
  }
}
