import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import 'compositor.dart';

Stream<GlobalMenuStatus> _globalMenuStatusStream(Ref ref) async* {
  bool belongs(GlobalMenuStatus status) {
    final focus = ref.read(focusedWindowStatusProvider).value;
    return focus == null || focus.address == status.window;
  }

  final latest = GlobalMenuStatus.latestRustSignal;
  if (latest != null && belongs(latest.message)) {
    yield latest.message;
  }

  await for (final signal in GlobalMenuStatus.rustSignalStream) {
    if (belongs(signal.message)) yield signal.message;
  }
}

/// Focused application headings projected by the native AppMenu bridge.
final globalMenuStatusProvider = StreamProvider<GlobalMenuStatus>(
  _globalMenuStatusStream,
);

/// GTK rows the native side has already read for the focused window.
///
/// Headings trigger a background snapshot. This map is filled as those rows
/// arrive, so a heading that opens before its own request returns can still
/// paint. GTK deletions replace the cached rows too. D-BusMenu rows are read
/// for each opening and never retained in this cache.
final globalMenuSectionCacheProvider =
    NotifierProvider<
      GlobalMenuSectionCache,
      Map<GlobalMenuAddress, GlobalMenuSectionStatus>
    >(GlobalMenuSectionCache.new);

class GlobalMenuSectionCache
    extends Notifier<Map<GlobalMenuAddress, GlobalMenuSectionStatus>> {
  @override
  Map<GlobalMenuAddress, GlobalMenuSectionStatus> build() {
    ref.listen(globalMenuStatusProvider, (previous, next) {
      if (previous?.value?.session != next.value?.session) {
        state = const {};
      }
    });
    ref.listen(focusedWindowStatusProvider, (previous, next) {
      if (previous?.value?.address != next.value?.address) {
        state = const {};
      }
    });
    final subscription = GlobalMenuSectionStatus.rustSignalStream.listen((
      signal,
    ) {
      final GlobalMenuSectionStatus status = signal.message;
      final current = ref.read(globalMenuStatusProvider).value?.session;
      if (current != status.session) return;
      final focused = ref.read(focusedWindowStatusProvider).value;
      if (focused != null && focused.address != status.session.window) return;
      // D-BusMenu rows belong to an open, not a reusable snapshot. A late
      // response after dismissal must not repopulate the next popup's cache.
      if (status.section is GlobalMenuSectionIdDbusMenu) return;
      state = <GlobalMenuAddress, GlobalMenuSectionStatus>{
        ...state,
        GlobalMenuAddress(session: status.session, section: status.section):
            status,
      };
    });
    ref.onDispose(subscription.cancel);
    return const <GlobalMenuAddress, GlobalMenuSectionStatus>{};
  }

  /// Drops rows for a heading that just closed.
  ///
  /// Firefox rebuilds native identifiers after a click. Keeping the last
  /// View menu would paint Actual Size as still disabled, and send Zoom In's
  /// old id, until AboutToShow returns.
  void forget(GlobalMenuAddress section) {
    ref.invalidate(globalMenuSectionProvider(section));
    state = <GlobalMenuAddress, GlobalMenuSectionStatus>{...state}
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
final globalMenuSectionProvider = StreamProvider.autoDispose
    .family<GlobalMenuSectionStatus, GlobalMenuAddress>((
      ref,
      GlobalMenuAddress section,
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
        if (status.session != section.session ||
            status.section != section.section) {
          continue;
        }
        if (status.items.isEmpty &&
            status.message == null &&
            status.section is GlobalMenuSectionIdDbusMenu) {
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
