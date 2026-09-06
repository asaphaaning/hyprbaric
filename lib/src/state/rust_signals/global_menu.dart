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

/// Rows the native side has already read for the focused window.
///
/// Headings trigger a background snapshot. This map is filled as those rows
/// arrive, so a heading that opens before its own request returns can still
/// paint. Empty placeholder layouts are ignored so they cannot paint
/// "No entries" over a later fill.
final globalMenuSectionCacheProvider =
    NotifierProvider<
      GlobalMenuSectionCache,
      Map<GlobalMenuSectionId, GlobalMenuSectionStatus>
    >(GlobalMenuSectionCache.new);

class GlobalMenuSectionCache
    extends Notifier<Map<GlobalMenuSectionId, GlobalMenuSectionStatus>> {
  @override
  Map<GlobalMenuSectionId, GlobalMenuSectionStatus> build() {
    final subscription = GlobalMenuSectionStatus.rustSignalStream.listen((
      signal,
    ) {
      final GlobalMenuSectionStatus status = signal.message;
      // Firefox placeholders and quiet layouts arrive empty. Storing them
      // would paint "No entries" and hide a later AboutToShow fill.
      if (status.items.isEmpty && status.message == null) {
        return;
      }
      state = <GlobalMenuSectionId, GlobalMenuSectionStatus>{
        ...state,
        status.section: status,
      };
    });
    ref.onDispose(subscription.cancel);
    return const <GlobalMenuSectionId, GlobalMenuSectionStatus>{};
  }

  /// Drops rows for a heading that just closed.
  ///
  /// Firefox rebuilds native identifiers after a click. Keeping the last
  /// View menu would paint Actual Size as still disabled, and send Zoom In's
  /// old id, until AboutToShow returns.
  void forget(GlobalMenuSectionId section) {
    if (!state.containsKey(section)) {
      return;
    }
    state = <GlobalMenuSectionId, GlobalMenuSectionStatus>{...state}
      ..remove(section);
  }
}

/// Rows of one heading, delivered when Rust has read them.
///
/// Prefetch fills [globalMenuSectionCacheProvider] before a heading opens.
/// The per-heading request still runs so a miss waits on D-Bus instead of
/// showing an empty panel. This provider reads the cache once and then
/// follows the section's own stream: watching the whole cache map would
/// restart every open menu whenever a sibling flyout arrived, which is the
/// one-row loading flash while moving between Firefox submenus.
final globalMenuSectionProvider =
    StreamProvider.family<GlobalMenuSectionStatus, GlobalMenuSectionId>((
      ref,
      GlobalMenuSectionId section,
    ) async* {
      final GlobalMenuSectionStatus? cached = ref.read(
        globalMenuSectionCacheProvider,
      )[section];
      var hadItems = cached != null && cached.items.isNotEmpty;
      if (cached != null && (hadItems || cached.message != null)) {
        yield cached;
      }

      await for (final signal in GlobalMenuSectionStatus.rustSignalStream) {
        final GlobalMenuSectionStatus status = signal.message;
        if (status.section != section) {
          continue;
        }
        if (status.items.isEmpty && status.message == null) {
          if (hadItems) {
            continue;
          }
          yield status;
          continue;
        }
        hadItems = status.items.isNotEmpty;
        yield status;
      }
    });

/// How far the compositor half of the global menu has got.
final globalMenuIntegrationProvider =
    StreamProvider<GlobalMenuIntegrationStatus>((ref) async* {
      final latest = GlobalMenuIntegrationStatus.latestRustSignal;
      if (latest != null) {
        yield latest.message;
      }

      await for (final signal in GlobalMenuIntegrationStatus.rustSignalStream) {
        yield signal.message;
      }
    });
