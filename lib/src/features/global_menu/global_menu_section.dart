import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../../state/rust_signals/global_menu.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import '../rust_commands.dart';

/// Geometry of an open menu, from the v6 reference.
abstract final class _Menu {
  static const double panelMinWidth = 214;
  static const double panelPadding = 5;
  static const double panelRadius = 11;
  static const double rowHeight = 25;
  static const double rowRadius = 6;
  static const double rowGap = 1;
  static const double markWidth = 13;
  static const double columnGap = 8;

  /// A submenu overhangs its parent row by the panel's own padding, so the
  /// first child sits level with the row that opened it.
  static const double submenuOverhang = panelPadding;
  static const double submenuGap = 4;
  static const double submenuMinWidth = 168;
  static const Duration submenuFade = Duration(milliseconds: 120);

  /// Grace period before a submenu closes, so the pointer can cross the gap
  /// between the row and the panel it opened without losing it.
  static const Duration submenuLinger = Duration(milliseconds: 260);
}

/// The reference's four foreground steps, mapped onto Hyprbaric's palette.
///
/// Shared with the bar so a heading and the rows it opens are tinted from one
/// set of weights rather than two that drift apart.
///
/// The design names four weights where the bar's palette carries three, so the
/// dimmest two are derived rather than invented: a menu's accelerators and
/// carets sit a step below its labels, and a row the application has disabled
/// sits below everything.
abstract final class GlobalMenuInk {
  /// Labels the pointer is on, and open headings.
  static const Color bright = HyprColors.text;

  /// Menu rows at rest.
  static const Color label = HyprColors.textMuted;

  /// Headings at rest, and accelerators the pointer is on.
  static const Color quiet = HyprColors.textFaint;

  /// Accelerators, carets, and group captions at rest.
  static Color get faint => HyprColors.textFaint.withValues(alpha: 0.62);

  /// Rows the application will not let you use.
  static Color get disabled => HyprColors.textFaint.withValues(alpha: 0.42);

  /// The tint an open heading takes: near-white, barely coloured.
  static Color get openHeading =>
      Color.lerp(HyprColors.text, HyprColors.accent, 0.14)!;
}

/// One open heading: its rows, and any submenu flying out beside them.
///
/// The submenu is laid out beside the panel rather than floated over it. The
/// layer-shell input region is built from this widget's rendered size, so a
/// panel drawn outside those bounds would be visible but not clickable.
class GlobalMenuSectionPanel extends ConsumerStatefulWidget {
  const GlobalMenuSectionPanel({
    required this.section,
    required this.onActivated,
    super.key,
  });

  final GlobalMenuSectionId section;
  final VoidCallback onActivated;

  @override
  ConsumerState<GlobalMenuSectionPanel> createState() =>
      _GlobalMenuSectionPanelState();
}

