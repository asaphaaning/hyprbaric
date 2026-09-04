import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';
import 'setup_fixtures.dart';

@UseCase(name: 'Welcome', type: SetupGuideCard, path: '[Widgets]/Setup')
Widget buildWelcomeSetupGuide(BuildContext context) {
  return const _SetupGuideStory(step: SetupStep.welcome);
}

@UseCase(name: 'Transparency', type: SetupGuideCard, path: '[Widgets]/Setup')
Widget buildTransparencySetupGuide(BuildContext context) {
  return const _SetupGuideStory(step: SetupStep.transparency);
}

@UseCase(name: 'Accent', type: SetupGuideCard, path: '[Widgets]/Setup')
Widget buildAccentSetupGuide(BuildContext context) {
  return const _SetupGuideStory(step: SetupStep.accent);
}

@UseCase(name: 'Layout', type: SetupGuideCard, path: '[Widgets]/Setup')
Widget buildLayoutSetupGuide(BuildContext context) {
  return const _SetupGuideStory(
    step: SetupStep.layout,
    appearance: SetupFixtures.appearanceTuned,
    workspaces: SetupFixtures.workspacesNumeric,
  );
}

@UseCase(name: 'Interactive', type: SetupGuideCard, path: '[Widgets]/Setup')
Widget buildInteractiveSetupGuide(BuildContext context) {
  return const _InteractiveSetupGuideStory();
}

@UseCase(
  name: 'Stage — every step',
  type: SetupGuidePreview,
  path: '[Building blocks]/Setup',
)
Widget buildSetupGuidePreviewSteps(BuildContext context) {
  return const _SetupGuidePreviewStates();
}

@UseCase(
  name: 'Controls — every step',
  type: SetupGuideControls,
  path: '[Building blocks]/Setup',
)
Widget buildSetupGuideControlsSteps(BuildContext context) {
  return const _SetupGuideControlsStates();
}

/// The production guide card at the size the overlay gives it on a 1080p output.
class _SetupGuideStory extends StatelessWidget {
  const _SetupGuideStory({
    required this.step,
    this.appearance = SetupFixtures.appearanceDefault,
    this.workspaces = SetupFixtures.workspacesRoman,
  });

  final SetupStep step;
  final AppearanceStatus appearance;
  final WorkspaceSettingsStatus workspaces;

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: _guideCard(
        step: step,
        appearance: appearance,
        workspaces: workspaces,
      ),
    );
  }
}

/// Walks the real step sequence and commits appearance edits to local state.
class _InteractiveSetupGuideStory extends StatefulWidget {
  const _InteractiveSetupGuideStory();

  @override
  State<_InteractiveSetupGuideStory> createState() =>
      _InteractiveSetupGuideStoryState();
}

