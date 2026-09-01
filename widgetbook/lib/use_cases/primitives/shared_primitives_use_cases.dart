import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';

@UseCase(
  name: 'Variants',
  type: HyprCommandButton,
  path: '[Building blocks]/Controls',
)
Widget buildCommandButtonVariants(BuildContext context) {
  return CatalogFrame(
    width: 420,
    child: Wrap(
      spacing: HyprSpacing.md,
      runSpacing: HyprSpacing.md,
      children: <Widget>[
        HyprCommandButton(label: 'Cancel', onPressed: _noop),
        HyprCommandButton(
          label: 'Continue',
          variant: HyprCommandButtonVariant.primary,
          icon: const Icon(Icons.arrow_forward_rounded, size: 14),
          onPressed: _noop,
        ),
        HyprCommandButton(
          label: 'End session',
          variant: HyprCommandButtonVariant.danger,
          onPressed: _noop,
        ),
        const HyprCommandButton(label: 'Unavailable', onPressed: null),
      ],
    ),
  );
}

@UseCase(
  name: 'Message states',
  type: HyprEmptyState,
  path: '[Building blocks]/Feedback',
)
Widget buildEmptyStateMessages(BuildContext context) {
  return CatalogFrame(
    width: 360,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        HyprEmptyState(message: 'Nothing waiting right now.', symbol: 'EMPTY'),
        SizedBox(height: HyprSpacing.xl),
        HyprEmptyState(
          message: 'Network service is unavailable.',
          symbol: 'OFFLINE',
          color: HyprColors.fill,
          borderColor: HyprColors.borderSoft,
        ),
      ],
    ),
  );
}

@UseCase(
  name: 'Frame treatments',
  type: HyprGlassFrame,
  path: '[Building blocks]/Surfaces',
)
Widget buildGlassFrameTreatments(BuildContext context) {
  return CatalogFrame(
    width: 420,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        HyprGlassFrame(
          fill: HyprColors.fill,
          vignette: true,
          child: _FrameLabel(label: 'FRAME'),
        ),
        const SizedBox(height: HyprSpacing.lg),
        HyprGlassFrame(
          fill: HyprColors.fillStrong,
          sheen: HyprGlassSheen.tile,
          glow: HyprColors.accentSoft,
          shadows: HyprGlassFrame.tileShadows,
          child: const _FrameLabel(label: 'CONNECTED TILE'),
        ),
      ],
    ),
  );
}

@UseCase(
  name: 'Identity states',
  type: HyprGlyphBadge,
  path: '[Building blocks]/Feedback',
)
Widget buildGlyphBadgeStates(BuildContext context) {
  return CatalogFrame(
    width: 360,
    child: const Wrap(
      spacing: HyprSpacing.lg,
      runSpacing: HyprSpacing.lg,
      children: <Widget>[
        HyprGlyphBadge(name: 'Zed'),
        HyprGlyphBadge(name: 'Hyprbaric Settings', dimension: 28),
        HyprGlyphBadge(name: 'Discord Canary', maxCharacters: 1),
        HyprGlyphBadge(name: '…'),
      ],
    ),
  );
}

@UseCase(
  name: 'On and off',
  type: HyprHardwareToggle,
  path: '[Building blocks]/Controls',
)
Widget buildHardwareToggleStates(BuildContext context) {
  return CatalogFrame(
    width: 280,
    child: const Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        HyprHardwareToggle(value: false),
        HyprHardwareToggle(value: true),
      ],
    ),
  );
}

@UseCase(
  name: 'Interactive states',
  type: HyprHoverPlate,
  path: '[Building blocks]/Controls',
)
Widget buildHoverPlateStates(BuildContext context) {
  return CatalogFrame(
    width: 360,
    child: Row(
      children: <Widget>[
        Expanded(
          child: HyprHoverPlate(
            semanticLabel: 'Hover plate',
            onPressed: _noop,
            padding: const EdgeInsets.all(HyprSpacing.lg),
            builder: (BuildContext context, {required bool hovered}) => Text(
              hovered ? 'HOVERED' : 'DEFAULT',
              textAlign: TextAlign.center,
              style: HyprTypography.compactMonoStrong,
            ),
          ),
        ),
        const SizedBox(width: HyprSpacing.md),
        const Expanded(
          child: HyprHoverPlate(
            selected: true,
            onPressed: _noop,
            padding: EdgeInsets.all(HyprSpacing.lg),
            builder: _selectedPlateLabel,
          ),
        ),
      ],
    ),
  );
}

