import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../../layer_shell_controller.dart';
import '../../layer_shell_hit_region.dart';
import '../../state/providers.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'setup_guide_controls.dart';
import 'setup_guide_state.dart';
import 'setup_guide_style.dart';

/// The setup journey in the shared instrument shell.
///
/// Faint neutral coverage activates Hyprland's desktop blur. The
/// native input region follows the laid-out card, with keyboard focus on click.
class SetupGuideOverlay extends ConsumerStatefulWidget {
  const SetupGuideOverlay({
    super.key,
    required this.launch,
    this.onReady,
    required this.onFinished,
    required this.onSkipped,
  });

  final SetupLaunch launch;
  final VoidCallback? onReady;
  final VoidCallback onFinished;
  final VoidCallback onSkipped;

  @override
  ConsumerState<SetupGuideOverlay> createState() => _SetupGuideOverlayState();
}

class _SetupGuideOverlayState extends ConsumerState<SetupGuideOverlay> {
  static const String _regionOwner = 'setup-guide';
  static const List<int> _accentPresets = <int>[
    197,
    238,
    275,
    310,
    345,
    25,
    70,
    145,
  ];

  final GlobalKey _cardKey = GlobalKey(debugLabel: 'setup-guide-bounds');
  final FocusNode _focusNode = FocusNode(debugLabel: 'setup-guide');
  late final LayerShellController _layerShellController;
  late final LayerShellRegionManager _regionManager;
  SetupStep _step = SetupStep.welcome;
  bool _readyReported = false;

  @override
  void initState() {
    super.initState();
    _layerShellController = ref.read(layerShellControllerProvider);
    _regionManager = ref.read(layerShellRegionManagerProvider);
  }

  @override
  void dispose() {
    unawaited(_layerShellController.releaseKeyboard(_regionOwner));
    unawaited(
      _regionManager.removePassiveRegions(
        owner: _regionOwner,
        debugLabel: 'setup-guide-close',
      ),
    );
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _updateRegion() async {
    if (!mounted) {
      return;
    }

    final renderObject = _cardKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize ||
        renderObject.size.isEmpty) {
      await _regionManager.removePassiveRegions(owner: _regionOwner);
      await _layerShellController.releaseKeyboard(_regionOwner);
      return;
    }
    final bounds = renderObject.localToGlobal(Offset.zero) & renderObject.size;

    await _regionManager.setPassiveRegions(
      owner: _regionOwner,
      regions: <LayerShellMenuRegion>[
        LayerShellMenuRegion(rect: bounds, radius: BorderRadius.circular(18)),
      ],
      debugLabel: 'setup-guide-open',
    );

    if (!mounted) return;
    await _layerShellController.claimKeyboard(
      _regionOwner,
      mode: LayerShellKeyboardMode.onDemand,
    );
    if (mounted && !_readyReported) {
      _readyReported = true;
      widget.onReady?.call();
    }
  }

  void _go(SetupStep step) {
    ref.read(appearancePreviewProvider.notifier).clear();
    setState(() => _step = step);
  }

  void _next() {
    final int index = SetupStep.sequence.indexOf(_step);
    if (index == SetupStep.sequence.length - 1) {
      widget.onFinished();
      return;
    }

    _go(SetupStep.sequence[index + 1]);
  }

  void _back() {
    final int index = SetupStep.sequence.indexOf(_step);
    if (index > 0) {
      _go(SetupStep.sequence[index - 1]);
    }
  }

  void _setOpacity(int value) {
    ref.read(appearanceControllerProvider.notifier).setOpacity(value);
    ref.read(appearancePreviewProvider.notifier).clear();
  }

  void _previewOpacity(int value) {
    ref
        .read(appearancePreviewProvider.notifier)
        .preview(ref.read(currentAppearanceProvider).copyWith(opacity: value));
  }

  void _setAccent(int value) {
    ref.read(appearanceControllerProvider.notifier).setAccentHue(value);
    ref.read(appearancePreviewProvider.notifier).clear();
  }

  void _previewAccent(int value) {
    ref
        .read(appearancePreviewProvider.notifier)
        .preview(
          ref.read(currentAppearanceProvider).copyWith(accentHue: value),
        );
  }

