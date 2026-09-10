import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../bindings/bindings.dart';

/// Immutable selection lifecycle, independent of focus, layout, and clocks.
///
/// Selecting -- Confirmed --> Idle
/// Selecting -- Rejected / Expired --> Failed -- Retried --> Selecting
@immutable
sealed class State {
  const State();

  /// Completes only the requested output; unrelated snapshots preserve state.
  State confirm(AudioOutputId? selected) => switch (this) {
    Selecting(:final id) when id == selected => const Idle(),
    Idle() || Selecting() || Failed() => this,
  };

  /// Accepts only a failure belonging to the output currently being selected.
  State reject(AudioCommandResult result) => switch ((this, result)) {
    (
      Selecting(:final id),
      AudioCommandResultFailed(
        command: AudioCommandSelectOutput(id: final rejected),
        :final message,
      ),
    )
        when id == rejected =>
      Failed(message),
    _ => this,
  };

  /// Expires this exact attempt, so an old timeout cannot fail a later retry.
  State expire(Selecting attempt) => identical(this, attempt)
      ? const Failed('Output change was not confirmed. Please try again.')
      : this;

  /// Clears a displayed failure without cancelling an in-flight selection.
  State clearFailure() => switch (this) {
    Failed() => const Idle(),
    Idle() || Selecting() => this,
  };
}

/// No output change is awaiting confirmation.
final class Idle extends State {
  const Idle();
}

/// One output change is awaiting a backend snapshot.
///
/// Each instance identifies a distinct attempt, including retries for the same
/// output. It is intentionally not const so attempts cannot be canonicalized.
final class Selecting extends State {
  // Each construction must create a distinct timeout token, even for one id.
  // ignore: prefer_const_constructors_in_immutables
  Selecting(this.id);

  /// Stable identity of the requested output.
  final AudioOutputId id;
}

/// The latest selection failed and can be retried.
final class Failed extends State {
  const Failed(this.message);

  /// User-facing failure detail.
  final String message;
}

/// Whether a backend update confirmed the in-flight selection.
enum Confirmation {
  /// No matching default-output confirmation was received.
  none,

  /// The requested output is now the backend-confirmed default.
  received,
}

/// Owns selection timing and applies backend updates to immutable [State].
///
/// Confirmed snapshots take precedence over failures in the same update.
/// Unrelated updates preserve both the current state and its original deadline.
/// Dispose with the picker to cancel its outstanding deadline.
class Control extends ChangeNotifier {
  Control({this.timeout = const Duration(seconds: 15)});

  /// Maximum wait for confirmation after requesting an output.
  final Duration timeout;

  State _state = const Idle();
  Timer? _deadline;

  /// Current immutable selection state; only transitions can replace it.
  State get state => _state;

  /// Starts a fresh attempt, replacing any previous attempt and its deadline.
  void select(AudioOutputId id) => _transition(Selecting(id));

  /// Applies a snapshot and, optionally, a newly received command report.
  ///
  /// Discovery loss cancels the attempt; the menu displays its discovery error.
  /// Pass only newly received reports, so a previous failure cannot reject a retry.
  Confirmation receive(AudioOutputs? outputs, {AudioCommandResult? result}) {
    switch (_state) {
      case Idle() || Failed():
        return Confirmation.none;
      case Selecting():
        if (outputs is! AudioOutputsAvailable) {
          _transition(const Idle());
          return Confirmation.none;
        }
        final State confirmed = _state.confirm(outputs.selected);
        if (confirmed is Idle) {
          _transition(confirmed);
          return Confirmation.received;
        }
        if (result != null) _transition(_state.reject(result));
        return Confirmation.none;
    }
  }

  /// Clears stale feedback when reopening or toggling the picker.
  void clearFailure() => _transition(_state.clearFailure());

  void _transition(State next) {
    if (identical(next, _state)) return;

    _deadline?.cancel();
    _state = next;
    _deadline = switch (next) {
      Selecting() => Timer(timeout, () => _transition(_state.expire(next))),
      Idle() || Failed() => null,
    };
    notifyListeners();
  }

  @override
  void dispose() {
    _deadline?.cancel();
    super.dispose();
  }
}
