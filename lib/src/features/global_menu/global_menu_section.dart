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
  static const double panelPadding = 6;
  static const double panelRadius = 11;
  static const double rowHeight = 28;
  static const double rowRadius = 6;
  static const double rowGap = 2;
  static const double markWidth = 14;
  static const double columnGap = 10;

  /// Space between a label and its accelerator, from the mock's grid gutter.
  static const double keyGap = 24;

  /// A submenu overhangs its parent row by the panel's own padding, so the
  /// first child sits level with the row that opened it.
  static const double submenuOverhang = panelPadding;
  static const double submenuGap = 4;
  static const double submenuMinWidth = 168;
  static const Duration submenuFade = Duration(milliseconds: 120);

  /// A little more of the layer-shell blur than the shared popover floor.
  /// Scales both the dark fill and the top-to-bottom wash; 1.0 is the tray.
  static const double glass = 0.84;

  /// Grace period before a submenu closes, so the pointer can cross the gap
  /// between the row and the panel it opened without losing it.
  static const Duration submenuLinger = Duration(milliseconds: 260);
}

/// Foreground steps shared with the bar and the other popovers.
///
/// A heading and the rows it opens have to sit on the same greys as the app
/// title and a tray menu. A private oklch ladder next to those looks like a
/// different product, and on a translucent panel the dimmer steps fall away.
abstract final class GlobalMenuInk {
  /// Labels the pointer is on, and hovered headings.
  static const Color bright = HyprColors.text;

  /// Menu rows at rest: a step above [HyprColors.textMuted], so labels read
  /// on the frost without jumping to hover-white.
  static Color get label =>
      Color.lerp(HyprColors.textMuted, HyprColors.text, 0.55)!;

  /// Headings at rest. Same grey as the rest of the bar's labels.
  static const Color quiet = HyprColors.textMuted;

  /// Accelerators, carets, and group captions at rest.
  static const Color faint = HyprColors.textFaint;

  /// Rows the application will not let you use.
  static Color get disabled => HyprColors.textFaint.withValues(alpha: 0.42);

  /// The tint an open heading takes: near-white, barely coloured.
  static Color get openHeading =>
      Color.lerp(HyprColors.text, HyprColors.accent, 0.14)!;

  /// Checkmarks, in the same accent the rest of the bar uses for state.
  static const Color mark = HyprColors.accent;

  /// The wash under a hovered or open row.
  static const Color rowHover = HyprColors.hover;
}

/// Formats a D-BusMenu chord the way the v6 mock prints one.
///
/// Rust stores `Ctrl+Shift+N`. The mock prints `Ctrl ⇧ N`: space-separated,
/// with a glyph for every modifier that has one. Super becomes Mod, which is
/// how the rest of the mock talks about Hyprland's logo key.
String formatGlobalMenuAccelerator(String chord) {
  if (!chord.contains('+')) {
    return _acceleratorToken(chord);
  }

  late final String modifiers;
  late final String key;
  if (chord.endsWith('++') && chord.length > 2) {
    modifiers = chord.substring(0, chord.length - 2);
    key = '+';
  } else {
    final int last = chord.lastIndexOf('+');
    modifiers = chord.substring(0, last);
    key = chord.substring(last + 1);
  }

  return <String>[
    ...modifiers
        .split('+')
        .where((String part) => part.isNotEmpty)
        .map(_acceleratorToken),
    _acceleratorToken(key),
  ].join(' ');
}