Widget _selectedPlateLabel(BuildContext context, {required bool hovered}) {
  return Text(
    'SELECTED',
    textAlign: TextAlign.center,
    style: HyprTypography.compactMonoStrong,
  );
}

@UseCase(
  name: 'Action states',
  type: HyprIconTile,
  path: '[Building blocks]/Controls',
)
Widget buildIconTileStates(BuildContext context) {
  return CatalogFrame(
    width: 320,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _iconTile(active: false, icon: Icons.wifi_rounded),
        _iconTile(active: true, icon: Icons.nights_stay_rounded),
        _iconTile(active: false, enabled: false, icon: Icons.block_rounded),
      ],
    ),
  );
}

Widget _iconTile({
  required bool active,
  required IconData icon,
  bool enabled = true,
}) {
  return HyprIconTile(
    active: active,
    enabled: enabled,
    semanticLabel: 'Icon tile',
    onPressed: enabled ? _noop : null,
    padding: const EdgeInsets.all(HyprSpacing.lg),
    builder:
        (
          BuildContext context, {
          required bool hovered,
          required bool pressed,
        }) => Icon(
          icon,
          color: active || hovered
              ? HyprColors.accentSoft
              : HyprColors.textMuted,
        ),
  );
}

@UseCase(
  name: 'Tag styles',
  type: HyprInlineTag,
  path: '[Building blocks]/Feedback',
)
Widget buildInlineTagStyles(BuildContext context) {
  return CatalogFrame(
    width: 380,
    child: Wrap(
      spacing: HyprSpacing.lg,
      runSpacing: HyprSpacing.lg,
      children: const <Widget>[
        HyprInlineTag(label: 'Default'),
        HyprInlineTag(
          label: 'Live',
          color: Color(0x1F55A7FF),
          borderColor: Color(0x6655A7FF),
          textColor: HyprColors.accentSoft,
        ),
        HyprBracketedTag(label: 'WPA2', accent: HyprColors.accentSoft),
      ],
    ),
  );
}

@UseCase(
  name: 'Bracketed tag',
  type: HyprBracketedTag,
  path: '[Building blocks]/Feedback',
)
Widget buildBracketedTag(BuildContext context) {
  return CatalogFrame(
    width: 260,
    child: const Center(
      child: HyprBracketedTag(label: 'WPA2', accent: HyprColors.accentSoft),
    ),
  );
}

@UseCase(
  name: 'Interaction states',
  type: HyprInteractionRegion,
  path: '[Building blocks]/Controls',
)
Widget buildInteractionRegionStates(BuildContext context) {
  return CatalogFrame(
    width: 320,
    child: HyprInteractionRegion(
      semanticLabel: 'Interaction region',
      onPressed: _noop,
      builder: (BuildContext context, HyprInteractionState state) {
        final Color color = state.pressed
            ? HyprColors.accent
            : state.hovered
            ? HyprColors.hoverStrong
            : HyprColors.fill;
        return AnimatedContainer(
          duration: HyprMotion.hover,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: HyprColors.border),
            borderRadius: HyprRadii.rowRadius,
          ),
          child: Text(
            state.pressed
                ? 'PRESSED'
                : state.hovered
                ? 'HOVERED'
                : 'READY',
            style: HyprTypography.compactMonoStrong,
          ),
        );
      },
    ),
  );
}

@UseCase(
  name: 'Selection states',
  type: HyprInteractiveTile,
  path: '[Building blocks]/Controls',
)
Widget buildInteractiveTileStates(BuildContext context) {
  return CatalogFrame(
    width: 380,
    child: Row(
      children: <Widget>[
        Expanded(child: _interactiveTile(label: 'NORMAL')),
        const SizedBox(width: HyprSpacing.md),
        Expanded(child: _interactiveTile(label: 'ACTIVE', selected: true)),
      ],
    ),
  );
}

Widget _interactiveTile({required String label, bool selected = false}) {
  return HyprInteractiveTile(
    selected: selected,
    semanticLabel: label,
    onPressed: _noop,
    height: 42,
    builder: (BuildContext context, HyprInteractiveTileState state) {
      return Center(
        child: Text(label, style: HyprTypography.compactMonoStrong),
      );
    },
  );
}