class _InteractiveSetupGuideStoryState
    extends State<_InteractiveSetupGuideStory> {
  SetupStep step = SetupStep.welcome;
  AppearanceStatus appearance = SetupFixtures.appearanceDefault;
  WorkspaceSettingsStatus workspaces = SetupFixtures.workspacesRoman;
  AppearanceStatus? preview;

  void _go(int offset) {
    final int index = SetupStep.sequence.indexOf(step) + offset;
    if (index < 0 || index >= SetupStep.sequence.length) {
      return;
    }
    setState(() {
      step = SetupStep.sequence[index];
      preview = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: _guideCard(
        step: step,
        appearance: preview ?? appearance,
        workspaces: workspaces,
        onStepSelected: (SetupStep next) {
          setState(() {
            step = next;
            preview = null;
          });
        },
        onBack: () => _go(-1),
        onNext: () => _go(1),
        onOpacityPreview: (int value) {
          setState(() => preview = appearance.copyWith(opacity: value));
        },
        onOpacityCommitted: (int value) {
          setState(() {
            appearance = appearance.copyWith(opacity: value);
            preview = null;
          });
        },
        onAccentPreview: (int value) {
          setState(() => preview = appearance.copyWith(accentHue: value));
        },
        onAccentCommitted: (int value) {
          setState(() {
            appearance = appearance.copyWith(accentHue: value);
            preview = null;
          });
        },
        onPositionChanged: (AppearancePosition position) {
          setState(() {
            appearance = appearance.copyWith(position: position);
            preview = null;
          });
        },
        onWorkspaceStyleChanged: (WorkspaceIndicatorStyle style) {
          setState(
            () => workspaces = workspaces.copyWith(indicatorStyle: style),
          );
        },
      ),
    );
  }
}

class _SetupGuidePreviewStates extends StatelessWidget {
  const _SetupGuidePreviewStates();

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        children: <Widget>[
          for (final SetupStep step in SetupStep.sequence)
            _LabelledStage(
              label: step.label,
              child: SizedBox(
                width: 320,
                height: 420,
                child: SetupGuidePreview(
                  step: step,
                  appearance: SetupFixtures.appearanceDefault,
                  workspaces: SetupFixtures.workspacesRoman,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SetupGuideControlsStates extends StatelessWidget {
  const _SetupGuideControlsStates();

  @override
  Widget build(BuildContext context) {
    return CatalogCanvas(
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        children: <Widget>[
          for (final SetupStep step in SetupStep.sequence)
            _LabelledStage(
              label: step.label,
              child: SizedBox(
                width: 460,
                height: 560,
                child: ColoredBox(
                  color: const Color(0xFF0C1218),
                  child: _controls(
                    step: step,
                    appearance: SetupFixtures.appearanceDefault,
                    workspaces: SetupFixtures.workspacesRoman,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LabelledStage extends StatelessWidget {
  const _LabelledStage({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// Mirrors the geometry the overlay hands [SetupGuideCard] at 1920x1080.
Widget _guideCard({
  required SetupStep step,
  required AppearanceStatus appearance,
  required WorkspaceSettingsStatus workspaces,
  ValueChanged<SetupStep>? onStepSelected,
  VoidCallback? onBack,
  VoidCallback? onNext,
  ValueChanged<int>? onOpacityPreview,
  ValueChanged<int>? onOpacityCommitted,
  ValueChanged<int>? onAccentPreview,
  ValueChanged<int>? onAccentCommitted,
  ValueChanged<AppearancePosition>? onPositionChanged,
  ValueChanged<WorkspaceIndicatorStyle>? onWorkspaceStyleChanged,
}) {
  const double width = 980;
  const double height = 600;

  return SetupGuideCard(
    width: width,
    height: height,
    preview: SetupGuidePreview(
      step: step,
      appearance: appearance,
      workspaces: workspaces,
    ),
    controls: _controls(
      step: step,
      appearance: appearance,
      workspaces: workspaces,
      onStepSelected: onStepSelected,
      onBack: onBack,
      onNext: onNext,
      onOpacityPreview: onOpacityPreview,
      onOpacityCommitted: onOpacityCommitted,
      onAccentPreview: onAccentPreview,
      onAccentCommitted: onAccentCommitted,
      onPositionChanged: onPositionChanged,
      onWorkspaceStyleChanged: onWorkspaceStyleChanged,
    ),
  );
}

Widget _controls({
  required SetupStep step,
  required AppearanceStatus appearance,
  required WorkspaceSettingsStatus workspaces,
  ValueChanged<SetupStep>? onStepSelected,
  VoidCallback? onBack,
  VoidCallback? onNext,
  ValueChanged<int>? onOpacityPreview,
  ValueChanged<int>? onOpacityCommitted,
  ValueChanged<int>? onAccentPreview,
  ValueChanged<int>? onAccentCommitted,
  ValueChanged<AppearancePosition>? onPositionChanged,
  ValueChanged<WorkspaceIndicatorStyle>? onWorkspaceStyleChanged,
}) {
  return SetupGuideControls(
    step: step,
    appearance: appearance,
    workspaces: workspaces,
    accentPresets: SetupFixtures.accentPresets,
    onStepSelected: onStepSelected ?? _ignore<SetupStep>,
    onBack: onBack ?? _noop,
    onNext: onNext ?? _noop,
    onSkip: _noop,
    onOpacityPreview: onOpacityPreview ?? _ignore<int>,
    onOpacityCommitted: onOpacityCommitted ?? _ignore<int>,
    onAccentPreview: onAccentPreview ?? _ignore<int>,
    onAccentCommitted: onAccentCommitted ?? _ignore<int>,
    onPositionChanged: onPositionChanged ?? _ignore<AppearancePosition>,
    onWorkspaceStyleChanged:
        onWorkspaceStyleChanged ?? _ignore<WorkspaceIndicatorStyle>,
  );
}

void _ignore<T>(T _) {}

void _noop() {}
