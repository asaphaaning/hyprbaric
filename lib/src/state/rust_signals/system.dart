import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';

Stream<SystemStatus> _systemStatusStream() async* {
  final latest = SystemStatus.latestRustSignal;
  if (latest != null) {
    yield latest.message;
  }

  await for (final rustSignal in SystemStatus.rustSignalStream) {
    yield rustSignal.message;
  }
}

/// Live CPU, memory, and disk occupancy emitted from Rust.
final systemStatusProvider = StreamProvider<SystemStatus>(
  (ref) => _systemStatusStream(),
);
