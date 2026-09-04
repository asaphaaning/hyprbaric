import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import '../../widgets/primitives/primitives.dart';
import 'setup_guide_state.dart';
import 'setup_guide_style.dart';

/// The copy, controls, progress, and navigation pane of the v6 guide.
class SetupGuideControls extends StatelessWidget {
  const SetupGuideControls({
    super.key,
    required this.step,
    required this.appearance,
    required this.workspaces,
    required this.accentPresets,
    required this.onStepSelected,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
    required this.onOpacityPreview,
    required this.onOpacityCommitted,
    required this.onAccentPreview,
    required this.onAccentCommitted,
    required this.onPositionChanged,
    required this.onWorkspaceStyleChanged,
  });

  final SetupStep step;
  final AppearanceStatus appearance;
  final WorkspaceSettingsStatus workspaces;
  final List<int> accentPresets;
  final ValueChanged<SetupStep> onStepSelected;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final ValueChanged<int> onOpacityPreview;
  final ValueChanged<int> onOpacityCommitted;
  final ValueChanged<int> onAccentPreview;
  final ValueChanged<int> onAccentCommitted;
  final ValueChanged<AppearancePosition> onPositionChanged;
  final ValueChanged<WorkspaceIndicatorStyle> onWorkspaceStyleChanged;

  @override
  Widget build(BuildContext context) {
    final int index = SetupStep.sequence.indexOf(step);
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 26, 40, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${(index + 1).toString().padLeft(2, '0')} — ${step.label.toUpperCase()}',
            style: setupMono(size: 9.5, spacing: 1.6),
          ),
          const SizedBox(height: 18),
          Text(_title(step), style: SetupGuideTypography.stepTitle),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 365),
            child: Text(
              _subtitle(step),
              style: SetupGuideTypography.stepSubtitle,
            ),
          ),
          const SizedBox(height: 26),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: const Cubic(.2, .9, .25, 1),
              child: SingleChildScrollView(
                key: ValueKey<SetupStep>(step),
                padding: const EdgeInsets.only(right: 4, bottom: 2),
                child: _controls(context),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 22),
            child: Row(
              children: <Widget>[
                _Progress(active: step, onSelected: onStepSelected),
                const Spacer(),
                SetupGuideButton(
                  label: index == 0 ? 'Skip' : 'Back',
                  onPressed: index == 0 ? onSkip : onBack,
                ),
                const SizedBox(width: 17),
                SetupGuideButton(
                  label: index == SetupStep.sequence.length - 1
                      ? 'Finish'
                      : index == 0
                      ? 'Get started'
                      : 'Continue',
                  kind: SetupGuideButtonKind.primary,
                  onPressed: onNext,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls(BuildContext context) => switch (step) {
    SetupStep.welcome => const _FeatureList(),
    SetupStep.transparency => Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _ChoiceCard(
                title: 'Frosted glass',
                subtitle: 'Backdrop blur, translucent depth.',
                selected: appearance.opacity < 100,
                preview: const _BarSwatch(frosted: true),
                onPressed: () => onOpacityCommitted(77),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ChoiceCard(
                title: 'Flat matte',
                subtitle: 'No blur, opaque chassis.',
                selected: appearance.opacity == 100,
                preview: const _BarSwatch(frosted: false),
                onPressed: () => onOpacityCommitted(100),
              ),
            ),
          ],
        ),
        if (appearance.opacity < 100) ...<Widget>[
          const SizedBox(height: 18),
          _ControlWell(
            title: 'Background opacity',
            subtitle: 'How much wallpaper shows through.',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SetupGuideSlider(
                  value: appearance.opacity.toDouble(),
                  min: 20,
                  max: 100,
                  kind: SetupGuideSliderKind.amount,
                  onChanged: (double value) => onOpacityPreview(value.round()),
                  onChangeEnd: (double value) =>
                      onOpacityCommitted(value.round()),
                ),
                const SizedBox(width: 10),
                _Value('${appearance.opacity}%'),
              ],
            ),
          ),
        ],
      ],
    ),
    SetupStep.accent => Column(
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: accentPresets
                .map(
                  (int hue) => _HueSwatch(
                    hue: hue,
                    selected: appearance.accentHue == hue,
                    onPressed: () => onAccentCommitted(hue),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 18),
        _ControlWell(
          title: 'Fine tune',
          subtitle: 'Anywhere on the wheel.',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SetupGuideSlider(
                value: appearance.accentHue.toDouble(),
                min: 0,
                max: 359,
                kind: SetupGuideSliderKind.hue,
                onChanged: (double value) => onAccentPreview(value.round()),
                onChangeEnd: (double value) => onAccentCommitted(value.round()),
              ),
              const SizedBox(width: 10),
              _Value('${appearance.accentHue}°'),
            ],
          ),
        ),
      ],
    ),
    SetupStep.layout => Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _ChoiceCard(
                title: 'Top',
                subtitle: 'Classic panel placement.',
                selected: appearance.position == AppearancePosition.top,
                preview: const _BarSwatch(
                  frosted: true,
                  position: AppearancePosition.top,
                ),
                onPressed: () => onPositionChanged(AppearancePosition.top),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ChoiceCard(
                title: 'Bottom',
                subtitle: 'Out of the way of titlebars.',
                selected: appearance.position == AppearancePosition.bottom,
                preview: const _BarSwatch(
                  frosted: true,
                  position: AppearancePosition.bottom,
                ),
                onPressed: () => onPositionChanged(AppearancePosition.bottom),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ControlWell(
          title: 'Workspace indicators',
          subtitle: 'Occupied ones get a coloured dot.',
          trailing: _Segmented(
            options: <_SegmentOption>[
              _SegmentOption(
                label: 'I·II',
                selected:
                    workspaces.indicatorStyle == WorkspaceIndicatorStyle.roman,
                onPressed: () =>
                    onWorkspaceStyleChanged(WorkspaceIndicatorStyle.roman),
              ),
              _SegmentOption(
                label: '1·2',
                selected:
                    workspaces.indicatorStyle ==
                    WorkspaceIndicatorStyle.numeric,
                onPressed: () =>
                    onWorkspaceStyleChanged(WorkspaceIndicatorStyle.numeric),
              ),
            ],
          ),
        ),
      ],
    ),
  };
}

