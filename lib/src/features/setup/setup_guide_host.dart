import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../../state/providers.dart';
import '../rust_commands.dart';
import 'setup_guide_overlay.dart';
import 'setup_guide_state.dart';

/// Owns the setup journey for one Flutter view.
///
/// Automatic opening is elected: every view builds a host against the same
/// container, but only the election winner opens the journey, so a
/// multi-monitor session does not onboard every bar at once.
///
/// The guide closes optimistically when the user finishes or skips, while
/// persistence settles asynchronously: a failure toasts and reopens for a
/// retry, and completion settling elsewhere stands down automatic guides.
/// Skipping restores the appearance trial changes; finishing keeps them.
class SetupGuideHost extends ConsumerStatefulWidget {
  const SetupGuideHost({super.key, this.onReady});

  /// Called after the guide has claimed its native input region.
  final VoidCallback? onReady;

  @override
  ConsumerState<SetupGuideHost> createState() => _SetupGuideHostState();
}

class _SetupGuideHostState extends ConsumerState<SetupGuideHost> {
  SetupLaunch? _launch;
  bool _awaitingPersistence = false;
  AppearanceStatus? _appearanceBefore;
  WorkspaceSettingsStatus? _workspacesBefore;
  late final ProviderSubscription<AsyncValue<SetupStatus>> _statusSubscription;
  late final ProviderSubscription<AsyncValue<SetupCommandResult>>
  _resultSubscription;
  late final ProviderSubscription<SetupGuideRequest?> _requestSubscription;
  late final ProviderSubscription<bool> _hostSubscription;

  /// Captured up front: `ref` cannot be read once the element is unmounting,
  /// and the claim has to be released exactly then.
  late final SetupGuideHostElection _election;

  @override
  void initState() {
    super.initState();
    _election = ref.read(setupGuideHostElectionProvider.notifier);
    _statusSubscription = ref.listenManual<AsyncValue<SetupStatus>>(
      setupStatusProvider,
      (_, AsyncValue<SetupStatus> next) {
        next.whenData(_acceptStatus);
      },
      fireImmediately: true,
    );
    _resultSubscription = ref.listenManual<AsyncValue<SetupCommandResult>>(
      setupCommandResultProvider,
      (_, AsyncValue<SetupCommandResult> next) {
        next.whenData(_acceptResult);
      },
      fireImmediately: true,
    );
    _requestSubscription = ref.listenManual<SetupGuideRequest?>(
      setupGuideRequestProvider,
      (_, SetupGuideRequest? request) {
        final pending = request;
        if (pending != null &&
            pending == SetupGuideRequest.show &&
            ref.read(setupGuideAutomaticHostProvider)) {
          _open(SetupLaunch.manual);
          scheduleMicrotask(
            () => ref.read(setupGuideRequestProvider.notifier).consume(pending),
          );
        }
      },
    );
    _hostSubscription = ref.listenManual<bool>(
      setupGuideAutomaticHostProvider,
      (_, bool isHost) {
        if (isHost) {
          ref.read(setupStatusProvider).whenData(_acceptStatus);
        } else {
          _standDownAutomatic();
        }
      },
    );
  }

  @override
  void dispose() {
    _statusSubscription.close();
    _resultSubscription.close();
    _requestSubscription.close();
    _hostSubscription.close();
    _election.release(this);
    super.dispose();
  }

  /// Closes an automatic guide that lost its eligibility or settled
  /// elsewhere. A manually opened guide belongs to the user and stays.
  void _standDownAutomatic() {
    if (_launch == SetupLaunch.automatic) {
      _awaitingPersistence = false;
      _appearanceBefore = null;
      _workspacesBefore = null;
      _election.release(this);
      setState(() => _launch = null);
    }
  }

  void _acceptStatus(SetupStatus status) {
    switch (status.state) {
      case SetupState.required:
        if (ref.read(setupGuideAutomaticHostProvider)) {
          if (_election.claim(this)) {
            _open(SetupLaunch.automatic);
          }
        }
      case SetupState.complete:
      case SetupState.disabled:
        // Completion settled elsewhere: another view acknowledged first, or a
        // relaunch delivered the persisted outcome of our optimistic close.
        // Automatic guides have nothing left to save, so they stand down. A
        // manually opened guide belongs to the user and stays.
        _standDownAutomatic();
    }
  }

  void _acceptResult(SetupCommandResult result) {
    if (result case SetupCommandResultFailed(:final message)) {
      // Only the host with an outstanding completion reacts. This ignores
      // replayed failures and failures settled by another view.
      if (!_awaitingPersistence) {
        return;
      }
      _awaitingPersistence = false;
      ref
          .read(transientOverlayProvider.notifier)
          .showLocalToast(
            app: 'Setup',
            message: 'Could not save setup completion: $message',
          );
      // The journey is still required. Reopen for a retry instead of
      // vanishing silently until the next launch.
      _open(SetupLaunch.manual);
      return;
    }

    if (result is SetupCommandResultSaved) {
      // Only our own acknowledgement settles the snapshot. A foreign Saved
      // leaves a manually opened guide and its restore baseline alone.
      if (!_awaitingPersistence) {
        return;
      }
      _awaitingPersistence = false;
      _appearanceBefore = null;
      _workspacesBefore = null;
    }
  }

  void _open(SetupLaunch launch) {
    if (mounted && _launch == null) {
      _appearanceBefore ??= ref.read(currentAppearanceProvider);
      _workspacesBefore ??= ref.read(currentWorkspaceSettingsProvider);
      setState(() => _launch = launch);
    }
  }

  void _complete(SetupOutcome outcome) {
    if (outcome == SetupOutcome.skipped) {
      _restoreSnapshot();
    } else {
      _appearanceBefore = null;
      _workspacesBefore = null;
      ref.read(appearancePreviewProvider.notifier).clear();
    }
    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(SetupIntent.complete(outcome));
    _awaitingPersistence = true;
    setState(() => _launch = null);
  }

  /// Reverts the appearance trial changes to the values at guide open.
  ///
  /// Only the settings the guide can change are restored, and only where
  /// they actually differ, so an untouched journey dispatches nothing.
  void _restoreSnapshot() {
    final AppearanceStatus? appearance = _appearanceBefore;
    final WorkspaceSettingsStatus? workspaces = _workspacesBefore;
    _appearanceBefore = null;
    _workspacesBefore = null;
    ref.read(appearancePreviewProvider.notifier).clear();

    if (appearance == null || workspaces == null) {
      return;
    }

    final AppearanceStatus current = ref.read(currentAppearanceProvider);
    final AppearanceController appearanceController = ref.read(
      appearanceControllerProvider.notifier,
    );
    if (current.opacity != appearance.opacity) {
      appearanceController.setOpacity(appearance.opacity);
    }
    if (current.accentHue != appearance.accentHue) {
      appearanceController.setAccentHue(appearance.accentHue);
    }
    if (current.position != appearance.position) {
      appearanceController.setPosition(appearance.position);
    }

    final WorkspaceSettingsStatus currentWorkspaces = ref.read(
      currentWorkspaceSettingsProvider,
    );
    if (currentWorkspaces.indicatorStyle != workspaces.indicatorStyle) {
      ref
          .read(workspaceSettingsControllerProvider.notifier)
          .setIndicatorStyle(workspaces.indicatorStyle);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_launch == null) {
      return const SizedBox.shrink();
    }

    return SetupGuideOverlay(
      launch: _launch!,
      onReady: widget.onReady,
      onFinished: () => _complete(SetupOutcome.finished),
      onSkipped: () => _complete(SetupOutcome.skipped),
    );
  }
}
