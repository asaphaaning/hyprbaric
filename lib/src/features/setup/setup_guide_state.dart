import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ordered steps in the first-run journey.
enum SetupStep {
  welcome,
  transparency,
  accent,
  layout;

  static const List<SetupStep> sequence = <SetupStep>[
    welcome,
    transparency,
    accent,
    layout,
  ];

  String get label => switch (this) {
    SetupStep.welcome => 'Welcome',
    SetupStep.transparency => 'Transparency',
    SetupStep.accent => 'Accent',
    SetupStep.layout => 'Layout',
  };
}

/// Source that opened the setup journey.
enum SetupLaunch { automatic, manual }

/// An intentional request to show the guide from application UI.
enum SetupGuideRequest { show }

/// Whether this view may host automatic onboarding.
///
/// This is the policy switch; the election below is the tie-break between
/// the views eligible under it. Single-view builds leave this true, and even
/// with every view eligible exactly one host opens the guide. Every host
/// still stands down its automatic guide once completion settles, so a
/// redundant open can never linger past the first acknowledged journey.
final setupGuideAutomaticHostProvider = Provider<bool>((_) => true);

/// Elects the single view that opens the guide automatically.
///
/// Every native view builds its own [SetupGuideHost] against the same
/// container, and the persisted status is replayed to each one, so without an
/// election a multi-monitor session opens the journey on every bar at once.
class SetupGuideHostElection extends Notifier<Object?> {
  @override
  Object? build() => null;

  /// Claims automatic hosting for [candidate], if nobody holds it.
  bool claim(Object candidate) {
    state ??= candidate;
    return identical(state, candidate);
  }

  /// Releases the claim so a surviving view can take over.
  void release(Object candidate) {
    if (identical(state, candidate)) {
      state = null;
    }
  }
}

final setupGuideHostElectionProvider =
    NotifierProvider<SetupGuideHostElection, Object?>(
      SetupGuideHostElection.new,
    );

final setupGuideRequestProvider =
    NotifierProvider<SetupGuideRequestController, SetupGuideRequest?>(
      SetupGuideRequestController.new,
    );

class SetupGuideRequestController extends Notifier<SetupGuideRequest?> {
  @override
  SetupGuideRequest? build() => null;

  /// Opens the setup guide regardless of persisted startup state.
  void show() {
    state = SetupGuideRequest.show;
  }

  /// Consumes a request after the local view has opened the guide.
  void consume(SetupGuideRequest request) {
    if (state == request) {
      state = null;
    }
  }
}
