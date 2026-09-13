import 'package:flutter/material.dart';

import '../hypr_surface.dart';

/// The recessed selector material shared by the mixer and settings.
abstract final class HyprSelectStyle {
  static const fill = Color(0xAA090C12);
  static const border = Color(0x22333742);
  static const radius = BorderRadius.all(Radius.circular(7));
  static const menuFill = Color(0xFA15181F);
  static const menuRadius = BorderRadius.all(Radius.circular(9));
}

/// A selector's current value, supporting label, and disclosure chevron.
///
/// Interaction belongs to the host: an audio picker or a typed dropdown.
class HyprSelectContent extends StatelessWidget {
  const HyprSelectContent({
    super.key,
    required this.title,
    required this.subtitle,
    this.expanded = false,
    this.enabled = true,
    this.padding = const EdgeInsets.fromLTRB(14, 7, 8, 7),
  });

  /// Current selection, elided when space is limited.
  final String title;

  /// Supporting context below the current selection.
  final String subtitle;

  /// Whether the owning picker is showing its choices.
  final bool expanded;

  /// Whether the current value should use the active foreground.
  final bool enabled;

  /// Insets inside the selector face.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HyprInstrumentText.meta.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: enabled
                      ? HyprInstrumentColors.text
                      : HyprInstrumentColors.secondary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HyprInstrumentText.meta.copyWith(
                  fontSize: 9.5,
                  letterSpacing: .3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Icon(
          expanded
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
          size: 21,
          color: HyprInstrumentColors.secondary,
        ),
      ],
    ),
  );
}

/// A finite, typed choice using the mixer's recessed two-line selector face.
///
/// Flutter owns keyboard navigation, dismissal, and the scrollable option menu.
class HyprDropdown<T> extends StatelessWidget {
  const HyprDropdown({
    super.key,
    required this.value,
    required this.values,
    required this.label,
    required this.format,
    required this.onChanged,
  });

  /// Current selection; must occur exactly once in [values].
  final T value;

  /// The available choices in display order.
  final List<T> values;

  /// Purpose of the selector, shown below its current value.
  final String label;

  /// Projects a domain value into its visible label.
  final String Function(T) format;

  /// Receives a selected value; null makes the field read-only.
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const ShapeDecoration(
      color: HyprSelectStyle.fill,
      shape: RoundedSuperellipseBorder(
        borderRadius: HyprSelectStyle.radius,
        side: BorderSide(color: HyprSelectStyle.border),
      ),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        icon: const SizedBox.shrink(),
        dropdownColor: HyprSelectStyle.menuFill,
        borderRadius: HyprSelectStyle.menuRadius,
        menuMaxHeight: 240,
        style: HyprInstrumentText.body.copyWith(fontSize: 12),
        selectedItemBuilder: (context) => [
          for (final option in values)
            HyprSelectContent(
              title: format(option),
              subtitle: label,
              enabled: onChanged != null,
            ),
        ],
        items: [
          for (final option in values)
            DropdownMenuItem<T>(
              value: option,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Expanded(child: Text(format(option))),
                    if (option == value)
                      const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: HyprInstrumentColors.secondary,
                      ),
                  ],
                ),
              ),
            ),
        ],
        onChanged: onChanged == null
            ? null
            : (next) {
                if (next != null) onChanged!(next);
              },
      ),
    ),
  );
}