class _GlobalMenuSectionPanelState
    extends ConsumerState<GlobalMenuSectionPanel> {
  GlobalMenuSectionId? _openSubmenu;
  double _submenuOffset = 0;
  Timer? _linger;

  @override
  void dispose() {
    _linger?.cancel();
    super.dispose();
  }

  void _openSub(GlobalMenuSectionId section, double offset) {
    _linger?.cancel();
    if (_openSubmenu == section) {
      return;
    }

    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(GlobalMenuIntent.openSection(section));
    setState(() {
      _openSubmenu = section;
      _submenuOffset = offset;
    });
  }

  void _closeSubAfterLinger() {
    _linger?.cancel();
    _linger = Timer(_Menu.submenuLinger, () {
      if (mounted) {
        setState(() => _openSubmenu = null);
      }
    });
  }

  void _closeSubNow() {
    _linger?.cancel();
    if (_openSubmenu != null) {
      setState(() => _openSubmenu = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final GlobalMenuSectionId? submenu = _openSubmenu;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        MouseRegion(
          onExit: (_) => _closeSubAfterLinger(),
          child: _MenuPanel(
            minWidth: _Menu.panelMinWidth,
            child: _MenuRows(
              section: widget.section,
              openSubmenu: submenu,
              onActivated: widget.onActivated,
              onSubmenuHovered: _openSub,
              onLeafHovered: _closeSubNow,
            ),
          ),
        ),
        if (submenu != null) ...<Widget>[
          const SizedBox(width: _Menu.submenuGap),
          Padding(
            padding: EdgeInsets.only(top: _submenuOffset),
            child: MouseRegion(
              onEnter: (_) => _linger?.cancel(),
              onExit: (_) => _closeSubAfterLinger(),
              child: TweenAnimationBuilder<double>(
                key: ValueKey<GlobalMenuSectionId>(submenu),
                tween: Tween<double>(begin: 0, end: 1),
                duration: _Menu.submenuFade,
                curve: Curves.easeOut,
                builder: (BuildContext context, double t, Widget? child) {
                  return Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(-3 * (1 - t), 0),
                      child: child,
                    ),
                  );
                },
                child: _MenuPanel(
                  minWidth: _Menu.submenuMinWidth,
                  child: _MenuRows(
                    section: submenu,
                    openSubmenu: null,
                    onActivated: widget.onActivated,
                    // One level of flyout is as far as the bar goes; deeper
                    // rows still activate, they just do not fan out further.
                    onSubmenuHovered: null,
                    onLeafHovered: () {},
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({required this.minWidth, required this.child});

  final double minWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return HyprPopoverPanel(
      borderRadius: BorderRadius.circular(_Menu.panelRadius),
      // The reference sets a floor and no ceiling: a menu is as wide as its
      // longest row. The ceiling here only stops a pathological label from
      // taking the screen, and rows ellipsize rather than wrap if one does.
      constraints: BoxConstraints(minWidth: minWidth, maxWidth: 420),
      padding: const EdgeInsets.all(_Menu.panelPadding),
      child: child,
    );
  }
}

/// The rows of one menu, or the reason there are none.
class _MenuRows extends ConsumerWidget {
  const _MenuRows({
    required this.section,
    required this.openSubmenu,
    required this.onActivated,
    required this.onSubmenuHovered,
    required this.onLeafHovered,
  });

  final GlobalMenuSectionId section;
  final GlobalMenuSectionId? openSubmenu;
  final VoidCallback onActivated;
  final void Function(GlobalMenuSectionId section, double offset)?
  onSubmenuHovered;
  final VoidCallback onLeafHovered;

  /// How tall a row of this kind stands, so a submenu can be placed against
  /// the row that opened it without waiting for a layout pass to measure it.
  static double _extentOf(GlobalMenuItemKind kind) => switch (kind) {
    GlobalMenuItemKindSeparator() => _MenuSeparator.extent,
    GlobalMenuItemKindGroup() => _MenuGroup.extent,
    _ => _Menu.rowHeight,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GlobalMenuSectionStatus? status = ref
        .watch(globalMenuSectionProvider(section))
        .asData
        ?.value;

    if (status == null) {
      return const _MenuNotice(label: 'Loading…');
    }
    if (status.items.isEmpty) {
      return const _MenuNotice(label: 'No entries');
    }

    // Rows are stacked at a known height, so a submenu's vertical offset is
    // arithmetic rather than a measurement taken after layout.
    double offset = _Menu.panelPadding;
    final List<Widget> rows = <Widget>[];
    for (final GlobalMenuItem item in status.items) {
      final double top = offset;
      offset += _extentOf(item.kind) + _Menu.rowGap;

      rows.add(
        switch (item.kind) {
          GlobalMenuItemKindSeparator() => const _MenuSeparator(),
          GlobalMenuItemKindGroup() => _MenuGroup(label: item.label),
          _ => _MenuRow(
            item: item,
            open: openSubmenu != null && item.submenu == openSubmenu,
            onActivated: onActivated,
            onHovered: () {
              final GlobalMenuSectionId? submenu = item.submenu;
              if (submenu == null || onSubmenuHovered == null) {
                onLeafHovered();
                return;
              }
              onSubmenuHovered!(submenu, top - _Menu.submenuOverhang);
            },
          ),
        },
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: _Menu.rowGap,
      children: rows,
    );
  }
}

class _MenuNotice extends StatelessWidget {
  const _MenuNotice({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _Menu.rowHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _Menu.columnGap),
          child: Text(
            label,
            style: HyprTypography.globalMenuItem.copyWith(
              color: HyprColors.textFaint,
            ),
          ),
        ),
      ),
    );
  }
}

/// A divider between groups of rows.
///
/// Two lines, not one: a dark rule with a barely-lit line under it, which is
/// what makes the panel read as a cut surface rather than a drawn border.
class _MenuSeparator extends StatelessWidget {
  const _MenuSeparator();

  static const double extent = 9;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: SizedBox(
        height: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x8C000000),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.05),
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: const SizedBox(width: double.infinity),
        ),
      ),
    );
  }
}

