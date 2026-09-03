import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../../features/settings/keybindings/keybinding_controller.dart';
import 'shortcuts.dart';

/// Asks Rust for the keybinding snapshot exactly once per container.
///
/// Rust only emits [ShortcutSettingsSnapshot] in reply to a load intent, so
/// something has to ask. This is split out from [shortcutLabelsProvider]
/// because a provider that watched the snapshot *and* dispatched the load
/// would re-dispatch on every snapshot it caused.
final _shortcutSettingsLoadProvider = Provider<void>((Ref ref) {
  unawaited(
    Future<void>.microtask(() => ref.read(keybindingControllerProvider).load()),
  );
});

/// The user's effective chord for each shortcut, ready to stamp onto a
/// control face.
///
/// A shortcut with no entry has no known binding, either because the snapshot
/// has not arrived yet or because the user disabled it. Callers must render
/// nothing in that case rather than guessing a default: a wrong chord is worse
/// than no chord.
final shortcutLabelsProvider = Provider<Map<ShortcutSettingId, String>>((
  Ref ref,
) {
  ref.watch(_shortcutSettingsLoadProvider);
  final ShortcutSettingsSnapshot? snapshot = ref
      .watch(shortcutSettingsSnapshotProvider)
      .asData
      ?.value;
  if (snapshot == null) {
    return const <ShortcutSettingId, String>{};
  }
  return <ShortcutSettingId, String>{
    for (final ShortcutSettingsRow row in snapshot.rows)
      if (row.effectiveMapping case ShortcutMappingViewBound(:final binding))
        row.shortcut: shortcutChordLabel(binding),
  };
});

/// Renders a binding the way a control face wants it.
///
/// Rust's own `display` spells modifiers out for the keybindings editor
/// (`LOGO+SHIFT+S`). A console face has room for roughly a dozen characters,
/// so this uses the shorter spelling the rest of the UI already reads.
String shortcutChordLabel(ShortcutBindingView binding) {
  return <String>[
    for (final ShortcutModifier modifier in binding.modifiers)
      switch (modifier) {
        ShortcutModifier.logo => 'Super',
        ShortcutModifier.ctrl => 'Ctrl',
        ShortcutModifier.shift => '⇧',
        ShortcutModifier.alt => 'Alt',
        ShortcutModifier.num => 'Num',
      },
    binding.key,
  ].join('+');
}
