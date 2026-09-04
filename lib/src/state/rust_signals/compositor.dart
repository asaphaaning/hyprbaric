import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';

class ShortcutEvent {
  const ShortcutEvent({required this.sequence, required this.event});

  final int sequence;
  final HotkeyEvent event;
}

Stream<WorkspaceStatus> _workspaceStream() async* {
  final latest = DesktopStatus.latestRustSignal;
  if (latest != null) {
    yield latest.message.workspace;
  }

  await for (final rustSignal in DesktopStatus.rustSignalStream) {
    yield rustSignal.message.workspace;
  }
}

Stream<FocusedWindowStatus> _focusedWindowStream() async* {
  final latest = DesktopStatus.latestRustSignal;
  if (latest != null) {
    yield latest.message.focusedWindow;
  }

  await for (final rustSignal in DesktopStatus.rustSignalStream) {
    yield rustSignal.message.focusedWindow;
  }
}

Stream<PortalStatus> _portalStream() async* {
  final latest = PortalStatus.latestRustSignal;
  if (latest != null) {
    yield latest.message;
  }

  await for (final rustSignal in PortalStatus.rustSignalStream) {
    yield rustSignal.message;
  }
}

Stream<ShortcutEvent> _shortcutStream() async* {
  var sequence = 0;
  await for (final rustSignal in HotkeyEvent.rustSignalStream) {
    yield ShortcutEvent(sequence: sequence++, event: rustSignal.message);
  }
}

/// Watches the Hyprland workspace updates forwarded from Rust.
final workspaceStatusProvider = StreamProvider<WorkspaceStatus>(
  (ref) => _workspaceStream(),
);

/// Watches the focused window updates forwarded from Rust.
final focusedWindowStatusProvider = StreamProvider<FocusedWindowStatus>(
  (ref) => _focusedWindowStream(),
);

/// Most recent portal-related data from Rust (e.g. color scheme).
// TODO(haaning): Feed this into a dedicated UI indicator once the bar exposes theme toggles.
final portalStatusProvider = StreamProvider<PortalStatus>(
  (ref) => _portalStream(),
);

/// Emits whenever a registered global shortcut is activated.
final shortcutEventProvider = StreamProvider<ShortcutEvent>(
  (ref) => _shortcutStream(),
);