String _title(SetupStep step) => switch (step) {
  SetupStep.welcome => 'Welcome to\nHyprbaric',
  SetupStep.transparency => 'Frosted, or flat?',
  SetupStep.accent => 'Pick an accent',
  SetupStep.layout => 'Where should it live?',
};

String _subtitle(SetupStep step) => switch (step) {
  SetupStep.welcome =>
    'Three quick choices and your bar is dressed. Every one of them also lives in Bar settings, so nothing here is permanent.',
  SetupStep.transparency =>
    'Blur looks great but costs a little GPU. Flat matte is cheaper and stays crisp on low-power hardware.',
  SetupStep.accent =>
    'One hue drives glows, active states, meters, and highlights across the whole bar.',
  SetupStep.layout => 'Dock the bar, then choose how workspaces are labelled.',
};

class _FeatureList extends StatelessWidget {
  const _FeatureList();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        _Feature('Frosted glass or flat matte', 'your call'),
        SizedBox(height: 15),
        _Feature('One accent hue', 'drives every highlight'),
        SizedBox(height: 15),
        _Feature('Dock and label style', 'top or bottom'),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature(this.title, this.detail);

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 9,
          height: 1.5,
          decoration: BoxDecoration(
            color: context.setupGuideAccent.withValues(alpha: .7),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(text: title),
                TextSpan(
                  text: '  — $detail',
                  style: const TextStyle(color: SetupGuideColors.textFaint),
                ),
              ],
            ),
            style: SetupGuideTypography.summaryRow,
          ),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.preview,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final Widget preview;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.setupGuideAccent;
    return HyprInteractionRegion(
      semanticLabel: title,
      semanticToggled: selected,
      onPressed: onPressed,
      builder: (BuildContext context, HyprInteractionState state) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color.lerp(const Color(0xFF343740), accent, .20)!,
                      Color.lerp(const Color(0xFF292B33), accent, .14)!,
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      state.hovered
                          ? const Color(0xFF484A54)
                          : SetupGuideColors.faceTop,
                      state.hovered
                          ? const Color(0xFF353740)
                          : SetupGuideColors.faceBottom,
                    ],
                  ),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: .72)
                  : const Color(0x59000000),
              width: selected ? 2.5 : 1,
            ),
            boxShadow: <BoxShadow>[
              const BoxShadow(
                color: Color(0x17FFFFFF),
                offset: Offset(0, 1),
                blurStyle: BlurStyle.inner,
              ),
              const BoxShadow(
                color: Color(0x66000000),
                offset: Offset(0, -1),
                blurStyle: BlurStyle.inner,
              ),
              if (!selected)
                const BoxShadow(
                  color: Color(0xA6000000),
                  blurRadius: 14,
                  spreadRadius: -8,
                  offset: Offset(0, 6),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              preview,
              const SizedBox(height: 13),
              Text(title, style: SetupGuideTypography.cardTitle),
              const SizedBox(height: 5),
              Text(subtitle, style: SetupGuideTypography.cardSubtitle),
            ],
          ),
        );
      },
    );
  }
}

class _BarSwatch extends StatelessWidget {
  const _BarSwatch({
    required this.frosted,
    this.position = AppearancePosition.top,
  });

