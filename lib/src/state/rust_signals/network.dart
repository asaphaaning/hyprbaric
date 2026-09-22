import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rinf/rinf.dart';

import '../../bindings/bindings.dart';

/// Receives Network snapshots without retaining events for absent listeners.
///
/// The app constructs this feed before Rust starts. Its permanent subscription
/// drains the generated RINF controller, which otherwise buffers signals until
/// the Network panel first subscribes. The feed keeps only [latest] while the
/// panel is closed and broadcasts every observation while it is open.
class NetworkStatusFeed {
  NetworkStatusFeed() {
    _source = NetworkStatus.rustSignalStream.listen((signal) {
      _latest = signal.message;
      _updates.add(signal.message);
    });
  }

  final StreamController<NetworkStatus> _updates =
      StreamController<NetworkStatus>.broadcast();
  late final StreamSubscription<RustSignalPack<NetworkStatus>> _source;
  NetworkStatus? _latest;

  /// The newest snapshot, including one received before the panel opens.
  NetworkStatus? get latest => _latest;

  /// Replays the newest snapshot, then delivers each live observation.
  ///
  /// Riverpod can pause a subscription after the panel closes. A paused
  /// listener receives only the latest missed snapshot when it resumes.
  Stream<NetworkStatus> updates() => Stream<NetworkStatus>.multi((controller) {
    var missedWhilePaused = false;
    final subscription = _updates.stream.listen((status) {
      if (controller.isPaused) {
        missedWhilePaused = true;
        return;
      }
      controller.add(status);
    }, onDone: controller.close);
    controller.onCancel = subscription.cancel;
    controller.onResume = () {
      if (!missedWhilePaused) return;
      missedWhilePaused = false;

      final current = _latest;
      if (current != null) controller.add(current);
    };

    final current = _latest;
    if (current != null) controller.add(current);
  });

  /// Releases the RINF subscription when the feed's owner is disposed.
  Future<void> close() async {
    await _source.cancel();
    await _updates.close();
  }
}

/// One feed is shared by every view in the app's root provider scope.
final networkStatusFeedProvider = Provider<NetworkStatusFeed>((ref) {
  final feed = NetworkStatusFeed();
  ref.onDispose(() => unawaited(feed.close()));
  return feed;
});

Stream<NetworkCommandResult> _networkCommandResultStream() async* {
  final latest = NetworkCommandResult.latestRustSignal;
  if (latest != null) {
    yield latest.message;
  }

  await for (final rustSignal in NetworkCommandResult.rustSignalStream) {
    yield rustSignal.message;
  }
}

/// Live NetworkManager Wi-Fi state emitted from Rust.
final networkStatusProvider = StreamProvider<NetworkStatus>(
  (ref) => ref.watch(networkStatusFeedProvider).updates(),
);

/// Results from Wi-Fi scan, toggle, connect, and settings commands.
final networkCommandResultProvider = StreamProvider<NetworkCommandResult>(
  (ref) => _networkCommandResultStream(),
);
