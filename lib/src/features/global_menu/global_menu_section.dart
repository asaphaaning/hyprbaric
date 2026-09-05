import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../../state/rust_signals/global_menu.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import '../rust_commands.dart';

/// The rows of one open heading.
///
/// Rows arrive after the heading opens, so this shows the application's own
/// wording for an empty or failed read rather than an empty panel.
class GlobalMenuSectionPanel extends ConsumerWidget {
  const GlobalMenuSectionPanel({
    required this.section,
    required this.onActivated,
    super.key,
  });

  final GlobalMenuSectionId section;
  final VoidCallback onActivated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GlobalMenuSectionStatus? status = ref
        .watch(globalMenuSectionProvider(section))
        .asData
        ?.value;

    return HyprPopoverPanel(
      borderRadius: HyprRadii.popoverRadius,
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
      padding: const EdgeInsets.all(6),
      child: switch (status) {
        null => const _GlobalMenuNotice(label: 'Loading…'),
        final GlobalMenuSectionStatus status when status.items.isEmpty =>
          const _GlobalMenuNotice(label: 'No entries'),
        final GlobalMenuSectionStatus status => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final item in status.items)
              _GlobalMenuRow(item: item, onActivated: onActivated),
          ],
        ),
      },
    );
  }
}

class _GlobalMenuNotice extends StatelessWidget {
  const _GlobalMenuNotice({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Text(
        label,
        style: HyprTypography.popRow.copyWith(color: HyprColors.textFaint),
      ),
    );
  }
}

class _GlobalMenuRow extends ConsumerWidget {
  const _GlobalMenuRow({required this.item, required this.onActivated});

  final GlobalMenuItem item;
  final VoidCallback onActivated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.kind is GlobalMenuItemKindSeparator) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: HyprColors.border.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(99),
          ),
          child: const SizedBox(height: 1, width: double.infinity),
        ),
      );
    }

    final GlobalMenuItemId? activation = item.activation;

    return HyprActionRow(
      title: item.label,
      leading: _leadingMark(item.kind),
      trailing: _trailing(),
      enabled: item.enabled && activation != null,
      onPressed: item.enabled && activation != null
          ? () {
              ref
                  .read(rustCommandDispatcherProvider)
                  .dispatch(GlobalMenuIntent.activate(activation));
              onActivated();
            }
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      borderRadius: BorderRadius.circular(6),
      titleStyle: HyprTypography.popRow,
    );
  }

  /// Trailing text is the accelerator, or a caret for a nested menu.
  ///
  /// Nested menus do not open yet, so the caret is a truthful hint that the
  /// row leads somewhere rather than a control.
  Widget? _trailing() {
    final String? label = item.submenu != null ? '›' : item.shortcut;
    if (label == null) {
      return null;
    }

    return Text(
      label,
      style: HyprTypography.popRow.copyWith(color: HyprColors.textFaint),
    );
  }

  Widget? _leadingMark(GlobalMenuItemKind kind) {
    final bool marked = switch (kind) {
      GlobalMenuItemKindCheckmark(:final bool checked) => checked,
      GlobalMenuItemKindRadio(:final bool selected) => selected,
      _ => false,
    };

    if (kind is GlobalMenuItemKindStandard ||
        kind is GlobalMenuItemKindSeparator) {
      return null;
    }

    return SizedBox(
      width: 12,
      child: marked
          ? Text(
              kind is GlobalMenuItemKindRadio ? '•' : '✓',
              style: HyprTypography.popRow.copyWith(color: HyprColors.text),
            )
          : null,
    );
  }
}
