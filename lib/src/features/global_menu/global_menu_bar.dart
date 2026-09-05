import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../../state/rust_signals/compositor.dart';
import '../../state/rust_signals/global_menu.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/layer_shell_dropdown.dart';
import '../rust_commands.dart';
import 'global_menu_section.dart';

/// Geometry of the menu bar itself, from the v6 reference.
abstract final class _Bar {
  static const double titleHeight = 20;
  static const double titleRadius = 5;
  static const double titlePadding = 8;
  static const double titleGap = 1;
  static const double rowPadding = 2;
  static const double dropGap = 6;
  static const Duration tint = Duration(milliseconds: 110);
}

/// The focused application's menu headings, macOS-style.
class GlobalMenuBar extends ConsumerStatefulWidget {
  const GlobalMenuBar({super.key});

  @override
  ConsumerState<GlobalMenuBar> createState() => _GlobalMenuBarState();
}

class _GlobalMenuBarState extends ConsumerState<GlobalMenuBar> {
  late final ProviderSubscription<AsyncValue<FocusedWindowStatus>>
  _focusedWindowSubscription;
  final Map<GlobalMenuSectionId, LayerShellDropdownController>
  _sectionControllers = <GlobalMenuSectionId, LayerShellDropdownController>{};
  final FocusNode _focusNode = FocusNode(
    debugLabel: 'GlobalMenuBar',
    skipTraversal: true,
  );
  List<GlobalMenuSection> _sections = const <GlobalMenuSection>[];
  GlobalMenuSectionId? _open;
  String? _focusedApp;
  bool _awaitingFirstMenu = true;

  @override
  void initState() {
    super.initState();
    _focusedWindowSubscription = ref
        .listenManual<AsyncValue<FocusedWindowStatus>>(
          focusedWindowStatusProvider,
          (_, AsyncValue<FocusedWindowStatus> next) {
            final FocusedWindowStatus? status = next.asData?.value;
            if (status != null) {
              _focusChanged(status);
            }
          },
          fireImmediately: true,
        );
  }

  /// Re-reads the menu when the focused application changes.
  ///
  /// The focused-window signal also carries the title, which changes as often
  /// as a document is edited or a tab is switched. Re-reading the whole menu
  /// on each of those would put a subprocess and a D-Bus round trip behind
  /// every keystroke, and would replace the headings mid-interaction.
  void _focusChanged(FocusedWindowStatus status) {
    if (status.appName == _focusedApp && !_awaitingFirstMenu) {
      return;
    }

    _focusedApp = status.appName;
    _awaitingFirstMenu = true;
    _close();
    _requestMenu();
  }

  void _requestMenu() {
    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(const GlobalMenuIntent.refresh());
  }

  /// Opens one heading, closing whichever other heading was open.
  ///
  /// Rows are asked for on every open rather than cached: an application
  /// decides what a menu contains at the moment it is shown, so a remembered
  /// answer would go stale as soon as its state changed.
  void _open_(GlobalMenuSectionId section) {
    for (final MapEntry<GlobalMenuSectionId, LayerShellDropdownController> entry
        in _sectionControllers.entries) {
      if (entry.key != section) {
        entry.value.close();
      }
    }

    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(GlobalMenuIntent.openSection(section));
    _controllerFor(section).open();
    setState(() => _open = section);
    _focusNode.requestFocus();
  }

  void _close() {
    for (final controller in _sectionControllers.values) {
      controller.close();
    }
    if (_open != null) {
      setState(() => _open = null);
    }
  }

  void _toggle(GlobalMenuSectionId section) {
    if (_open == section) {
      _close();
      return;
    }
    _open_(section);
  }