String _acceleratorToken(String token) {
  if (token.isEmpty) {
    return '+';
  }

  return switch (token) {
    'Shift' => '⇧',
    'Alt' => '⌥',
    'Super' || 'Meta' => 'Mod',
    'Control' => 'Ctrl',
    'Up' || 'ArrowUp' => '↑',
    'Down' || 'ArrowDown' => '↓',
    'Left' || 'ArrowLeft' => '←',
    'Right' || 'ArrowRight' => '→',
    'Tab' => '⇥',
    'Return' || 'Enter' || 'ISO_Enter' => '⏎',
    'space' || 'Space' => 'Space',
    _ => token,
  };
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
  GlobalMenuSectionId? _filledSubmenu;
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

    final GlobalMenuSectionId? previous = _openSubmenu;
    if (previous != null) {
      _dismiss(previous);
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
        _dismiss(_openSubmenu ?? _filledSubmenu);
        setState(() {
          _openSubmenu = null;
          _filledSubmenu = null;
        });
      }
    });
  }

  void _closeSubNow() {
    _linger?.cancel();
    final GlobalMenuSectionId? closing = _openSubmenu ?? _filledSubmenu;
    if (closing != null) {
      _dismiss(closing);
      setState(() {
        _openSubmenu = null;
        _filledSubmenu = null;
      });
    }
  }

  void _dismiss(GlobalMenuSectionId? section) {
    if (section == null) {
      return;
    }
    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(GlobalMenuIntent.dismiss(section));
  }

  @override
  Widget build(BuildContext context) {
    final GlobalMenuSectionId? pending = _openSubmenu;
    GlobalMenuSectionId? flyout = pending == null ? null : _filledSubmenu;
    if (pending != null) {
      final GlobalMenuSectionStatus? status = ref
          .watch(globalMenuSectionProvider(pending))
          .value;
      if (status != null && status.items.isNotEmpty) {
        flyout = pending;
        _filledSubmenu = pending;
      }
    }

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
              openSubmenu: pending,
              onActivated: widget.onActivated,
              onSubmenuHovered: _openSub,
              onLeafHovered: _closeSubNow,
            ),
          ),
        ),
        if (flyout != null) ...<Widget>[
          const SizedBox(width: _Menu.submenuGap),
          Padding(
            padding: EdgeInsets.only(top: _submenuOffset),
            child: MouseRegion(
              onEnter: (_) => _linger?.cancel(),
              onExit: (_) => _closeSubAfterLinger(),
              child: TweenAnimationBuilder<double>(
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
                    section: flyout,
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
    // Same chassis as the tray, audio, and network popovers, with a slightly
    // thinner dark floor so the frost behind the menu can still read.
    final Color floor = context.hyprPalette.surfaceStrong;
    return HyprPopoverPanel(
      borderRadius: BorderRadius.circular(_Menu.panelRadius),
      color: floor.withValues(alpha: floor.a * _Menu.glass),
      overlayOpacity: _Menu.glass,
      // The mock's menu is a grid: a 214px floor, labels in the middle
      // column, accelerators on the right. The ceiling is the original 360px
      // so a heading and its flyout still sit on a typical panel together;
      // rows ellipsize rather than wrap once they hit it.
      constraints: BoxConstraints(minWidth: minWidth, maxWidth: 360),
      padding: const EdgeInsets.all(_Menu.panelPadding),
      child: SizedBox(width: double.infinity, child: child),
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
    final AsyncValue<GlobalMenuSectionStatus> asyncStatus = ref.watch(
      globalMenuSectionProvider(section),
    );
    // Keep the last rows while a sibling flyout reloads the stream. Showing
    // the one-line loading notice instead is what made the open menu jump.
    final GlobalMenuSectionStatus? status = asyncStatus.value;

    if (status == null) {
      return const _MenuNotice(label: 'Loading…');
    }
    if (status.items.isEmpty) {
      return const _MenuNotice(label: 'No entries');
    }

    final List<GlobalMenuItem> items = _withoutEmptyDividers(status.items);
    if (items.isEmpty) {
      return const _MenuNotice(label: 'No entries');
    }

    // Rows are stacked at a known height, so a submenu's vertical offset is
    // arithmetic rather than a measurement taken after layout.
    double offset = _Menu.panelPadding;
    final List<Widget> rows = <Widget>[];
    for (final GlobalMenuItem item in items) {
      final double top = offset;
      offset += _extentOf(item.kind) + _Menu.rowGap;

      rows.add(switch (item.kind) {
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
      });
    }

    // Rows stretch to the panel so accelerators sit on one right-hand column,
    // the way the mock's grid does. Long labels ellipsize once the panel is
    // as wide as it is allowed to be.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: _Menu.rowGap,
      children: rows,
    );
  }
}

/// Drops separators that do not sit between two real rows.
List<GlobalMenuItem> _withoutEmptyDividers(List<GlobalMenuItem> items) {
  final List<GlobalMenuItem> rows = <GlobalMenuItem>[];
  for (final GlobalMenuItem item in items) {
    if (item.kind is GlobalMenuItemKindSeparator &&
        (rows.isEmpty || rows.last.kind is GlobalMenuItemKindSeparator)) {
      continue;
    }
    rows.add(item);
  }
  while (rows.isNotEmpty && rows.last.kind is GlobalMenuItemKindSeparator) {
    rows.removeLast();
  }
  return rows;
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
              color: GlobalMenuInk.faint,
            ),
            textHeightBehavior: HyprTypography.uiLeading,
          ),
        ),
      ),
    );
  }
}

