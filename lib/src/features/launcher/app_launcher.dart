import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../../layer_shell_controller.dart';
import '../../state/layer_shell.dart';
import '../../state/rust_signals/launcher.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/modal_command_surface.dart';
import 'app_launcher_results.dart';
import 'launcher_controller.dart';

class AppLauncherController extends ModalCommandSurfaceController {}

class AppLauncher extends ConsumerStatefulWidget {
  const AppLauncher({
    super.key,
    required this.controller,
    required this.barHeight,
    required this.anchorKey,
    this.animationDuration = HyprMotion.popup,
    this.launcherRadius = HyprRadii.launcherRadius,
  });

  final AppLauncherController controller;
  final double barHeight;
  final GlobalKey anchorKey;
  final Duration animationDuration;
  final BorderRadius launcherRadius;

  @override
  ConsumerState<AppLauncher> createState() => _AppLauncherState();
}

class _AppLauncherState extends ConsumerState<AppLauncher> {
  static const String _keyboardOwner = 'app-launcher';
  final FocusNode _queryFocusNode = FocusNode(debugLabel: 'app-launcher-query');
  final TextEditingController _queryController = TextEditingController();
  late final LayerShellController _layerShellController;
  bool _muteQueryNotifications = false;
  Timer? _queryDispatchTimer;

  List<AppLauncherEntry> get _entries =>
      _resultsForCurrentQuery()?.entries ?? const <AppLauncherEntry>[];

  @override
  void initState() {
    super.initState();
    _layerShellController = ref.read(layerShellControllerProvider);
    _queryController.addListener(_handleQueryTextChanged);
  }

  @override
  void didUpdateWidget(covariant AppLauncher oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncQueryFromResults();
  }

  @override
  void dispose() {
    _queryController.removeListener(_handleQueryTextChanged);
    _queryDispatchTimer?.cancel();
    _queryController.dispose();
    _queryFocusNode.dispose();
    super.dispose();
  }

  void _handleOpening() {
    ref.read(launcherControllerProvider.notifier).opened();
    _setQuery('');
  }

  void _handleOpened() {
    _dispatchQueryIfCurrent('');
    unawaited(_layerShellController.claimKeyboard(_keyboardOwner));
  }

  void _handleClosing() {
    ref.read(launcherControllerProvider.notifier).closed();
    _setQuery('');
    _queryDispatchTimer?.cancel();
    unawaited(_layerShellController.releaseKeyboard(_keyboardOwner));
  }

  void _handleDismissed() {
    ref.read(launcherControllerProvider.notifier).closed();
    _setQuery('');
    _queryDispatchTimer?.cancel();
    unawaited(_layerShellController.releaseKeyboard(_keyboardOwner));
  }

  void _handleQueryTextChanged() {
    if (!widget.controller.isOpen || _muteQueryNotifications) {
      return;
    }
    _scheduleQueryDispatch(_queryController.text);
  }

  void _scheduleQueryDispatch(String query) {
    _queryDispatchTimer?.cancel();
    _queryDispatchTimer = Timer(HyprDurations.queryDebounce, () {
      _dispatchQueryIfCurrent(query);
    });
  }

  void _dispatchQueryIfCurrent(String query) {
    if (!mounted ||
        !widget.controller.isOpen ||
        _queryController.text != query) {
      return;
    }
    ref.read(launcherControllerProvider.notifier).updateQuery(query);
  }

  void _setQuery(String value) {
    _muteQueryNotifications = true;
    _queryController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _muteQueryNotifications = false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AppLauncherResults>>(appLauncherResultsProvider, (
      _,
      AsyncValue<AppLauncherResults> next,
    ) {
      if (next.asData?.value != null) {
        _syncQueryFromResults();
      }
    });
    ref.listen<LauncherViewState>(launcherControllerProvider, (
      LauncherViewState? previous,
      LauncherViewState next,
    ) {
      if (previous != null && previous.closeSerial != next.closeSerial) {
        widget.controller.close();
      }
    });

    final LauncherViewState state = ref.watch(launcherControllerProvider);
    return ModalCommandSurface(
      controller: widget.controller,
      barHeight: widget.barHeight,
      borderRadius: widget.launcherRadius,
      debugLabel: 'app-launcher',
      focusNode: _queryFocusNode,
      anchorKey: widget.anchorKey,
      placement: ModalCommandSurfacePlacement.anchorLeft,
      transition: ModalCommandSurfaceTransition.anchored,
      constraints: const BoxConstraints(
        maxWidth: 680,
        minWidth: 620,
        maxHeight: 506,
      ),
      width: 680,
      animationDuration: widget.animationDuration,
      shortcuts: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape):
            widget.controller.close,
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => ref
            .read(launcherControllerProvider.notifier)
            .moveSelection(1, _entries.length),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => ref
            .read(launcherControllerProvider.notifier)
            .moveSelection(-1, _entries.length),
        const SingleActivator(LogicalKeyboardKey.enter): () => ref
            .read(launcherControllerProvider.notifier)
            .launchSelected(_entries),
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () => ref
            .read(launcherControllerProvider.notifier)
            .launchSelected(_entries),
      },
      onOpening: _handleOpening,
      onOpened: _handleOpened,
      onClosing: _handleClosing,
      onDismissed: _handleDismissed,
      builder: (BuildContext context) {
        final AppLauncherResults? results = _resultsForCurrentQuery();
        return AppLauncherConsole(
          results: results,
          queryController: _queryController,
          queryFocusNode: _queryFocusNode,
          selectedIndex: state.selectedIndex,
          iconPathsByEntryId: state.iconPathsByEntryId,
          errorMessage: state.errorMessage,
          borderRadius: widget.launcherRadius,
          onSelect: (int index) {
            ref
                .read(launcherControllerProvider.notifier)
                .select(index, _entries.length);
          },
          onLaunch: (AppLauncherEntry entry) {
            ref.read(launcherControllerProvider.notifier).launch(entry);
          },
          onClose: widget.controller.close,
        );
      },
    );
  }

  AppLauncherResults? _resultsForCurrentQuery() {
    final AppLauncherResults? results = ref
        .watch(appLauncherResultsProvider)
        .asData
        ?.value;
    if (results == null || results.query == _queryController.text) {
      return results;
    }

    return AppLauncherResults(
      phase: AppLauncherPhase.loading,
      query: _queryController.text,
      entries: const <AppLauncherEntry>[],
    );
  }

  void _syncQueryFromResults() {
    final AppLauncherResults? results = ref
        .read(appLauncherResultsProvider)
        .asData
        ?.value;
    if (results != null &&
        results.query != _queryController.text &&
        !_queryFocusNode.hasFocus) {
      _setQuery(results.query);
    }
  }
}
