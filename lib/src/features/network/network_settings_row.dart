import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../widgets/primitives/primitives.dart';
import 'network_chrome.dart';

class NetworkSettingsRow extends StatelessWidget {
  const NetworkSettingsRow({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return HyprPlateButton(
      label: 'NETWORK SETTINGS',
      icon: Iconsax.setting_2_copy,
      semanticLabel: 'Network settings',
      onPressed: onPressed,
      labelColor: NetworkMenuColors.fg1,
      iconColor: NetworkMenuColors.fg2,
      trailingColor: NetworkMenuColors.fg3,
    );
  }
}