/// A divider between groups of rows.
///
/// A cut in the panel, not a drawn rule: a dark recess with a barely-lit
/// hairline under it, inset from the corners so it does not run into the
/// radius. A full-width bright stroke is what made these look like a
/// different product from the rest of the bar.
class _MenuSeparator extends StatelessWidget {
  const _MenuSeparator();

  static const Key paintKey = Key('global-menu-separator');
  static const double extent = 10;

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: paintKey,
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: _Menu.columnGap),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ColoredBox(
            color: Color(0x66000000),
            child: SizedBox(height: 1, width: double.infinity),
          ),
          ColoredBox(
            color: HyprColors.popupStroke,
            child: SizedBox(height: 1, width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// A caption naming the rows beneath it.
class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.label});

  final String label;

  /// Padding to the bottom of a caption, matching the mock's group row.
  static const double extent = 24;

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
            bottom: 4,
          ),
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            textHeightBehavior: HyprTypography.uiLeading,
            style: HyprTypography.globalMenuGroup.copyWith(
              color: GlobalMenuInk.faint,
            ),
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

  bool get _toggle => switch (widget.item.kind) {
    GlobalMenuItemKindCheckmark() || GlobalMenuItemKindRadio() => true,
    _ => false,
  };

  void _activate() {
    final GlobalMenuItemId? activation = widget.item.activation;
    if (activation == null) {
      return;
    }

    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(GlobalMenuIntent.activate(activation));
    if (!_toggle) {
      widget.onActivated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool lit = (_hovered || widget.open) && _actionable;
    final Color labelColor = !_actionable
        ? GlobalMenuInk.disabled
        : lit
        ? GlobalMenuInk.bright
        : GlobalMenuInk.label;
    // Keys step up to heading-grey on hover. Chevrons step up to the row
    // label, which is what makes an open submenu read as held.
    final Color trailingColor = !_actionable
        ? GlobalMenuInk.disabled
        : lit
        ? (widget.item.submenu != null
              ? GlobalMenuInk.label
              : GlobalMenuInk.quiet)
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
            color: lit ? GlobalMenuInk.rowHover : Colors.transparent,
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
                  textHeightBehavior: HyprTypography.uiLeading,
                  style: HyprTypography.globalMenuItem.copyWith(
                    color: labelColor,
                  ),
                ),
              ),
              const SizedBox(width: _Menu.keyGap),
              _MenuRowTrailing(item: widget.item, color: trailingColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// The checkmark, drawn in the accent so state reads at a glance.
class _MenuMark extends StatelessWidget {
  const _MenuMark({required this.kind});

  final GlobalMenuItemKind kind;

  @override
  Widget build(BuildContext context) {
    // The mock draws every selected state as a checkmark, including the
    // mutually exclusive theme rows that are radios underneath.
    final bool marked = switch (kind) {
      GlobalMenuItemKindCheckmark(:final bool checked) => checked,
      GlobalMenuItemKindRadio(:final bool selected) => selected,
      _ => false,
    };

    if (!marked) {
      return const SizedBox.shrink();
    }

    return Text(
      '✓',
      textAlign: TextAlign.center,
      textHeightBehavior: HyprTypography.uiLeading,
      style: HyprTypography.globalMenuItem.copyWith(
        fontSize: 11,
        color: GlobalMenuInk.mark,
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
        textHeightBehavior: HyprTypography.uiLeading,
        style: HyprTypography.globalMenuItem.copyWith(
          fontSize: 12,
          color: color,
        ),
      );
    }

    final String? shortcut = item.shortcut;
    if (shortcut == null) {
      return const SizedBox.shrink();
    }

    return Text(
      formatGlobalMenuAccelerator(shortcut),
      textHeightBehavior: HyprTypography.uiLeading,
      style: HyprTypography.globalMenuKey.copyWith(color: color),
    );
  }
}
