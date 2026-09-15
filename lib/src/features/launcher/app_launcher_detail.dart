import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'app_launcher_empty_states.dart';
import 'app_launcher_footer.dart';
import 'app_launcher_results_list.dart';

class AppLauncherDetailPane extends StatelessWidget {
  const AppLauncherDetailPane({
    super.key,
    required this.entry,
    required this.iconPath,
    required this.onLaunch,
  });

  final AppLauncherEntry? entry;
  final String? iconPath;
  final VoidCallback? onLaunch;

  @override
  Widget build(BuildContext context) {
    final AppLauncherEntry? selectedEntry = entry;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0x2E000000), Color(0x4D000000)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0xB3000000),
            blurRadius: 10,
            spreadRadius: -8,
            offset: Offset(-6, 0),
          ),
        ],
      ),
      child: CustomPaint(
        painter: const LauncherDotGridPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: selectedEntry == null
              ? const _LauncherDetailEmpty()
              : _LauncherDetailContent(
                  entry: selectedEntry,
                  iconPath: iconPath,
                  onLaunch: onLaunch,
                ),
        ),
      ),
    );
  }
}

class _LauncherDetailEmpty extends StatelessWidget {
  const _LauncherDetailEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const DecoratedBox(
            decoration: ShapeDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.3, -0.45),
                radius: 0.85,
                colors: <Color>[Color(0xFF26323D), Color(0xFF111922)],
              ),
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.all(Radius.circular(HyprRadii.tile)),
              ),
            ),
            child: SizedBox.square(
              dimension: 56,
              child: Icon(
                Iconsax.search_normal_1_copy,
                size: 20,
                color: HyprColors.textFaint,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'NOTHING SELECTED',
            style: HyprTypography.compactMonoStrong.copyWith(
              color: HyprColors.textFaint,
              fontSize: HyprTypography.size(11),
              letterSpacing: 0.88,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Search or pick an app',
            style: HyprTypography.compactMono.copyWith(
              color: HyprColors.textFaint.withValues(alpha: 0.60),
              fontSize: HyprTypography.size(10),
            ),
          ),
        ],
      ),
    );
  }
}

class _LauncherDetailContent extends StatelessWidget {
  const _LauncherDetailContent({
    required this.entry,
    required this.iconPath,
    required this.onLaunch,
  });

  final AppLauncherEntry entry;
  final String? iconPath;
  final VoidCallback? onLaunch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _LauncherDetailHeader(entry: entry, iconPath: iconPath),
        const SizedBox(height: 12),
        _LauncherMetadataPlate(entry: entry, iconPath: iconPath),
        const SizedBox(height: 12),
        Text(
          'ACTIONS',
          style: HyprTypography.compactMonoStrong.copyWith(
            color: HyprColors.textFaint,
            fontSize: HyprTypography.size(9.5),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.52,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _LauncherActions(entry: entry, onLaunch: onLaunch),
        ),
      ],
    );
  }
}

class _LauncherDetailHeader extends StatelessWidget {
  const _LauncherDetailHeader({required this.entry, required this.iconPath});

