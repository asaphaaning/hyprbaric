import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../../layer_shell_controller.dart';
import '../../layer_shell_hit_region.dart';
import '../../state/providers.dart';
import 'setup_guide_controls.dart';
import 'setup_guide_preview.dart';
import 'setup_guide_state.dart';
import 'setup_guide_style.dart';

/// The split-stage setup guide from the v6 product reference.
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _focusNode.requestFocus();
      unawaited(_layerShellController.claimKeyboard(_regionOwner));
      unawaited(_updateRegion());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_updateRegion()),
    );
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

    final Size size = MediaQuery.sizeOf(context);
    await _regionManager.setPassiveRegions(
      owner: _regionOwner,
      regions: <LayerShellMenuRegion>[
        LayerShellMenuRegion(
          rect: Offset.zero & size,
          radius: BorderRadius.zero,
        ),
      ],
      debugLabel: 'setup-guide-open',
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
    final double barHeight = ref.watch(barHeightProvider) + 3;

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
            children: <Widget>[
              Positioned(
                top: appearance.position == AppearancePosition.top
                    ? barHeight
                    : 0,
                bottom: appearance.position == AppearancePosition.bottom
                    ? barHeight
                    : 0,
                left: 0,
                right: 0,
                child: const ColoredBox(
                  key: ValueKey<String>('setup-guide-scrim'),
                  color: SetupGuideColors.scrim,
                ),
              ),
              Center(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double width = (constraints.maxWidth - 48).clamp(
                      640,
                      980,
                    );
                    final double height = (constraints.maxHeight - 40).clamp(
                      500,
                      600,
                    );

                    return SetupGuideCard(
                      width: width,
                      height: height,
                      preview: SetupGuidePreview(
                        step: _step,
                        appearance: appearance,
                        workspaces: workspaces,
                      ),
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

/// The split-stage chassis that pairs the live preview with its controls.
///
/// The overlay owns the compositor plumbing; this card owns the layout, so the
/// catalog can present the guide without a layer-shell surface.
class SetupGuideCard extends StatelessWidget {
  const SetupGuideCard({
    super.key,
    required this.width,
    required this.height,
    required this.preview,
    required this.controls,
  });

  final double width;
  final double height;
  final Widget preview;
  final Widget controls;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('setup-guide'),
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0xE0000000),
            blurRadius: 90,
            spreadRadius: -30,
            offset: Offset(0, 42),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: SetupGuideColors.chassis,
            border: Border.all(color: const Color(0x80000000)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                left: width * .45,
                top: 0,
                right: 0,
                bottom: 0,
                child: controls,
              ),
              Positioned(
                left: 0,
                top: 0,
                width: width * .45,
                bottom: 0,
                child: ClipPath(
                  key: const ValueKey<String>('setup-guide-preview'),
                  clipper: const SetupStageClipper(),
                  child: preview,
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  key: const ValueKey<String>('setup-guide-seam'),
                  painter: SetupSeamPainter(
                    split: .45,
                    accent: context.setupGuideAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