@UseCase(
  name: 'Metric alignment',
  type: HyprMetricCard,
  path: '[Building blocks]/Feedback',
)
Widget buildMetricCardStates(BuildContext context) {
  return CatalogFrame(
    width: 340,
    child: const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        HyprMetricCard(
          label: 'UPSTREAM',
          value: '388.32',
          unit: ' MB/s',
          detail: '1.2 GB SENT',
        ),
        HyprMetricCard(
          label: 'LATENCY',
          value: '10',
          unit: ' ms',
          detail: 'ROUND TRIP',
          alignEnd: true,
        ),
      ],
    ),
  );
}

@UseCase(
  name: 'Header and dividers',
  type: HyprPanelHeader,
  path: '[Building blocks]/Rows',
)
Widget buildPanelChrome(BuildContext context) {
  return CatalogFrame(
    width: 420,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HyprPanelHeader(
          title: 'Connected network',
          subtitle: 'Hyprnet_5G · WPA2',
          leading: const Icon(Icons.wifi_rounded),
          actionLabel: 'Refresh',
          onAction: _noop,
          trailing: const HyprInlineTag(label: 'Live'),
        ),
        const HyprSectionBreak(before: HyprSpacing.xl, after: HyprSpacing.xl),
        const HyprSectionLabel('Interface details', trailingLine: true),
        const SizedBox(height: HyprSpacing.lg),
        const HyprPanelDivider(),
      ],
    ),
  );
}

@UseCase(
  name: 'Divider treatments',
  type: HyprPanelDivider,
  path: '[Building blocks]/Rows',
)
Widget buildPanelDividers(BuildContext context) {
  return CatalogFrame(
    width: 420,
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Above the divider'),
        SizedBox(height: HyprSpacing.md),
        HyprPanelDivider(),
        SizedBox(height: HyprSpacing.md),
        Text('Below the divider'),
      ],
    ),
  );
}

@UseCase(
  name: 'Section break',
  type: HyprSectionBreak,
  path: '[Building blocks]/Rows',
)
Widget buildSectionBreak(BuildContext context) {
  return CatalogFrame(
    width: 420,
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('First section'),
        HyprSectionBreak(before: HyprSpacing.lg, after: HyprSpacing.lg),
        Text('Second section'),
      ],
    ),
  );
}

@UseCase(
  name: 'Trailing line',
  type: HyprSectionLabel,
  path: '[Building blocks]/Rows',
)
Widget buildSectionLabel(BuildContext context) {
  return CatalogFrame(
    width: 420,
    child: const HyprSectionLabel('Interfaces', trailingLine: true),
  );
}

@UseCase(
  name: 'Settings row',
  type: HyprPlateButton,
  path: '[Building blocks]/Rows',
)
Widget buildPlateButton(BuildContext context) {
  return CatalogFrame(
    width: 420,
    child: HyprPlateButton(
      label: 'BAR SETTINGS',
      icon: Icons.settings_outlined,
      semanticLabel: 'Open bar settings',
      labelColor: HyprColors.textMuted,
      iconColor: HyprColors.textMuted,
      trailingColor: HyprColors.textFaint,
      onPressed: _noop,
    ),
  );
}

@UseCase(
  name: 'Popover frame',
  type: HyprPopoverPanel,
  path: '[Building blocks]/Surfaces',
)
Widget buildPopoverPanel(BuildContext context) {
  return CatalogCanvas(
    child: HyprPopoverPanel(
      borderRadius: HyprRadii.panelRadius,
      constraints: const BoxConstraints.tightFor(width: 340),
      padding: const EdgeInsets.all(HyprSpacing.loose),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          HyprSectionLabel('Popover panel'),
          SizedBox(height: HyprSpacing.md),
          Text('Shared chrome for floating bar surfaces.'),
        ],
      ),
    ),
  );
}

@UseCase(
  name: 'Field states',
  type: HyprTextFieldChrome,
  path: '[Building blocks]/Controls',
)
Widget buildTextFieldChromeStates(BuildContext context) {
  return CatalogFrame(
    width: 420,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        HyprTextFieldChrome(
          child: Text('Enter password', style: HyprTypography.popRow),
        ),
        SizedBox(height: HyprSpacing.md),
        HyprTextFieldChrome(
          enabled: false,
          child: Text('Network unavailable', style: HyprTypography.popRow),
        ),
      ],
    ),
  );
}

class _FrameLabel extends StatelessWidget {
  const _FrameLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Center(
        child: Text(label, style: HyprTypography.compactMonoStrong),
      ),
    );
  }
}

void _noop() {}
