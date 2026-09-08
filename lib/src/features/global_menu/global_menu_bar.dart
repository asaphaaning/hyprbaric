import 'dart:async';

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
  static const double titleHeight = 22;
  static const double titlePadding = 10;
  static const double titleGap = 2;
  static const double rowPadding = 2;
  static const double dropGap = 8;
  static const Duration tint = Duration(milliseconds: 110);
}

/// The focused application's menu headings, macOS-style.
class GlobalMenuBar extends ConsumerStatefulWidget {
  const GlobalMenuBar({super.key, this.showLeadingDivider = true});

  /// Whether to draw the rule separating the menu from what precedes it.
  ///
  /// The menu draws its own divider because only it knows whether the focused
  /// window exports any headings; a neighbour drawing one would leave a rule
  /// hanging beside nothing every time a window has no menu.
  final bool showLeadingDivider;

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
  String? _focusedWindow;
  GlobalMenuSession? _session;
  bool _awaitingFirstMenu = true;
  Timer? _retry;
  int _retryIndex = 0;

  /// Backoff while the companion is still joining the focused window.
  ///
  /// Opening an application publishes its menu after the focus signal. A
  /// single read then is often empty. Keep asking for a few seconds rather
  /// than treating that empty as the window having no menu.
  static const List<int> _retryDelaysMs = <int>[80, 160, 320, 640, 1280, 2500];

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

  /// Re-reads the menu when the focused window changes.
  ///
  /// The focused-window signal also carries the title, which changes as often
  /// as a document is edited or a tab is switched. Re-reading the whole menu
  /// on each of those would put a subprocess and a D-Bus round trip behind
  /// every keystroke, and would replace the headings mid-interaction.
  void _focusChanged(FocusedWindowStatus status) {
    if (status.address == _focusedWindow) {
      return;
    }

    _focusedWindow = status.address;
    _awaitingFirstMenu = true;
    _retryIndex = 0;
    _close();
    setState(() {
      _session = null;
      _sections = const [];
    });
    _requestMenu();
    _scheduleRetry();
  }

  void _requestMenu() {
    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(GlobalMenuIntent.refresh(window: _focusedWindow));
  }

  void _scheduleRetry() {
    _retry?.cancel();
    if (!_awaitingFirstMenu) {
      return;
    }
    if (_retryIndex >= _retryDelaysMs.length) {
      _awaitingFirstMenu = false;
      return;
    }

    _retry = Timer(Duration(milliseconds: _retryDelaysMs[_retryIndex]), () {
      if (!mounted || !_awaitingFirstMenu) {
        return;
      }
      _retryIndex++;
      _requestMenu();
      _scheduleRetry();
    });
  }

  void _menuArrived() {
    _retry?.cancel();
    _retry = null;
    _awaitingFirstMenu = false;
  }

