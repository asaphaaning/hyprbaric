import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bindings/bindings.dart';
import '../../../state/rust_signals/shortcuts.dart';
import '../../../state/transient_overlays.dart';
import '../../../widgets/hypr_surface.dart';
import '../../../widgets/primitives/primitives.dart';
import 'keybinding_controller.dart';

class KeybindingsPanel extends ConsumerStatefulWidget {
  const KeybindingsPanel({super.key});

  @override
  ConsumerState<KeybindingsPanel> createState() => _KeybindingsPanelState();
}

class _KeybindingsPanelState extends ConsumerState<KeybindingsPanel> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'keybindings-panel');
  final ScrollController _scrollController = ScrollController();
  final Map<ShortcutSettingId, _PendingMapping> _pendingMappings =
      <ShortcutSettingId, _PendingMapping>{};
  final Set<ShortcutModifier> _recordingModifiers = <ShortcutModifier>{};

  ShortcutSettingId? _recording;
  String? _message;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleHardwareKeyEvent);
    unawaited(
      Future<void>.microtask(() {
        if (mounted) {
          ref.read(keybindingControllerProvider).load();
        }
      }),
    );
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKeyEvent);
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startRecording(ShortcutSettingsRow row) {
    setState(() {
      _recording = row.shortcut;
      _recordingModifiers.clear();
      _message = 'Press a new shortcut for ${row.label}';
    });
    FocusScope.of(context).requestFocus(_focusNode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _recording == row.shortcut) {
        FocusScope.of(context).requestFocus(_focusNode);
      }
    });
  }

  void _setPendingMapping(
    ShortcutSettingId shortcut,
    ShortcutMappingView mapping,
    ShortcutMappingSource source,
  ) {
    _pendingMappings[shortcut] = _PendingMapping(
      mapping: mapping,
      source: source,
    );
  }

  void _clearPendingMapping(ShortcutSettingId? shortcut) {
    if (shortcut == null) {
      _pendingMappings.clear();
    } else {
      _pendingMappings.remove(shortcut);
    }
  }

  void _reconcilePendingMappings(ShortcutSettingsSnapshot snapshot) {
    final List<ShortcutSettingId> confirmed = <ShortcutSettingId>[];

    for (final ShortcutSettingsRow row in snapshot.rows) {
      final _PendingMapping? pending = _pendingMappings[row.shortcut];
      if (pending == null) {
        continue;
      }
      if (pending.mapping == row.effectiveMapping &&
          pending.source == row.source) {
        confirmed.add(row.shortcut);
      }
    }

    if (confirmed.isEmpty) {
      return;
    }

    setState(() {
      for (final ShortcutSettingId shortcut in confirmed) {
        _pendingMappings.remove(shortcut);
      }
    });
  }

  ShortcutSettingsRow _projectRow(ShortcutSettingsRow row) {
    final _PendingMapping? pending = _pendingMappings[row.shortcut];
    if (pending == null) {
      return row;
    }

    return row.copyWith(
      effectiveMapping: pending.mapping,
      source: pending.source,
      conflict: () => null,
    );
  }

  bool _handleHardwareKeyEvent(KeyEvent event) {
    return _handleRecordingKeyEvent(event);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    return _handleRecordingKeyEvent(event)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  bool _handleRecordingKeyEvent(KeyEvent event) {
    final ShortcutSettingId? recording = _recording;
    if (recording == null) {
      return false;
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() {
        _recording = null;
        _recordingModifiers.clear();
        _message = null;
      });
      return true;
    }

    final ShortcutModifier? modifier = _modifierFor(event.logicalKey);
    if (modifier != null) {
      setState(() {
        if (event is KeyUpEvent) {
          _recordingModifiers.remove(modifier);
        } else {
          _recordingModifiers.add(modifier);
        }
      });
      return true;
    }
    if (event is! KeyDownEvent) {
      return true;
    }

    final String? key = _keyLabel(event.logicalKey);
    if (key == null) {
      setState(() => _message = 'Unsupported key');
      return true;
    }

    final ShortcutBindingInput binding = ShortcutBindingInput(
      phase: ShortcutBindingPhase.press,
      modifiers: _activeRecordingModifiers(_recordingModifiers),
      key: key,
    );
    ref
        .read(keybindingControllerProvider)
        .setBinding(shortcut: recording, binding: binding);
    setState(() {
      _setPendingMapping(
        recording,
        ShortcutMappingViewBound(
          binding: ShortcutBindingView(
            phase: binding.phase,
            modifiers: binding.modifiers,
            key: binding.key,
            display: _displayBinding(binding),
          ),
        ),
        ShortcutMappingSource.userOverride,
      );
      _recording = null;
      _recordingModifiers.clear();
      _message = 'Saving shortcut...';
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ShortcutSettingsSnapshot>>(
      shortcutSettingsSnapshotProvider,
      (_, AsyncValue<ShortcutSettingsSnapshot> next) {
        next.whenData(_reconcilePendingMappings);
      },
    );
    ref.listen<AsyncValue<ShortcutSettingsCommandResult>>(
      shortcutSettingsCommandResultProvider,
      (_, AsyncValue<ShortcutSettingsCommandResult> next) {
        next.whenData((ShortcutSettingsCommandResult result) {
          if (result.command is ShortcutSettingsRequestLoad) {
            return;
          }
          final String message = switch (result.outcome) {
            ShortcutSettingsCommandOutcome.started => 'Saving shortcut...',
            ShortcutSettingsCommandOutcome.saved => 'Shortcut settings saved',
            ShortcutSettingsCommandOutcome.failed =>
              result.message ?? 'Shortcut settings failed',
          };
          setState(() {
            _message = message;
            if (result.outcome == ShortcutSettingsCommandOutcome.failed) {
              _clearPendingMapping(result.shortcut);
            }
          });
          if (result.outcome == ShortcutSettingsCommandOutcome.failed) {
            ref
                .read(transientOverlayProvider.notifier)
                .showLocalToast(
                  app: 'Keybinds',
                  message: message,
                  urgency: NotificationUrgency.critical,
                );
          }
        });
      },
    );

    final AsyncValue<ShortcutSettingsSnapshot> snapshot = ref.watch(
      shortcutSettingsSnapshotProvider,
    );

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: snapshot.when(
        data: _buildSnapshot,
        loading: () => const Center(child: HyprSpinner.panel()),
        error: (Object error, StackTrace stackTrace) => HyprEmptyState(
          symbol: 'KEYS',
          message: 'Keybindings unavailable: $error',
        ),
      ),
    );
  }

  Widget _buildSnapshot(ShortcutSettingsSnapshot snapshot) {
    final Map<ShortcutSettingCategory, List<ShortcutSettingsRow>> grouped =
        <ShortcutSettingCategory, List<ShortcutSettingsRow>>{};
    for (final ShortcutSettingsRow row in snapshot.rows) {
      grouped.putIfAbsent(row.category, () => <ShortcutSettingsRow>[]).add(row);
    }

    return ListView(
      controller: _scrollController,
      primary: false,
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      children: <Widget>[
        if (_message != null || snapshot.message != null) ...<Widget>[
          _StatusMessage(message: _message ?? snapshot.message!),
          const SizedBox(height: 10),
        ],
        for (final ShortcutSettingCategory category
            in ShortcutSettingCategory.values) ...<Widget>[
          if (grouped[category]?.isNotEmpty ?? false) ...<Widget>[
            HyprSectionLabel(category.label, trailingLine: true),
            const SizedBox(height: 8),
            for (final ShortcutSettingsRow row in grouped[category]!)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: KeybindingRow(
                  row: _projectRow(row),
                  recording: _recording == row.shortcut,
                  recordingDisplay: _recordingDisplay,
                  onRecord: () => _startRecording(row),
                  onDisable: () {
                    setState(() {
                      _setPendingMapping(
                        row.shortcut,
                        const ShortcutMappingViewDisabled(),
                        ShortcutMappingSource.disabled,
                      );
                      _message = 'Saving shortcut...';
                    });
                    ref
                        .read(keybindingControllerProvider)
                        .disable(row.shortcut);
                  },
                  onReset: () {
                    setState(() {
                      _setPendingMapping(
                        row.shortcut,
                        row.defaultMapping,
                        ShortcutMappingSource.builtin,
                      );
                      _message = 'Saving shortcut...';
                    });
                    ref.read(keybindingControllerProvider).reset(row.shortcut);
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ],
        Text(
          'Writing ${snapshot.writablePath}',
          style: HyprTypography.compactMono.copyWith(
            color: HyprColors.textFaint,
            fontSize: HyprTypography.size(10.5),
          ),
        ),
      ],
    );
  }

  String get _recordingDisplay {
    if (_recordingModifiers.isEmpty) {
      return 'Press keys...';
    }
    return <String>[
      for (final ShortcutModifier modifier in _orderedModifiers(
        _recordingModifiers,
      ))
        modifier.label,
      '...',
    ].join('+');
  }
}

class _PendingMapping {
  const _PendingMapping({required this.mapping, required this.source});

  final ShortcutMappingView mapping;
  final ShortcutMappingSource source;
}

class KeybindingRow extends StatelessWidget {
  const KeybindingRow({
    super.key,
    required this.row,
    required this.recording,
    required this.recordingDisplay,
    required this.onRecord,
    required this.onDisable,
    required this.onReset,
  });

  final ShortcutSettingsRow row;
  final bool recording;
  final String recordingDisplay;
  final VoidCallback onRecord;
  final VoidCallback onDisable;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final String display = recording
        ? recordingDisplay
        : row.effectiveMapping.displayLabel;
    final String source = row.source.label;
    final String? conflict = row.conflict?.label;
    final bool disabled = row.effectiveMapping is ShortcutMappingViewDisabled;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: recording
            ? HyprColors.hover
            : Colors.black.withValues(alpha: 0.16),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(9),
          side: BorderSide(
            color: row.conflict == null
                ? HyprColors.popupStroke
                : HyprColors.danger,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        row.label,
                        style: HyprTypography.popRow.copyWith(
                          fontSize: HyprTypography.size(13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        conflict == null
                            ? row.description
                            : 'Conflicts with $conflict',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HyprTypography.popRow.copyWith(
                          color: conflict == null
                              ? HyprColors.textFaint
                              : HyprColors.danger,
                          fontSize: HyprTypography.size(11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                HyprBadge.text(
                  label: display,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  color: recording
                      ? HyprColors.fillStrong
                      : Colors.black.withValues(alpha: 0.12),
                  borderColor: HyprColors.popupStroke.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(5),
                  textColor: recording ? HyprColors.text : HyprColors.textMuted,
                  style: HyprTypography.compactMonoStrong.copyWith(
                    fontSize: HyprTypography.size(11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: <Widget>[
                HyprInlineTag(label: source),
                const Spacer(),
                _RowButton(label: 'Record', onPressed: onRecord),
                const SizedBox(width: 7),
                _RowButton(
                  label: disabled ? 'Restore' : 'Reset',
                  onPressed: onReset,
                ),
                if (!disabled) ...<Widget>[
                  const SizedBox(width: 7),
                  _RowButton(label: 'Disable', onPressed: onDisable),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RowButton extends StatelessWidget {
  const _RowButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return HyprCommandButton(
      label: label,
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      constraints: const BoxConstraints(minHeight: 28),
      textStyle: HyprTypography.compactMonoStrong.copyWith(
        fontSize: HyprTypography.size(10.5),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return HyprBadge.text(
      label: message,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: HyprColors.fillStrong,
      borderColor: HyprColors.popupStroke,
      borderRadius: BorderRadius.circular(7),
      textColor: HyprColors.textMuted,
      style: HyprTypography.popRow.copyWith(
        fontSize: HyprTypography.size(11.5),
      ),
    );
  }
}

extension on ShortcutSettingCategory {
  String get label => switch (this) {
    ShortcutSettingCategory.bar => 'Bar',
    ShortcutSettingCategory.session => 'Session',
    ShortcutSettingCategory.capture => 'Capture',
    ShortcutSettingCategory.audio => 'Audio',
    ShortcutSettingCategory.display => 'Display',
  };
}

extension on ShortcutSettingId {
  String get label => switch (this) {
    ShortcutSettingId.appLauncher => 'App launcher',
    ShortcutSettingId.controls => 'Controls',
    ShortcutSettingId.barSettings => 'Bar settings',
    ShortcutSettingId.sessionLauncher => 'Session launcher',
    ShortcutSettingId.lockSession => 'Lock session',
    ShortcutSettingId.captureRegion => 'Screenshot region',
    ShortcutSettingId.captureWindow => 'Screenshot window',
    ShortcutSettingId.captureFullScreen => 'Screenshot full screen',
    ShortcutSettingId.colorPick => 'Color picker',
    ShortcutSettingId.toggleRecording => 'Toggle recording',
    ShortcutSettingId.toggleDoNotDisturb => 'Toggle DND',
    ShortcutSettingId.toggleNightLight => 'Toggle Night light',
    ShortcutSettingId.toggleCaffeine => 'Toggle Caffeine',
    ShortcutSettingId.volumeUp => 'Volume up',
    ShortcutSettingId.volumeDown => 'Volume down',
    ShortcutSettingId.toggleMute => 'Toggle mute',
    ShortcutSettingId.brightnessUp => 'Brightness up',
    ShortcutSettingId.brightnessDown => 'Brightness down',
  };
}

extension on ShortcutMappingSource {
  String get label => switch (this) {
    ShortcutMappingSource.builtin => 'default',
    ShortcutMappingSource.userOverride => 'override',
    ShortcutMappingSource.disabled => 'disabled',
  };
}

extension on ShortcutMappingView {
  String get displayLabel => switch (this) {
    ShortcutMappingViewBound(:final binding) => binding.display,
    ShortcutMappingViewDisabled() => 'Disabled',
    _ => 'Unknown',
  };
}

String _displayBinding(ShortcutBindingInput binding) {
  return <String>[
    for (final ShortcutModifier modifier in binding.modifiers) modifier.label,
    binding.key,
  ].join('+');
}

extension on ShortcutModifier {
  String get label => switch (this) {
    ShortcutModifier.logo => 'LOGO',
    ShortcutModifier.ctrl => 'CTRL',
    ShortcutModifier.shift => 'SHIFT',
    ShortcutModifier.alt => 'ALT',
    ShortcutModifier.num => 'NUM',
  };
}

ShortcutModifier? _modifierFor(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.meta ||
      key == LogicalKeyboardKey.metaLeft ||
      key == LogicalKeyboardKey.metaRight ||
      key == LogicalKeyboardKey.superKey) {
    return ShortcutModifier.logo;
  }
  if (key == LogicalKeyboardKey.control ||
      key == LogicalKeyboardKey.controlLeft ||
      key == LogicalKeyboardKey.controlRight) {
    return ShortcutModifier.ctrl;
  }
  if (key == LogicalKeyboardKey.shift ||
      key == LogicalKeyboardKey.shiftLeft ||
      key == LogicalKeyboardKey.shiftRight) {
    return ShortcutModifier.shift;
  }
  if (key == LogicalKeyboardKey.alt ||
      key == LogicalKeyboardKey.altLeft ||
      key == LogicalKeyboardKey.altRight) {
    return ShortcutModifier.alt;
  }
  return null;
}

List<ShortcutModifier> _activeRecordingModifiers(
  Set<ShortcutModifier> cachedModifiers,
) {
  final Set<LogicalKeyboardKey> pressed =
      HardwareKeyboard.instance.logicalKeysPressed;
  return _orderedModifiers(<ShortcutModifier>{
    ...cachedModifiers,
    if (pressed.contains(LogicalKeyboardKey.meta) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight) ||
        pressed.contains(LogicalKeyboardKey.superKey))
      ShortcutModifier.logo,
    if (pressed.contains(LogicalKeyboardKey.control) ||
        pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight))
      ShortcutModifier.ctrl,
    if (pressed.contains(LogicalKeyboardKey.shift) ||
        pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight))
      ShortcutModifier.shift,
    if (pressed.contains(LogicalKeyboardKey.alt) ||
        pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight))
      ShortcutModifier.alt,
  });
}

List<ShortcutModifier> _orderedModifiers(Set<ShortcutModifier> modifiers) {
  return <ShortcutModifier>[
    if (modifiers.contains(ShortcutModifier.logo)) ShortcutModifier.logo,
    if (modifiers.contains(ShortcutModifier.ctrl)) ShortcutModifier.ctrl,
    if (modifiers.contains(ShortcutModifier.shift)) ShortcutModifier.shift,
    if (modifiers.contains(ShortcutModifier.alt)) ShortcutModifier.alt,
    if (modifiers.contains(ShortcutModifier.num)) ShortcutModifier.num,
  ];
}

String? _keyLabel(LogicalKeyboardKey key) {
  final String? special = _specialKeyLabel(key);
  if (special != null) {
    return special;
  }
  final String label = key.keyLabel.trim();
  if (label.isEmpty) {
    return null;
  }
  if (label.startsWith('XF86')) {
    return label;
  }
  if (label.length == 1) {
    return label.toUpperCase();
  }
  return label.replaceAll(' ', '').toUpperCase();
}

String? _specialKeyLabel(LogicalKeyboardKey key) {
  return switch (key) {
    LogicalKeyboardKey.escape => 'ESCAPE',
    LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter => 'RETURN',
    LogicalKeyboardKey.tab => 'TAB',
    LogicalKeyboardKey.space => 'SPACE',
    LogicalKeyboardKey.backspace => 'BACKSPACE',
    LogicalKeyboardKey.delete => 'DELETE',
    LogicalKeyboardKey.arrowUp => 'UP',
    LogicalKeyboardKey.arrowDown => 'DOWN',
    LogicalKeyboardKey.arrowLeft => 'LEFT',
    LogicalKeyboardKey.arrowRight => 'RIGHT',
    LogicalKeyboardKey.printScreen => 'Print',
    LogicalKeyboardKey.f1 => 'F1',
    LogicalKeyboardKey.f2 => 'F2',
    LogicalKeyboardKey.f3 => 'F3',
    LogicalKeyboardKey.f4 => 'F4',
    LogicalKeyboardKey.f5 => 'F5',
    LogicalKeyboardKey.f6 => 'F6',
    LogicalKeyboardKey.f7 => 'F7',
    LogicalKeyboardKey.f8 => 'F8',
    LogicalKeyboardKey.f9 => 'F9',
    LogicalKeyboardKey.f10 => 'F10',
    LogicalKeyboardKey.f11 => 'F11',
    LogicalKeyboardKey.f12 => 'F12',
    _ => null,
  };
}
