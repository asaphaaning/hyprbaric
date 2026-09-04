import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../../layer_shell_controller.dart';
import '../../state/layer_shell.dart';
import '../../theme/hypr_tokens.dart';
import '../../widgets/modal_command_surface.dart';
import 'session_controller.dart';
import 'session_launcher_content.dart';

class SessionLauncherController extends ModalCommandSurfaceController {}

class SessionLauncher extends ConsumerStatefulWidget {
  const SessionLauncher({
    super.key,
    required this.controller,
    required this.barHeight,
    this.anchorKey,
    this.animationDuration = HyprMotion.popup,
    this.launcherRadius = HyprRadii.launcherRadius,
  });

  final SessionLauncherController controller;
  final double barHeight;
  final GlobalKey? anchorKey;
  final Duration animationDuration;
  final BorderRadius launcherRadius;

  @override
  ConsumerState<SessionLauncher> createState() => _SessionLauncherState();
}

class _SessionLauncherState extends ConsumerState<SessionLauncher> {
  static const String _keyboardOwner = 'session-launcher';
  final FocusNode _focusNode = FocusNode(debugLabel: 'session-launcher');
  late final LayerShellController _layerShellController;

  @override
  void initState() {
    super.initState();
    _layerShellController = ref.read(layerShellControllerProvider);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleOpening() {
    ref.read(sessionControllerProvider.notifier).opened();
  }

  void _handleOpened() {
    unawaited(_layerShellController.claimKeyboard(_keyboardOwner));
  }

  void _handleClosing() {
    ref.read(sessionControllerProvider.notifier).closed();
    unawaited(_layerShellController.releaseKeyboard(_keyboardOwner));
  }

  void _handleDismissed() {
    ref.read(sessionControllerProvider.notifier).closed();
    unawaited(_layerShellController.releaseKeyboard(_keyboardOwner));
  }

  bool _canOpen() {
    return ref.read(sessionControllerProvider).canOpen;
  }

  void _cancelConfirm() {
    final bool cancelled = ref
        .read(sessionControllerProvider.notifier)
        .cancelConfirmation();
    if (!cancelled) {
      widget.controller.close();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _cancelConfirm();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      ref.read(sessionControllerProvider.notifier).activateSelection();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowLeft) {
      ref.read(sessionControllerProvider.notifier).moveSelection(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowRight) {
      ref.read(sessionControllerProvider.notifier).moveSelection(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SessionLauncherState>(sessionControllerProvider, (
      SessionLauncherState? previous,
      SessionLauncherState next,
    ) {
      if (previous != null && previous.closeSerial != next.closeSerial) {
        widget.controller.close();
        return;
      }
      if (widget.controller.isOpen &&
          previous != null &&
          (previous.confirmingAction != next.confirmingAction ||
              previous.errorMessage != next.errorMessage ||
              previous.actions.length != next.actions.length)) {
        widget.controller.refreshRegion();
      }
    });

    final SessionLauncherState state = ref.watch(sessionControllerProvider);
    return ModalCommandSurface(
      controller: widget.controller,
      barHeight: widget.barHeight,
      borderRadius: widget.launcherRadius,
      debugLabel: 'session-launcher',
      canOpen: _canOpen,
      onOpening: _handleOpening,
      onOpened: _handleOpened,
      onClosing: _handleClosing,
      onDismissed: _handleDismissed,
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      anchorKey: widget.anchorKey,
      placement: ModalCommandSurfacePlacement.anchorRight,
      transition: ModalCommandSurfaceTransition.anchored,
      width: 240,
      topGap: 10,
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 240),
      animationDuration: widget.animationDuration,
      builder: (BuildContext context) {
        return SessionLauncherCard(
          borderRadius: widget.launcherRadius,
          actions: state.actions,
          selectedAction: state.selectedAction,
          confirmingAction: state.confirmingAction,
          confirmChoice: state.confirmChoice,
          errorMessage: state.errorMessage,
          onActionTap: (SessionAction action) {
            ref.read(sessionControllerProvider.notifier).select(action);
          },
          onCancel: _cancelConfirm,
          onConfirm: () {
            ref.read(sessionControllerProvider.notifier).activateSelection();
          },
        );
      },
    );
  }
}
