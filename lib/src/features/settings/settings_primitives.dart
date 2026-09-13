import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';

/// A settings group built from the same glass material as the bar's panels.
class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.child,
    this.title,
    this.hovered = false,
    this.borderColor,
  });

  final Widget child;
  final String? title;
  final bool hovered;

  /// Optional semantic outline, such as a shortcut conflict.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(hovered ? 0x802A303C : 0x60242A35),
          const Color(0x38151820),
        ],
      ),
      border: Border.all(
        color:
            borderColor ??
            HyprInstrumentColors.border.withValues(alpha: hovered ? .55 : .24),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title case final title?) ...[
            Text(
              title.toUpperCase(),
              style: HyprInstrumentText.title.copyWith(
                fontSize: 11,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    ),
  );
}

/// The label, explanation, and optional control shared by settings rows.
class SettingsField extends StatelessWidget {
  const SettingsField({
    super.key,
    required this.label,
    required this.subtitle,
    this.trailing,
    this.child,
  });

  final String label;
  final String subtitle;
  final Widget? trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: HyprInstrumentText.body.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: HyprInstrumentText.meta),
              ],
            ),
          ),
          if (trailing case final trailing?) ...[
            const SizedBox(width: 16),
            trailing,
          ],
        ],
      ),
      if (child case final child?) ...[const SizedBox(height: 14), child],
    ],
  );
}

/// A tabular readout that uses the shared recessed badge primitive.
class SettingsValue extends StatelessWidget {
  const SettingsValue(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => HyprBadge.text(
    label: label,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    color: const Color(0x55080B10),
    borderColor: HyprInstrumentColors.border.withValues(alpha: .3),
    borderRadius: BorderRadius.circular(8),
    textColor: HyprInstrumentColors.secondary,
    style: HyprInstrumentText.body.copyWith(
      fontFeatures: HyprTypography.tabularNumbers,
    ),
  );
}

/// Lavender selection material, shared by position, monitor, and workspace choices.
class SettingsChoice extends StatelessWidget {
  const SettingsChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: IntrinsicWidth(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFD2CFFF), Color(0xFFAAA8E9)],
                )
              : null,
        ),
        child: HyprCommandButton(
          label: label,
          onPressed: onPressed,
          pressedScale: 1,
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          borderRadius: BorderRadius.circular(9),
          color: selected ? Colors.transparent : const Color(0x44080B10),
          hoverColor: const Color(0x227E86B4),
          borderColor: HyprInstrumentColors.border.withValues(
            alpha: selected ? .7 : .24,
          ),
          foregroundColor: selected
              ? const Color(0xFF171825)
              : HyprInstrumentColors.secondary,
          hoverForegroundColor: selected
              ? const Color(0xFF171825)
              : HyprInstrumentColors.text,
          textStyle: HyprInstrumentText.body,
        ),
      ),
    ),
  );
}

/// Side-by-side groups when there is room, stacked at compact panel widths.
class SettingsColumns extends StatelessWidget {
  const SettingsColumns({super.key, required this.first, required this.second});
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 640) {
        return Column(children: [first, const SizedBox(height: 16), second]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: 16),
          Expanded(child: second),
        ],
      );
    },
  );
}
