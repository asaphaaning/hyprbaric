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

/// Focused application headings projected by the native AppMenu bridge.
final globalMenuStatusProvider = StreamProvider<GlobalMenuStatus>(
  (ref) => _globalMenuStatusStream(),
);

/// Rows of one heading, delivered when Rust has read them.
///
/// Menus populate lazily: an application fills a section's rows only once
/// something announces the section is opening, so rows are requested per
/// heading rather than read with the bar.
final globalMenuSectionProvider =
    StreamProvider.family<GlobalMenuSectionStatus, GlobalMenuSectionId>((
      ref,
      GlobalMenuSectionId section,
    ) {
      return GlobalMenuSectionStatus.rustSignalStream
          .map((signal) => signal.message)
          .where((status) => status.section == section);
    });

/// How far the compositor half of the global menu has got.
final globalMenuIntegrationProvider = StreamProvider<GlobalMenuIntegrationStatus>(
  (ref) async* {
    final latest = GlobalMenuIntegrationStatus.latestRustSignal;
    if (latest != null) {
      yield latest.message;
    }

    await for (final signal in GlobalMenuIntegrationStatus.rustSignalStream) {
      yield signal.message;
    }
  },
);
