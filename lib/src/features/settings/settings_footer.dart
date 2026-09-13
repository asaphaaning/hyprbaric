import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../widgets/hypr_surface.dart';

class SettingsVersionFooter extends ConsumerWidget {
  const SettingsVersionFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String version = ref
        .watch(appStatusProvider)
        .maybeWhen(data: (status) => status.version, orElse: () => '...');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'hyprbaric',
          style: HyprInstrumentText.meta.copyWith(
            color: HyprInstrumentColors.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'v$version',
          style: HyprInstrumentText.meta.copyWith(
            color: HyprInstrumentColors.secondary,
            fontSize: HyprTypography.size(10),
          ),
        ),
      ],
    );
  }
}
