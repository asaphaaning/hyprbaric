import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../../state/rust_signals/compositor.dart';
import '../../state/rust_signals/global_menu.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/layer_shell_dropdown.dart';
import '../../widgets/primitives/primitives.dart';
import '../rust_commands.dart';

/// Compact macOS-style menu bar for the focused application's AppMenu.
class GlobalMenuBar extends ConsumerStatefulWidget {
  const GlobalMenuBar({super.key});

  @override
  ConsumerState<GlobalMenuBar> createState() => _GlobalMenuBarState();
}

class _GlobalMenuBarState extends ConsumerState<GlobalMenuBar> {
  late final ProviderSubscription<AsyncValue<FocusedWindowStatus>>
  _focusedWindowSubscription;
  final Map<int, LayerShellDropdownController> _sectionControllers =
      <int, LayerShellDropdownController>{};

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

  void _toggleSection(LayerShellDropdownController controller) {
    if (controller.isOpen) {
      controller.close();
      return;
    }

    for (final openController in _sectionControllers.values) {
      if (!identical(openController, controller)) {
        openController.close();
      }
    }
    controller.open();
  }

  @override
  void dispose() {
    _focusedWindowSubscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GlobalMenuStatus? status = ref
        .watch(globalMenuStatusProvider)
        .asData
        ?.value;
    final sections = status?.sections ?? const <GlobalMenuSection>[];

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
                controller: _sectionControllers.putIfAbsent(
                  section.id,
                  LayerShellDropdownController.new,
                ),
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
  final ValueChanged<LayerShellDropdownController> onToggle;

  bool get _hasActionableItems => section.items.any((item) => !item.separator);

  bool get _canOpen => section.enabled && _hasActionableItems;

  @override
  Widget build(BuildContext context) {
    return LayerShellDropdown(
      controller: controller,
      menuWidth: 280,
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
                onTap: _canOpen ? () => onToggle(controller) : null,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: Text(
                    section.label,
                    style: HyprTypography.barMono.copyWith(
                      color: _canOpen
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
            return HyprPopoverPanel(
              borderRadius: HyprRadii.popoverRadius,
              constraints: const BoxConstraints(minWidth: 240, maxWidth: 280),
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final item in section.items)
                    if (item.separator)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: HyprColors.border.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const SizedBox(
                            height: 1,
                            width: double.infinity,
                          ),
                        ),
                      )
                    else
                      HyprActionRow(
                        title: item.label,
                        enabled: item.enabled,
                        onPressed: item.enabled ? controller.close : null,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        titleStyle: HyprTypography.popRow,
                      ),
                ],
              ),
            );
          },
    );
  }
}