  @override
  Widget build(BuildContext context) {
    final AppearanceStatus appearance = ref.watch(currentAppearanceProvider);
    final WorkspaceSettingsStatus workspaces = ref.watch(
      currentWorkspaceSettingsProvider,
    );

    return Positioned.fill(
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): widget.onSkipped,
        },
        child: Focus(
          autofocus: true,
          focusNode: _focusNode,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const IgnorePointer(
                child: ColoredBox(color: HyprColors.desktopBlurCoverage),
              ),
              Center(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => unawaited(_updateRegion()),
                    );
                    if (constraints.maxWidth < 560 ||
                        constraints.maxHeight < 320) {
                      return const SizedBox.shrink();
                    }
                    final double width = (constraints.maxWidth - 48).clamp(
                      0,
                      980,
                    );
                    final double height = (constraints.maxHeight - 40).clamp(
                      0,
                      660,
                    );

                    return SizedBox(
                      key: _cardKey,
                      width: width,
                      height: height,
                      child: SetupGuideCard(
                        width: width,
                        height: height,
                        step: _step,
                        onStepSelected: _go,
                        controls: SetupGuideControls(
                          step: _step,
                          appearance: appearance,
                          workspaces: workspaces,
                          accentPresets: _accentPresets,
                          onStepSelected: _go,
                          onBack: _back,
                          onNext: _next,
                          onSkip: widget.onSkipped,
                          onOpacityPreview: _previewOpacity,
                          onOpacityCommitted: _setOpacity,
                          onAccentPreview: _previewAccent,
                          onAccentCommitted: _setAccent,
                          onPositionChanged: (AppearancePosition position) {
                            ref
                                .read(appearanceControllerProvider.notifier)
                                .setPosition(position);
                          },
                          onWorkspaceStyleChanged:
                              (WorkspaceIndicatorStyle style) {
                                ref
                                    .read(
                                      workspaceSettingsControllerProvider
                                          .notifier,
                                    )
                                    .setIndicatorStyle(style);
                              },
                          globalMenuEnabled: ref
                              .watch(currentModulesProvider)
                              .isEnabled(ModuleId.globalMenu),
                          globalMenuIntegration: ref
                              .watch(globalMenuIntegrationProvider)
                              .asData
                              ?.value,
                          onGlobalMenuChanged: (bool enabled) {
                            ref
                                .read(modulesControllerProvider.notifier)
                                .setEnabled(
                                  ModuleId.globalMenu,
                                  enabled: enabled,
                                );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Settings-style setup chassis with step navigation and controls.
///
/// Both the native overlay and catalog compose this same clipped glass shell.
class SetupGuideCard extends StatelessWidget {
  const SetupGuideCard({
    super.key,
    required this.width,
    required this.height,
    required this.controls,
    required this.step,
    required this.onStepSelected,
  });

  final double width;
  final double height;
  final Widget controls;
  final SetupStep step;
  final ValueChanged<SetupStep> onStepSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey<String>('setup-guide'),
    width: width,
    height: height,
    child: HyprInstrumentSurface(
      borderRadius: BorderRadius.circular(18),
      child: Row(
        children: [
          SizedBox(
            width: width < 700 ? 164 : 232,
            child: ColoredBox(
              color: const Color(0x7007090E),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
                    child: Text(
                      'HYPRBARIC',
                      style: HyprInstrumentText.title.copyWith(
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final entry in SetupStep.sequence)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: HyprActionRow(
                              title: entry.label,
                              selected: step == entry,
                              onPressed: () => onStepSelected(entry),
                              titleStyle: HyprInstrumentText.body.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              titleColor: HyprInstrumentColors.secondary,
                              color: Colors.transparent,
                              selectedColor: const Color(0x50656895),
                              borderColor: Colors.transparent,
                              selectedBorderColor: HyprInstrumentColors.border,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              leadingGap: 12,
                              leadingBuilder:
                                  (
                                    context, {
                                    required hovered,
                                    required selected,
                                  }) => Icon(
                                    setupStepIcon(entry),
                                    size: 20,
                                    color: HyprInstrumentColors.secondary,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1, color: Color(0x457E86B4)),
          Expanded(child: controls),
        ],
      ),
    ),
  );
}
