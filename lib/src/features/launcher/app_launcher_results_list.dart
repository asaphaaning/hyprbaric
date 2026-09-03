import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'app_launcher_empty_states.dart';

class AppLauncherResultsList extends StatefulWidget {
  const AppLauncherResultsList({
    super.key,
    required this.results,
    required this.loading,
    required this.iconPathsByEntryId,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLaunch,
  });

  final AppLauncherResults? results;
  final bool loading;
  final Map<String, String> iconPathsByEntryId;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<AppLauncherEntry> onLaunch;

  @override
  State<AppLauncherResultsList> createState() => _AppLauncherResultsListState();
}

class _AppLauncherResultsListState extends State<AppLauncherResultsList> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const LauncherLoadingState();
    }

    final AppLauncherResults readyResults = widget.results!;
    if (readyResults.entries.isEmpty) {
      return LauncherEmptyState(
        message: readyResults.message ?? 'No applications matched that query.',
      );
    }

    final String sectionLabel = readyResults.query.trim().isEmpty
        ? 'Suggested'
        : 'Applications';

    return Scrollbar(
      controller: _controller,
      thickness: 4,
      radius: const Radius.circular(2),
      thumbVisibility: false,
      child: ListView(
        controller: _controller,
        key: const ValueKey<String>('app-launcher-results'),
        padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
        children: <Widget>[
          _LauncherSectionHeader(
            label: sectionLabel,
            count: readyResults.entries.length,
          ),
          for (int index = 0; index < readyResults.entries.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: AppLauncherResultTile(
                entry: readyResults.entries[index],
                iconPath:
                    readyResults.entries[index].iconPath ??
                    widget.iconPathsByEntryId[readyResults.entries[index].id],
                selected: index == widget.selectedIndex,
                onSelect: () => widget.onSelect(index),
                onLaunch: () => widget.onLaunch(readyResults.entries[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class _LauncherSectionHeader extends StatelessWidget {
  const _LauncherSectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
      child: Row(
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: HyprTypography.compactMonoStrong.copyWith(
              color: HyprColors.textFaint,
              fontSize: HyprTypography.size(9.5),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.52,
              height: 1,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(color: HyprColors.popupStroke),
              child: SizedBox(height: 1),
            ),
          ),
          const SizedBox(width: 10),
          HyprInlineTag(
            label: count.toString(),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            borderRadius: HyprRadii.badgeRadius,
            color: const Color(0x66000000),
            borderColor: HyprColors.popupStroke,
            textColor: HyprColors.textFaint,
            style: HyprTypography.compactMonoStrong.copyWith(
              fontSize: HyprTypography.size(9),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.72,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class AppLauncherResultTile extends StatelessWidget {
  const AppLauncherResultTile({
    super.key,
    required this.entry,
    required this.iconPath,
    required this.selected,
    required this.onSelect,
    required this.onLaunch,
  });

  final AppLauncherEntry entry;
  final String? iconPath;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    return HyprInteractiveTile(
      key: ValueKey<String>('app-launcher-entry-${entry.id}'),
      selected: selected,
      onPressed: onLaunch,
      onHoverChanged: (bool hovered) {
        if (hovered) {
          onSelect();
        }
      },
      color: Colors.transparent,
      hoverColor: Colors.transparent,
      selectedColor: Colors.transparent,
      borderColor: Colors.transparent,
      hoverBorderColor: Colors.transparent,
      selectedBorderColor: Colors.transparent,
      pressedScale: 1,
      borderRadius: HyprRadii.compactRadius,
      builder: (BuildContext context, HyprInteractiveTileState state) {
        return AnimatedContainer(
          duration: HyprMotion.hover,
          curve: HyprMotion.hoverCurve,
          decoration: ShapeDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: <Color>[Color(0x1A16B7F4), Color(0x06FFFFFF)],
                  )
                : const LinearGradient(
                    colors: <Color>[Colors.transparent, Colors.transparent],
                  ),
            shape: RoundedSuperellipseBorder(
              borderRadius: HyprRadii.compactRadius,
              side: BorderSide(
                color: selected ? HyprColors.popupStroke : Colors.transparent,
              ),
            ),
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 3,
                top: 8,
                bottom: 8,
                child: AnimatedContainer(
                  duration: HyprMotion.hover,
                  curve: HyprMotion.hoverCurve,
                  width: 2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1),
                    color: selected ? HyprColors.accent : Colors.transparent,
                    boxShadow: selected
                        ? const <BoxShadow>[
                            BoxShadow(color: Color(0x8A16B7F4), blurRadius: 6),
                          ]
                        : null,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 7, 10, 7),
                child: Row(
                  children: <Widget>[
                    AppLauncherIcon(
                      entry: entry,
                      iconPath: iconPath,
                      selected: selected,
                      size: 30,
                      radius: HyprRadii.row,
                      padding: const EdgeInsets.all(5),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _AppLauncherEntryLabels(entry: entry)),
                    const SizedBox(width: 10),
                    _LauncherKindTag(entry: entry, selected: selected),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AppLauncherIcon extends StatelessWidget {
  const AppLauncherIcon({
    super.key,
    required this.entry,
    required this.iconPath,
    required this.selected,
    this.size = 44,
    this.radius = 14,
    this.padding = const EdgeInsets.all(7),
  });

  final AppLauncherEntry entry;
  final String? iconPath;
  final bool selected;
  final double size;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected
        ? HyprColors.surfaceStrong
        : HyprColors.textMuted;
    final Widget fallback = AppLauncherInitial(
      name: entry.name,
      color: foreground,
      size: size,
    );
    return AnimatedContainer(
      duration: HyprMotion.selection,
      curve: HyprMotion.selectionCurve,
      width: size,
      height: size,
      padding: padding,
      decoration: ShapeDecoration(
        color: selected ? HyprColors.accent : HyprColors.fillStrong,
        shadows: const <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(
            color: selected ? HyprColors.borderSoft : HyprColors.popupStroke,
          ),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          iconPath == null
              ? fallback
              : AppLauncherIconFile(
                  path: iconPath!,
                  dimension: (size - padding.horizontal)
                      .clamp(1, size)
                      .toDouble(),
                  fallback: fallback,
                ),
          const IgnorePointer(child: _IconSheen()),
        ],
      ),
    );
  }
}

class _IconSheen extends StatelessWidget {
  const _IconSheen();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: <double>[0, 0.45, 1],
          colors: <Color>[
            Color(0x2EFFFFFF),
            Color(0x00000000),
            Color(0x00000000),
          ],
        ),
      ),
    );
  }
}

class AppLauncherIconFile extends StatelessWidget {
  const AppLauncherIconFile({
    super.key,
    required this.path,
    required this.dimension,
    required this.fallback,
  }) : assert(
         dimension > 0 && dimension < double.infinity,
         'AppLauncherIconFile requires a finite positive dimension.',
       );

  final String path;
  final double dimension;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final File file = File(path);
    final String lowerPath = path.toLowerCase();
    final int cacheDimension =
        (dimension * MediaQuery.devicePixelRatioOf(context)).ceil();

    if (lowerPath.endsWith('.svg')) {
      return SizedBox.square(
        dimension: dimension,
        child: SvgPicture.file(
          file,
          width: dimension,
          height: dimension,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => fallback,
          errorBuilder: (_, _, _) => fallback,
        ),
      );
    }

    return SizedBox.square(
      dimension: dimension,
      child: Image.file(
        file,
        width: dimension,
        height: dimension,
        cacheWidth: cacheDimension,
        cacheHeight: cacheDimension,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class AppLauncherInitial extends StatelessWidget {
  const AppLauncherInitial({
    super.key,
    required this.name,
    required this.color,
    required this.size,
  });

  final String name;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: HyprGlyphBadge(
        name: name,
        dimension: size,
        maxCharacters: 1,
        backgroundColor: Colors.transparent,
        borderColor: Colors.transparent,
        foregroundColor: color,
        textStyle: HyprTypography.appBadge.copyWith(
          color: color,
          fontSize: HyprTypography.size(size * 0.43 < 9 ? 9 : size * 0.43),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AppLauncherEntryLabels extends StatelessWidget {
  const _AppLauncherEntryLabels({required this.entry});

  final AppLauncherEntry entry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HyprTypography.popRowStrong.copyWith(
            color: HyprColors.text,
            fontSize: HyprTypography.size(13.5),
            fontWeight: FontWeight.w500,
            letterSpacing: -0.067,
            height: 1.16,
          ),
        ),
        if (entry.subtitle != null) ...<Widget>[
          const SizedBox(height: 1),
          Text(
            entry.subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HyprTypography.popRow.copyWith(
              color: HyprColors.textFaint,
              fontSize: HyprTypography.size(11.5),
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}

class _LauncherKindTag extends StatelessWidget {
  const _LauncherKindTag({required this.entry, required this.selected});

  final AppLauncherEntry entry;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return HyprInlineTag(
      label: entry.terminal ? 'TERM' : 'APP',
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      borderRadius: HyprRadii.badgeRadius,
      color: const Color(0x59000000),
      borderColor: selected ? HyprColors.borderSoft : HyprColors.popupStroke,
      textColor: selected ? HyprColors.textMuted : HyprColors.textFaint,
      style: HyprTypography.compactMonoStrong.copyWith(
        fontSize: HyprTypography.size(9),
        fontWeight: FontWeight.w600,
        letterSpacing: 1.08,
        height: 1,
      ),
    );
  }
}