/// A caption naming the rows beneath it.
class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.label});

  final String label;

  static const double extent = 21;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: extent,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.only(
            left: _Menu.columnGap,
            right: _Menu.columnGap,
            bottom: 2,
          ),
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            style: HyprTypography.globalMenuGroup.copyWith(color: GlobalMenuInk.faint),
          ),
        ),
      ),
    );
  }
}

/// One row: mark, label, then accelerator or submenu caret.
///
/// The mark column keeps its width whether or not the row is checked, so
/// labels stay aligned down the menu.
class _MenuRow extends ConsumerStatefulWidget {
  const _MenuRow({
    required this.item,
    required this.open,
    required this.onActivated,
    required this.onHovered,
  });

  final GlobalMenuItem item;
  final bool open;
  final VoidCallback onActivated;
  final VoidCallback onHovered;

  @override
  ConsumerState<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends ConsumerState<_MenuRow> {
  bool _hovered = false;

  bool get _actionable =>
      widget.item.enabled &&
      (widget.item.activation != null || widget.item.submenu != null);

  void _activate() {
    final GlobalMenuItemId? activation = widget.item.activation;
    if (activation == null) {
      return;
    }

    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(GlobalMenuIntent.activate(activation));
    widget.onActivated();
  }

  @override
  Widget build(BuildContext context) {
    final bool lit = (_hovered || widget.open) && _actionable;
    final Color labelColor = !_actionable
        ? GlobalMenuInk.disabled
        : lit
        ? GlobalMenuInk.bright
        : GlobalMenuInk.label;
    final Color metaColor = !_actionable
        ? GlobalMenuInk.disabled
        : lit
        ? GlobalMenuInk.quiet
        : GlobalMenuInk.faint;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) {
        setState(() => _hovered = true);
        widget.onHovered();
      },
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _actionable ? _activate : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          height: _Menu.rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: _Menu.columnGap),
          decoration: BoxDecoration(
            color: lit ? HyprColors.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(_Menu.rowRadius),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: _Menu.markWidth,
                child: _MenuMark(kind: widget.item.kind),
              ),
              const SizedBox(width: _Menu.columnGap),
              Expanded(
                child: Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HyprTypography.globalMenuItem.copyWith(
                    color: labelColor,
                  ),
                ),
              ),
              const SizedBox(width: _Menu.columnGap),
              _MenuRowTrailing(item: widget.item, color: metaColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// The checkmark or radio dot, drawn in the accent so state reads at a glance.
class _MenuMark extends StatelessWidget {
  const _MenuMark({required this.kind});

  final GlobalMenuItemKind kind;

  @override
  Widget build(BuildContext context) {
    final String? glyph = switch (kind) {
      GlobalMenuItemKindCheckmark(:final bool checked) => checked ? '✓' : null,
      GlobalMenuItemKindRadio(:final bool selected) => selected ? '•' : null,
      _ => null,
    };

    if (glyph == null) {
      return const SizedBox.shrink();
    }

    return Text(
      glyph,
      textAlign: TextAlign.center,
      style: HyprTypography.globalMenuItem.copyWith(
        fontSize: 11,
        height: 1,
        color: HyprColors.accent,
      ),
    );
  }
}

class _MenuRowTrailing extends StatelessWidget {
  const _MenuRowTrailing({required this.item, required this.color});

  final GlobalMenuItem item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (item.submenu != null) {
      return Text(
        '›',
        style: HyprTypography.globalMenuItem.copyWith(
          fontSize: 12,
          height: 1,
          color: color,
        ),
      );
    }

    final String? shortcut = item.shortcut;
    if (shortcut == null) {
      return const SizedBox.shrink();
    }

    return Text(
      shortcut,
      style: HyprTypography.globalMenuKey.copyWith(color: color),
    );
  }
}
