import 'dart:async';

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
/// paint. GTK deletions replace the cached rows too.
///
/// D-BusMenu rows belong to one opening, not a reusable snapshot. They are
/// kept only while that heading is [opening], so a reply that beats the
/// popup's first frame still paints, and a late reply after [forget] cannot
/// refill the next popup with stale Firefox identifiers.
///
/// Heading and flyout close drop rows accepted for that opening. Per-heading
/// streams auto-dispose when their last panel unmounts.
final globalMenuSectionCacheProvider =
    NotifierProvider<
      GlobalMenuSectionCache,
      Map<GlobalMenuAddress, GlobalMenuSectionStatus>
    >(GlobalMenuSectionCache.new);

class GlobalMenuSectionCache
    extends Notifier<Map<GlobalMenuAddress, GlobalMenuSectionStatus>> {
  final Set<GlobalMenuAddress> _opening = <GlobalMenuAddress>{};

  @override
  Map<GlobalMenuAddress, GlobalMenuSectionStatus> build() {
    ref.listen(globalMenuStatusProvider, (previous, next) {
      if (previous?.value?.session != next.value?.session) {
        _opening.clear();
        state = const {};
      }
    });
    ref.listen(focusedWindowStatusProvider, (previous, next) {
      if (previous?.value?.address != next.value?.address) {
        _opening.clear();
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
      final GlobalMenuAddress address = GlobalMenuAddress(
        session: status.session,
        section: status.section,
      );
      // D-BusMenu rows belong to an open, not a reusable snapshot. A late
      // response after dismissal must not repopulate the next popup's cache.
      if (status.section is GlobalMenuSectionIdDbusMenu &&
          !_opening.contains(address)) {
        return;
      }
      state = <GlobalMenuAddress, GlobalMenuSectionStatus>{
        ...state,
        address: status,
      };
    });
    ref.onDispose(subscription.cancel);
    return const <GlobalMenuAddress, GlobalMenuSectionStatus>{};
  }

  /// Accepts D-BusMenu rows for a heading the bar has just asked to open.
  ///
  /// The open request is sent before the overlay's first frame, and a warm
  /// exporter answers in that gap. Without this, the reply is dropped and the
  /// popup stays on Loading… until the next focus change.
  /// Call immediately before dispatching the open-section command.
  void opening(GlobalMenuAddress section) {
    _opening.add(section);
  }

  /// Stops accepting D-BusMenu rows without notifying listeners.
  ///
  /// Popup dispose cannot [forget] while the tree is unmounting. Dropping the
  /// opening mark here means a late reply cannot land. A later open replaces
  /// whatever rows remain in the cache.
  void abandon(GlobalMenuAddress section) {
    _opening.remove(section);
  }

  /// Drops rows for a heading that just closed.
  ///
  /// Firefox rebuilds native identifiers after a click. Keeping the last
  /// View menu would paint Actual Size as still disabled, and send Zoom In's
  /// old id, until AboutToShow returns.
  /// Call from a close interaction, including a popup releasing its flyouts.
  void forget(GlobalMenuAddress section) {
    _opening.remove(section);
    ref.invalidate(globalMenuSectionProvider(section));
    state = <GlobalMenuAddress, GlobalMenuSectionStatus>{...state}
      ..remove(section);
  }
}

/// Rows of one heading, delivered when Rust has read them.
///
/// Prefetch fills [globalMenuSectionCacheProvider] before a heading opens.
/// The per-heading request still runs so a miss waits on D-Bus instead of
/// showing an empty panel. This provider subscribes first, then seeds from
/// the cache: watching the whole cache map would restart every open menu
/// whenever a sibling flyout arrived, which is the one-row loading flash
/// while moving between Firefox submenus.
/// An empty cached reply also completes loading; later updates can still
/// populate the menu when the application finishes building its rows.
final globalMenuSectionProvider = StreamProvider.autoDispose
    .family<GlobalMenuSectionStatus, GlobalMenuAddress>(_sectionUpdates);

Stream<GlobalMenuSectionStatus> _sectionUpdates(
  Ref ref,
  GlobalMenuAddress section,
) async* {
  final StreamController<GlobalMenuSectionStatus> incoming =
      StreamController<GlobalMenuSectionStatus>();
  final subscription = GlobalMenuSectionStatus.rustSignalStream.listen((
    signal,
  ) {
    final GlobalMenuSectionStatus status = signal.message;
    if (status.session != section.session ||
        status.section != section.section) {
      return;
    }
    if (!incoming.isClosed) {
      incoming.add(status);
    }
  });
  ref.onDispose(() {
    unawaited(subscription.cancel());
    if (!incoming.isClosed) {
      unawaited(incoming.close());
    }
  });

  final GlobalMenuSectionStatus? cached = ref.read(
    globalMenuSectionCacheProvider,
  )[section];
  var hadItems = cached != null && cached.items.isNotEmpty;
  if (cached != null) {
    yield cached;
  }

  await for (final GlobalMenuSectionStatus status in incoming.stream) {
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
}

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
