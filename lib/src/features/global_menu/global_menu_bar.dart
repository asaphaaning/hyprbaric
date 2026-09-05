import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../../state/rust_signals/compositor.dart';
import '../../state/rust_signals/global_menu.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/layer_shell_dropdown.dart';
import '../rust_commands.dart';
import 'global_menu_section.dart';

/// Compact macOS-style menu bar for the focused application's menu.
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

  @override
  void initState() {
    super.initState();
    _focusedWindowSubscription = ref
        .listenManual<AsyncValue<FocusedWindowStatus>>(
          focusedWindowStatusProvider,
          (_, AsyncValue<FocusedWindowStatus> next) {
            if (next.hasValue) {
              _requestMenu();
            }
          },
          fireImmediately: true,
        );
  }

  void _requestMenu() {
    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(const GlobalMenuIntent.refresh());
  }

  /// Opens one heading, closing whichever other heading was open.
  ///
  /// The rows are asked for on every open rather than cached: an application
  /// decides what a menu contains at the moment it is shown, so a remembered
  /// answer would go stale as soon as its state changed.
  void _toggleSection(GlobalMenuSectionId section) {
    final LayerShellDropdownController controller = _controllerFor(section);
    if (controller.isOpen) {
      controller.close();
      return;
    }

    for (final openController in _sectionControllers.values) {
      if (!identical(openController, controller)) {
        openController.close();
      }
    }

    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(GlobalMenuIntent.openSection(section));
    controller.open();
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
  void _retainSections(Iterable<GlobalMenuSectionId> sections) {
    final Set<GlobalMenuSectionId> live = sections.toSet();
    _sectionControllers.removeWhere(
      (section, _) => !live.contains(section),
    );
  }

  @override
  void dispose() {
    _focusedWindowSubscription.close();
    _sectionControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GlobalMenuStatus? status = ref
        .watch(globalMenuStatusProvider)
        .asData
        ?.value;
    final sections = status?.sections ?? const <GlobalMenuSection>[];
    _retainSections(sections.map((section) => section.id));

    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 36,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final section in sections)
              _GlobalMenuSectionButton(
                section: section,
                controller: _controllerFor(section.id),
                onToggle: _toggleSection,
              ),
          ],
        ),
      ),
    );
  }
}

class _GlobalMenuSectionButton extends StatelessWidget {
  const _GlobalMenuSectionButton({
    required this.section,
    required this.controller,
    required this.onToggle,
  });

  final GlobalMenuSection section;
  final LayerShellDropdownController controller;
  final ValueChanged<GlobalMenuSectionId> onToggle;

  @override
  Widget build(BuildContext context) {
    return LayerShellDropdown(
      controller: controller,
      menuWidth: 320,
      verticalGap: 6,
      horizontalAnchor: LayerShellDropdownAnchor.center,
      menuRadius: HyprRadii.popoverRadius,
      buttonBuilder:
          (
            BuildContext context,
            LayerShellDropdownController controller, {
            required bool isOpen,
          }) {
            return Semantics(
              button: true,
              label: section.label,
              child: InkWell(
                onTap: section.enabled ? () => onToggle(section.id) : null,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: Text(
                    section.label,
                    style: HyprTypography.barMono.copyWith(
                      color: section.enabled
                          ? (isOpen ? HyprColors.text : HyprColors.textMuted)
                          : HyprColors.textFaint,
                    ),
                  ),
                ),
              ),
            );
          },
      menuBuilder:
          (BuildContext context, LayerShellDropdownController controller) {
            return GlobalMenuSectionPanel(
              section: section.id,
              onActivated: controller.close,
            );
          },
    );
  }
}
