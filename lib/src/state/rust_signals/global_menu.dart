import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';

Stream<GlobalMenuStatus> _globalMenuStatusStream() async* {
  final latest = GlobalMenuStatus.latestRustSignal;
  if (latest != null) {
    yield latest.message;
  }

  await for (final signal in GlobalMenuStatus.rustSignalStream) {
    yield signal.message;
  }
}

/// Focused application menu projected by the native AppMenu bridge.
final globalMenuStatusProvider = StreamProvider<GlobalMenuStatus>(
  (ref) => _globalMenuStatusStream(),
);
