import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';

/// Every received snapshot, including identical idle observations.
Stream<NetworkStatus> networkStatusUpdates() async* {
  final latest = NetworkStatus.latestRustSignal;
  if (latest != null) {
    yield latest.message;
  }

  await for (final rustSignal in NetworkStatus.rustSignalStream) {
    yield rustSignal.message;
  }
}

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
  (ref) => networkStatusUpdates(),
);

/// Results from Wi-Fi scan, toggle, connect, and settings commands.
final networkCommandResultProvider = StreamProvider<NetworkCommandResult>(
  (ref) => _networkCommandResultStream(),
);