  final AppLauncherEntry entry;
  final String? iconPath;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HyprColors.popupStroke)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: <Widget>[
            AppLauncherIcon(
              entry: entry,
              iconPath: iconPath,
              selected: true,
              size: 52,
              radius: 14,
              padding: const EdgeInsets.all(8),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HyprTypography.settingHeading.copyWith(
                      fontSize: HyprTypography.size(16),
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.16,
                      height: 1.15,
                    ),
                  ),
                  if (entry.subtitle != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      entry.subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HyprTypography.popRow.copyWith(
                        color: HyprColors.textMuted,
                        fontSize: HyprTypography.size(11.5),
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LauncherMetadataPlate extends StatelessWidget {
  const _LauncherMetadataPlate({required this.entry, required this.iconPath});

  final AppLauncherEntry entry;
  final String? iconPath;

  @override
  Widget build(BuildContext context) {
    final List<_LauncherMetaRow> rows = <_LauncherMetaRow>[
      _LauncherMetaRow('Type', entry.terminal ? 'Terminal app' : 'Application'),
      if (entry.iconName != null) _LauncherMetaRow('Icon', entry.iconName!),
      if (iconPath != null) _LauncherMetaRow('Icon path', iconPath!),
    ];

    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: Color(0x52000000),
        shadows: <BoxShadow>[
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
        shape: RoundedSuperellipseBorder(
          borderRadius: HyprRadii.controlRadius,
          side: BorderSide(color: Color(0x80000000)),
        ),
      ),
      child: ClipRRect(
        borderRadius: HyprRadii.controlRadius,
        child: Column(
          children: <Widget>[
            for (int index = 0; index < rows.length; index++) ...<Widget>[
              if (index > 0)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: HyprColors.popupStroke,
                ),
              _LauncherMetaRowWidget(row: rows[index]),
            ],
          ],
        ),
      ),
    );
  }
}

class _LauncherMetaRow {
  const _LauncherMetaRow(this.label, this.value);

  final String label;
  final String value;
}

class _LauncherMetaRowWidget extends StatelessWidget {
  const _LauncherMetaRowWidget({required this.row});

  final _LauncherMetaRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: <Widget>[
          Text(
            row.label.toUpperCase(),
            style: HyprTypography.compactMonoStrong.copyWith(
              color: HyprColors.textFaint,
              fontSize: HyprTypography.size(9.5),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.95,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              row.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: HyprTypography.compactMono.copyWith(
                color: HyprColors.textMuted,
                fontSize: HyprTypography.size(10.5),
                fontFeatures: HyprTypography.tabularNumbers,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LauncherActions extends StatelessWidget {
  const _LauncherActions({required this.entry, required this.onLaunch});

  final AppLauncherEntry entry;
  final VoidCallback? onLaunch;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: Color(0x52000000),
        shape: RoundedSuperellipseBorder(
          borderRadius: HyprRadii.controlRadius,
          side: BorderSide(color: Color(0x80000000)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _LauncherActionRow(
              primary: true,
              icon: Iconsax.arrow_right_1_copy,
              label: 'Open ${entry.name}',
              keys: const <String>['↵'],
              onPressed: onLaunch,
            ),
            const _LauncherActionRow(
              icon: Iconsax.info_circle_copy,
              label: 'Desktop entry selected',
              keys: <String>[],
              onPressed: null,
            ),
          ],
        ),
      ),
    );
  }
}

class _LauncherActionRow extends StatelessWidget {
  const _LauncherActionRow({
    required this.icon,
    required this.label,
    required this.keys,
    required this.onPressed,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final List<String> keys;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return HyprInteractiveTile(
      semanticLabel: label,
      onPressed: onPressed,
      enabled: onPressed != null,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      borderRadius: HyprRadii.cardRadius,
      color: primary ? const Color(0x2E16B7F4) : Colors.transparent,
      hoverColor: primary ? const Color(0x3D16B7F4) : HyprColors.hover,
      borderColor: primary ? const Color(0x5916B7F4) : Colors.transparent,
      hoverBorderColor: primary ? const Color(0x8A16B7F4) : Colors.transparent,
      pressedScale: 0.98,
      builder: (BuildContext context, HyprInteractiveTileState state) {
        final Color foreground = primary
            ? HyprColors.text
            : state.hovered
            ? HyprColors.text
            : HyprColors.textMuted;
        return Row(
          children: <Widget>[
            DecoratedBox(
              decoration: ShapeDecoration(
                color: primary
                    ? const Color(0x3316B7F4)
                    : const Color(0x66000000),
                shape: RoundedSuperellipseBorder(
                  borderRadius: HyprRadii.cardRadius,
                  side: BorderSide(
                    color: primary
                        ? const Color(0x8016B7F4)
                        : HyprColors.popupStroke,
                  ),
                ),
              ),
              child: SizedBox.square(
                dimension: 20,
                child: Icon(
                  icon,
                  size: 11,
                  color: primary
                      ? context.hyprPalette.accentSoft
                      : HyprColors.textFaint,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HyprTypography.popRow.copyWith(
                  color: foreground,
                  fontSize: HyprTypography.size(12),
                  fontWeight: primary ? FontWeight.w500 : FontWeight.w400,
                  height: 1,
                ),
              ),
            ),
            if (keys.isNotEmpty) ...<Widget>[
              const SizedBox(width: 8),
              for (final String key in keys)
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: LauncherKeycap(label: key, primary: primary),
                ),
            ],
          ],
        );
      },
    );
  }
}