  /// Moves along the bar while a menu is open, the way a menu bar behaves.
  void _step(int delta) {
    final GlobalMenuSectionId? open = _open;
    if (open == null || _sections.isEmpty) {
      return;
    }

    final int index = _sections.indexWhere((section) => section.id == open);
    if (index < 0) {
      return;
    }

    final int count = _sections.length;
    for (int hop = 1; hop <= count; hop++) {
      final GlobalMenuSection candidate =
          _sections[(index + delta * hop + count * count) % count];
      if (candidate.enabled) {
        _open_(candidate.id);
        return;
      }
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_open == null || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        _close();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _step(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _step(-1);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  LayerShellDropdownController _controllerFor(GlobalMenuSectionId section) =>
      _sectionControllers.putIfAbsent(
        section,
        LayerShellDropdownController.new,
      );

  /// Drops controllers for headings the focused window no longer exports.
  ///
  /// Focus moves between applications constantly, and every application brings
  /// its own headings, so retaining them would grow this map for the lifetime
  /// of the bar. A controller holds nothing but a link to its dropdown, which
  /// detaches itself when the dropdown leaves the tree, so forgetting it here
  /// is the whole of the cleanup.
  void _retainSections(List<GlobalMenuSection> sections) {
    _sections = sections;
    final Set<GlobalMenuSectionId> live = sections
        .map((section) => section.id)
        .toSet();
    _sectionControllers.removeWhere((section, _) => !live.contains(section));
    if (_open != null && !live.contains(_open)) {
      _open = null;
    }
  }

  /// The headings to show for the application that is focused now.
  ///
  /// A read can fail for reasons that have nothing to do with the window,
  /// such as the menu being asked for while focus is in flight. Answering an
  /// empty read by clearing the bar makes the centre flick between the menu
  /// and the window title, so an empty answer only takes effect once, when the
  /// focused application changes.
  List<GlobalMenuSection> _headings(GlobalMenuStatus? status) {
    if (status == null) {
      return _sections;
    }

    if (status.sections.isNotEmpty) {
      _awaitingFirstMenu = false;
      return status.sections;
    }

    if (_awaitingFirstMenu) {
      _awaitingFirstMenu = false;
      return const <GlobalMenuSection>[];
    }

    return _sections;
  }

  @override
  void dispose() {
    _focusedWindowSubscription.close();
    _focusNode.dispose();
    _sectionControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GlobalMenuStatus? status = ref
        .watch(globalMenuStatusProvider)
        .asData
        ?.value;
    final List<GlobalMenuSection> sections = _headings(status);
    _retainSections(sections);

    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      child: SizedBox(
        height: 36,
        // Centred while the headings fit, scrollable once they do not. A bare
        // scroll view fills its viewport and lays its row out from the left,
        // which put the menu somewhere other than where the window title sits
        // and made the centre of the bar jump as the two swapped.
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: _Bar.rowPadding),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: math.max(
                    0,
                    constraints.maxWidth - _Bar.rowPadding * 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    for (final GlobalMenuSection section in sections)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _Bar.titleGap / 2,
                        ),
                        child: _GlobalMenuTitle(
                          section: section,
                          controller: _controllerFor(section.id),
                          anyOpen: _open != null,
                          onToggle: _toggle,
                          onHoverOpen: _open_,
                          onDismissed: () {
                            if (_open == section.id) {
                              setState(() => _open = null);
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One heading, and the menu it opens beneath itself.
class _GlobalMenuTitle extends StatefulWidget {
  const _GlobalMenuTitle({
    required this.section,
    required this.controller,
    required this.anyOpen,
    required this.onToggle,
    required this.onHoverOpen,
    required this.onDismissed,
  });

  final GlobalMenuSection section;
  final LayerShellDropdownController controller;
  final bool anyOpen;
  final ValueChanged<GlobalMenuSectionId> onToggle;
  final ValueChanged<GlobalMenuSectionId> onHoverOpen;
  final VoidCallback onDismissed;

  @override
  State<_GlobalMenuTitle> createState() => _GlobalMenuTitleState();
}

class _GlobalMenuTitleState extends State<_GlobalMenuTitle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return LayerShellDropdown(
      controller: widget.controller,
      verticalGap: _Bar.dropGap,
      horizontalAnchor: LayerShellDropdownAnchor.left,
      menuRadius: BorderRadius.circular(11),
      menuOffset: const Offset(-5, 0),
      onClosed: widget.onDismissed,
      buttonBuilder:
          (
            BuildContext context,
            LayerShellDropdownController controller, {
            required bool isOpen,
          }) {
            final Color color = !widget.section.enabled
                ? HyprColors.textFaint
                : isOpen
                ? Color.lerp(HyprColors.text, HyprColors.accent, 0.3)!
                : _hovered
                ? HyprColors.text
                : HyprColors.textMuted;

            return Semantics(
              button: true,
              label: widget.section.label,
              child: MouseRegion(
                cursor: SystemMouseCursors.basic,
                onEnter: (_) {
                  setState(() => _hovered = true);
                  // While a menu is open the bar tracks the pointer, so
                  // sliding along the headings walks the menus.
                  if (widget.anyOpen && !isOpen && widget.section.enabled) {
                    widget.onHoverOpen(widget.section.id);
                  }
                },
                onExit: (_) => setState(() => _hovered = false),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.section.enabled
                      ? () => widget.onToggle(widget.section.id)
                      : null,
                  child: AnimatedContainer(
                    duration: _Bar.tint,
                    curve: Curves.easeOut,
                    height: _Bar.titleHeight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: _Bar.titlePadding,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isOpen ? HyprColors.hover : Colors.transparent,
                      borderRadius: BorderRadius.circular(_Bar.titleRadius),
                    ),
                    child: Text(
                      widget.section.label,
                      maxLines: 1,
                      style: HyprTypography.globalMenuTitle.copyWith(
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
      menuBuilder:
          (BuildContext context, LayerShellDropdownController controller) {
            return GlobalMenuSectionPanel(
              section: widget.section.id,
              onActivated: controller.close,
            );
          },
    );
  }
}
