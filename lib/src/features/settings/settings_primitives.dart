import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';

/// The tonal bays in the settings instrument chassis.
enum SettingsTone { graphite, slate, well }

/// An edge-to-edge instrument bay; the containing chassis clips its corners.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.child,
    this.title,
    this.hovered = false,
    this.borderColor,
    this.tone = SettingsTone.graphite,
  });

  final Widget child;
  final String? title;
  final bool hovered;
  final Color? borderColor;
  final SettingsTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      SettingsTone.graphite => const [Color(0x70303844), Color(0x50191D26)],
      SettingsTone.slate => const [Color(0xA0404655), Color(0x70303644)],
      SettingsTone.well => const [Color(0x90080B12), Color(0x700E121A)],
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        border: Border(
          top: BorderSide(color: borderColor ?? const Color(0x12FFFFFF)),
          bottom: BorderSide(color: borderColor ?? const Color(0x65000000)),
        ),
      ),
      child: ColoredBox(
        color: hovered ? HyprConsoleColors.tileHover : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                const SizedBox(height: 20),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
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

/// A tabular readout that uses the shared recessed well primitive.
class SettingsValue extends StatelessWidget {
  const SettingsValue(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => HyprWell(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    color: HyprConsoleColors.seam,
    borderRadius: BorderRadius.circular(7),
    borderColor: const Color(0x384F596F),
    child: Text(
      label,
      style: HyprInstrumentText.body.copyWith(
        color: HyprInstrumentColors.text,
        fontFeatures: HyprTypography.tabularNumbers,
      ),
    ),
  );
}

/// Raised console keys with warm indicators for the selected choice.
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
      child: HyprWell(
        padding: const EdgeInsets.all(3),
        borderRadius: BorderRadius.circular(10),
        color: HyprConsoleColors.seam,
        child: HyprInteractionRegion(
          semanticLabel: label,
          onPressed: onPressed,
          builder: (context, state) => Transform.translate(
            offset: Offset(0, state.pressed ? 1 : 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: state.pressed
                      ? const [Color(0xFF13161D), Color(0xFF1C2029)]
                      : [
                          state.hovered
                              ? const Color(0xFF3A4050)
                              : const Color(0xFF303440),
                          const Color(0xFF171B23),
                        ],
                ),
                border: Border.all(
                  color: selected
                      ? const Color(0x8069532C)
                      : const Color(0x404B5264),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x70000000),
                    offset: Offset(0, 2),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 4,
                      height: 12,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: selected
                            ? HyprAmberToggle.amber
                            : const Color(0xFF50586E),
                        boxShadow: selected
                            ? const [
                                BoxShadow(
                                  color: Color(0x88FFAF32),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: HyprInstrumentText.body.copyWith(
                        color: selected
                            ? HyprInstrumentColors.text
                            : HyprInstrumentColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
        return Column(children: [first, second]);
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: first),
            const SizedBox(width: 1),
            Expanded(child: second),
          ],
        ),
      );
    },
  );
}