  /// Opens one heading, closing whichever other heading was open.
  ///
  /// The request always goes out. GTK rows may already be snapshotted; a
  /// D-BusMenu heading is announced on every open because Firefox rebuilds
  /// native identifiers after the previous click.
  void _open_(GlobalMenuSectionId section) {
    final session = _session;
    if (session == null) return;
    for (final MapEntry<GlobalMenuSectionId, LayerShellDropdownController> entry
        in _sectionControllers.entries) {
      if (entry.key != section) {
        entry.value.close();
      }
    }

    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(
          GlobalMenuIntent.openSection(
            GlobalMenuAddress(session: session, section: section),
          ),
        );
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
  ///
  /// Firefox also rebuilds native identifiers after a menu is announced. The
  /// heading is still File; only its id changed. Keep the open dropdown and
  /// its controller attached to the new id so the panel does not vanish.
  void _retainSections(List<GlobalMenuSection> sections) {
    final GlobalMenuSectionId? open = _open;
    if (open != null) {
      String? label;
      for (final GlobalMenuSection section in _sections) {
        if (section.id == open) {
          label = section.label;
          break;
        }
      }
      if (label != null) {
        for (final GlobalMenuSection section in sections) {
          if (section.label == label && section.id != open) {
            final LayerShellDropdownController? controller = _sectionControllers
                .remove(open);
            if (controller != null) {
              _sectionControllers[section.id] = controller;
            }
            _open = section.id;
            break;
          }
        }
      }
    }

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
  /// such as the menu being asked for while the companion is still joining
  /// it. Answering that empty read by giving up makes the bar stay blank
  /// until the next focus change. Keep showing nothing while we retry, and
  /// only treat a later empty as "this window has no menu" after retries
  /// settle. An empty read after headings have already arrived must not
  /// clear them: that is what made the centre flick between the menu and
  /// the window title.
  List<GlobalMenuSection> _headings(GlobalMenuStatus? status) {
    if (status != null && status.window != _focusedWindow) {
      return _sections;
    }
    if (status == null) {
      return _sections;
    }

    if (status.sections.isNotEmpty) {
      _session = status.session;
      _menuArrived();
      return status.sections;
    }

    if (status.session == _session &&
        _sections.any(
          (section) => section.id is! GlobalMenuSectionIdDbusMenu,
        )) {
      return const <GlobalMenuSection>[];
    }

    if (_awaitingFirstMenu) {
      return const <GlobalMenuSection>[];
    }

    return _sections;
  }

  @override
  void dispose() {
    _retry?.cancel();
    _focusedWindowSubscription.close();
    _focusNode.dispose();
    _sectionControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Map<GlobalMenuAddress, GlobalMenuSectionStatus>>(
      globalMenuSectionCacheProvider,
      (_, _) {},
    );
    ref.listen(globalMenuIntegrationProvider, (previous, next) {
      if (next.value is GlobalMenuIntegrationStatusReady &&
          previous?.value is! GlobalMenuIntegrationStatusReady) {
        _awaitingFirstMenu = true;
        _retryIndex = 0;
        _requestMenu();
        _scheduleRetry();
      }
    });
    ref.listen(globalMenuStatusProvider, (previous, next) {
      if (_session != null &&
          next.value?.session != _session &&
          next.value?.window == _focusedWindow) {
        _close();
      }
    });
    final GlobalMenuStatus? status = ref
        .watch(globalMenuStatusProvider)
        .asData
        ?.value;
    final List<GlobalMenuSection> sections = _headings(status);
    _retainSections(sections);

    final session = _session;
    if (sections.isEmpty || session == null) {
      return const SizedBox.shrink();
    }

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (widget.showLeadingDivider)
            const HyprDivider(
              height: 16,
              margin: EdgeInsets.symmetric(horizontal: 8),
            ),
          Flexible(
            child: SizedBox(
              height: 36,
              // Scrolls rather than pushing its neighbours when an application
              // exports more headings than the bar has room for.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: _Bar.rowPadding,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final GlobalMenuSection section in sections)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _Bar.titleGap / 2,
                        ),
                        child: _GlobalMenuTitle(
                          section: section,
                          session: session,
                          controller: _controllerFor(section.id),
                          anyOpen: _open != null,
                          onToggle: _toggle,
                          onHoverOpen: _open_,
                          onDismissed: () {
                            ref
                                .read(rustCommandDispatcherProvider)
                                .dispatch(
                                  GlobalMenuIntent.dismiss(
                                    GlobalMenuAddress(
                                      session: session,
                                      section: section.id,
                                    ),
                                  ),
                                );
                            ref
                                .read(globalMenuSectionCacheProvider.notifier)
                                .forget(
                                  GlobalMenuAddress(
                                    session: session,
                                    section: section.id,
                                  ),
                                );
                            if (_open == section.id) {
                              setState(() => _open = null);
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One heading, and the menu it opens beneath itself.
class _GlobalMenuTitle extends StatefulWidget {
  const _GlobalMenuTitle({
    required this.section,
    required this.session,
    required this.controller,
    required this.anyOpen,
    required this.onToggle,
    required this.onHoverOpen,
    required this.onDismissed,
  });

  final GlobalMenuSection section;
  final GlobalMenuSession session;
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
                ? GlobalMenuInk.disabled
                : isOpen
                ? GlobalMenuInk.openHeading
                : _hovered
                ? GlobalMenuInk.bright
                : GlobalMenuInk.quiet;

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
                // Menus open on press, not release, the way a menu bar has
                // always behaved: the button goes down and the menu is already
                // there to be dragged through.
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: widget.section.enabled
                      ? (_) => widget.onToggle(widget.section.id)
                      : null,
                  child: SizedBox(
                    height: _Bar.titleHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _Bar.titlePadding,
                      ),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: _Bar.tint,
                          curve: Curves.easeOut,
                          style: HyprTypography.globalMenuTitle.copyWith(
                            color: color,
                          ),
                          child: Text(
                            widget.section.label,
                            maxLines: 1,
                            textHeightBehavior: HyprTypography.uiLeading,
                          ),
                        ),
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
              session: widget.session,
              onActivated: controller.close,
            );
          },
    );
  }
}