  final bool frosted;
  final AppearancePosition position;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x10FFFFFF)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 5,
            offset: Offset(0, 2),
            blurStyle: BlurStyle.inner,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(setupGuideWallpaper, fit: BoxFit.cover),
            Align(
              alignment: position == AppearancePosition.bottom
                  ? Alignment.bottomCenter
                  : Alignment.topCenter,
              child: Container(
                height: 15,
                margin: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: position == AppearancePosition.top ? 6 : 0,
                  bottom: position == AppearancePosition.bottom ? 6 : 0,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: frosted
                      ? const Color(0x4D24262E)
                      : const Color(0xFF272930),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0x1FFFFFFF)),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 12,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.setupGuideAccent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    for (int index = 0; index < 2; index++) ...<Widget>[
                      Container(
                        width: 5,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0x668E9097),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    const Spacer(),
                    Container(
                      width: 18,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0x668E9097),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlWell extends StatelessWidget {
  const _ControlWell({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 18, 16),
      decoration: setupWell(),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: SetupGuideTypography.rowTitle),
                const SizedBox(height: 5),
                Text(subtitle, style: SetupGuideTypography.cardSubtitle),
              ],
            ),
          ),
          const SizedBox(width: 20),
          trailing,
        ],
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: Text(
        value,
        textAlign: TextAlign.right,
        style: setupMono(color: const Color(0xFFC5C7CD), size: 11, spacing: 0),
      ),
    );
  }
}

class _HueSwatch extends StatelessWidget {
  const _HueSwatch({
    required this.hue,
    required this.selected,
    required this.onPressed,
  });

  final int hue;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color color = HSLColor.fromAHSL(
      1,
      hue.toDouble(),
      .72,
      .58,
    ).toColor();
    return Semantics(
      button: true,
      label: 'Accent hue $hue degrees',
      selected: selected,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color.lerp(color, Colors.white, .18)!,
                Color.lerp(color, Colors.black, .14)!,
              ],
            ),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0x1AFFFFFF)),
            boxShadow: <BoxShadow>[
              const BoxShadow(
                color: Color(0x2EFFFFFF),
                offset: Offset(0, 1),
                blurStyle: BlurStyle.inner,
              ),
              const BoxShadow(
                color: Color(0x59000000),
                blurRadius: 4,
                offset: Offset(0, -2),
                blurStyle: BlurStyle.inner,
              ),
              const BoxShadow(
                color: Color(0xBF000000),
                blurRadius: 9,
                spreadRadius: -4,
                offset: Offset(0, 4),
              ),
              if (selected) ...<BoxShadow>[
                const BoxShadow(color: Color(0xFF22242B), spreadRadius: 2),
                BoxShadow(
                  color: color.withValues(alpha: .7),
                  spreadRadius: 3.5,
                ),
                BoxShadow(
                  color: color.withValues(alpha: .55),
                  blurRadius: 18,
                  spreadRadius: -6,
                  offset: const Offset(0, 6),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentOption {
  const _SegmentOption({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.options});

  final List<_SegmentOption> options;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: setupWell(radius: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options
            .map(
              (_SegmentOption option) => Semantics(
                button: true,
                label: option.label,
                selected: option.selected,
                child: GestureDetector(
                  onTap: option.onPressed,
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    alignment: Alignment.center,
                    decoration: option.selected
                        ? BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Color.lerp(
                                  const Color(0xFF40434C),
                                  context.setupGuideAccent,
                                  .26,
                                )!,
                                Color.lerp(
                                  const Color(0xFF30323A),
                                  context.setupGuideAccent,
                                  .18,
                                )!,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x29FFFFFF),
                                offset: Offset(0, 1),
                                blurStyle: BlurStyle.inner,
                              ),
                            ],
                          )
                        : null,
                    child: Text(
                      option.label,
                      style: setupMono(
                        color: option.selected
                            ? const Color(0xFFE2E3E8)
                            : SetupGuideColors.textFaint,
                        size: 9,
                        spacing: .4,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.active, required this.onSelected});

  final SetupStep active;
  final ValueChanged<SetupStep> onSelected;

  @override
  Widget build(BuildContext context) {
    final int activeIndex = SetupStep.sequence.indexOf(active);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: setupWell(radius: 7),
      child: Row(
        children: List<Widget>.generate(SetupStep.sequence.length, (int index) {
          final bool selected = index == activeIndex;
          final SetupStep step = SetupStep.sequence[index];
          return Semantics(
            button: true,
            label: 'Go to ${step.label} step',
            selected: selected,
            child: GestureDetector(
              onTap: () => onSelected(step),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: selected ? 18 : 6,
                height: 6,
                margin: EdgeInsets.only(
                  right: index == SetupStep.sequence.length - 1 ? 0 : 6,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? context.setupGuideAccent
                      : index < activeIndex
                      ? const Color(0x42FFFFFF)
                      : const Color(0x21FFFFFF),
                  borderRadius: BorderRadius.circular(selected ? 3 : 6),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x80000000),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                      blurStyle: BlurStyle.inner,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
