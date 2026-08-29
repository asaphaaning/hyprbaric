import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/bindings/bindings.dart';
import 'package:hyprbaric/src/features/rust_commands.dart';
import 'package:hyprbaric/src/features/setup/setup_guide_host.dart';
import 'package:hyprbaric/src/features/setup/setup_guide_state.dart';
import 'package:hyprbaric/src/features/setup/setup_guide_style.dart';
import 'package:hyprbaric/src/layer_shell_controller.dart';
import 'package:hyprbaric/src/native/layer_shell_api.g.dart';
import 'package:hyprbaric/src/state/providers.dart';
import 'package:hyprbaric/src/theme/hypr_palette.dart';
import 'package:hyprbaric/src/widgets/surfaces/hypr_typography.dart';
import 'package:hyprbaric/src/widgets/transient_overlays.dart';

const BasicMessageChannel<Object?> _keyboardModeChannel =
    BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.hyprbaric.NativeLayerShellHostApi.setKeyboardMode',
      NativeLayerShellHostApi.pigeonChannelCodec,
    );

void main() {
  testWidgets('only one host opens the guide automatically', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          setupGuideAutomaticHostProvider.overrideWithValue(true),
          setupStatusProvider.overrideWith(
            (_) => Stream<SetupStatus>.value(
              const SetupStatus(state: SetupState.required),
            ),
          ),
        ],
        child: _surface(
          const Stack(
            fit: StackFit.expand,
            children: <Widget>[SetupGuideHost(), SetupGuideHost()],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Every native view builds its own host against the same container, and
    // the status is replayed to each. Without an election a multi-monitor
    // session would open the journey on every bar at once.
    expect(find.byKey(const ValueKey<String>('setup-guide')), findsOneWidget);
  });

  testWidgets('required setup opens once on the automatic host', (
    WidgetTester tester,
  ) async {
    final _RecordingDispatcher dispatcher = _RecordingDispatcher();
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          setupGuideAutomaticHostProvider.overrideWithValue(true),
          setupStatusProvider.overrideWith(
            (_) => Stream<SetupStatus>.value(
              const SetupStatus(state: SetupState.required),
            ),
          ),
          rustCommandDispatcherProvider.overrideWithValue(dispatcher),
        ],
        child: _surface(const SetupGuideHost()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('setup-guide')), findsOneWidget);
    expect(find.text('Welcome to\nHyprbaric'), findsOneWidget);

    await tester.tap(find.text('SKIP'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('setup-guide')), findsNothing);
    expect(
      dispatcher.intents.map((RustIntent intent) => intent.debugLabel),
      contains('setup_complete:skipped'),
    );
  });

  testWidgets('manual request opens setup on a non-automatic host', (
    WidgetTester tester,
  ) async {
    int openingCount = 0;
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          setupGuideAutomaticHostProvider.overrideWithValue(false),
          setupStatusProvider.overrideWith(
            (_) => Stream<SetupStatus>.value(
              const SetupStatus(state: SetupState.required),
            ),
          ),
        ],
        child: _surface(
          Stack(
            fit: StackFit.expand,
            children: <Widget>[
              SetupGuideHost(onReady: () => openingCount += 1),
              const _ManualLaunchButton(),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('setup-guide')), findsNothing);

    await tester.tap(find.text('Launch'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('setup-guide')), findsOneWidget);
    expect(openingCount, 1);
    final Finder scrim = find.byKey(
      const ValueKey<String>('setup-guide-scrim'),
    );
    expect(tester.getTopLeft(scrim).dy, 43);
    expect(tester.getSize(scrim), const Size(1200, 757));
  });

  testWidgets('guide preserves the v6 split geometry and control vocabulary', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          setupGuideAutomaticHostProvider.overrideWithValue(true),
          setupStatusProvider.overrideWith(
            (_) => Stream<SetupStatus>.value(
              const SetupStatus(state: SetupState.required),
            ),
          ),
        ],
        child: _surface(const SetupGuideHost()),
      ),
    );
    await tester.pumpAndSettle();

    final Finder card = find.byKey(const ValueKey<String>('setup-guide'));
    final Finder preview = find.byKey(
      const ValueKey<String>('setup-guide-preview'),
    );
    expect(tester.getSize(card), const Size(980, 600));
    expect(tester.getSize(preview), const Size(441, 600));
    expect(find.text('LIVE PREVIEW'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('setup-guide-seam')),
      findsOneWidget,
    );

    await tester.tap(find.text('GET STARTED'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('setup-guide-amount-slider')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('setup-guide-hue-slider')),
      findsNothing,
    );

    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('setup-guide-hue-slider')),
      findsOneWidget,
    );
  });

  testWidgets('escape skips the guide from any step', (
    WidgetTester tester,
  ) async {
    final _RecordingDispatcher dispatcher = _RecordingDispatcher();
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          setupGuideAutomaticHostProvider.overrideWithValue(true),
          setupStatusProvider.overrideWith(
            (_) => Stream<SetupStatus>.value(
              const SetupStatus(state: SetupState.required),
            ),
          ),
          rustCommandDispatcherProvider.overrideWithValue(dispatcher),
        ],
        child: _surface(const SetupGuideHost()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GET STARTED'));
    await tester.pumpAndSettle();
    expect(find.text('Frosted, or flat?'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('setup-guide')), findsNothing);
    expect(
      dispatcher.intents.map((RustIntent intent) => intent.debugLabel),
      contains('setup_complete:skipped'),
    );
  });

  testWidgets('a failed persist toasts and reopens for a retry', (
    WidgetTester tester,
  ) async {
    final _RecordingDispatcher dispatcher = _RecordingDispatcher();
    final StreamController<SetupCommandResult> results =
        StreamController<SetupCommandResult>();
    addTearDown(results.close);
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          setupGuideAutomaticHostProvider.overrideWithValue(true),
          setupStatusProvider.overrideWith(
            (_) => Stream<SetupStatus>.value(
              const SetupStatus(state: SetupState.required),
            ),
          ),
          setupCommandResultProvider.overrideWith((_) => results.stream),
          rustCommandDispatcherProvider.overrideWithValue(dispatcher),
        ],
        child: _surface(
          Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const SetupGuideHost(),
              ToastHost(barHeight: 40, onToastPressed: (_) {}),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('SKIP'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('setup-guide')), findsNothing);

    results.add(
      const SetupCommandResultFailed(
        command: SetupCommandComplete(outcome: SetupOutcome.skipped),
        message: 'disk full',
      ),
    );
    // Two short pumps: one delivers the result stream event, one rebuilds.
    // A settle would advance past the toast lifetime and dismiss it.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey<String>('setup-guide')), findsOneWidget);
    expect(
      find.text('Could not save setup completion: disk full'),
      findsOneWidget,
    );
  });

  testWidgets('skip restores the appearance trial values', (
    WidgetTester tester,
  ) async {
    final _RecordingDispatcher dispatcher = _RecordingDispatcher();
    final StreamController<AppearanceStatus> appearance =
        StreamController<AppearanceStatus>();
    addTearDown(appearance.close);
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          setupGuideAutomaticHostProvider.overrideWithValue(false),
          setupStatusProvider.overrideWith(
            (_) => Stream<SetupStatus>.value(
              const SetupStatus(state: SetupState.complete),
            ),
          ),
          appearanceStatusProvider.overrideWith((_) => appearance.stream),
          rustCommandDispatcherProvider.overrideWithValue(dispatcher),
        ],
        child: _surface(
          const Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _ManualLaunchButton(),
              // The production bar always watches appearance, keeping the
              // status stream subscribed. Mirror that so the snapshot taken
              // at guide open observes the already-delivered status.
              _AppearanceWatcher(),
              SetupGuideHost(),
            ],
          ),
        ),
      ),
    );
    appearance.add(
      const AppearanceStatus(
        position: AppearancePosition.bottom,
        monitor: AppearanceMonitorTargetPrimary(),
        opacity: 100,
        cornerRadius: 12,
        accentHue: 300,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Launch'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('setup-guide')), findsOneWidget);

    appearance.add(
      const AppearanceStatus(
        position: AppearancePosition.top,
        monitor: AppearanceMonitorTargetPrimary(),
        opacity: 50,
        cornerRadius: 12,
        accentHue: 100,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('SKIP'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('setup-guide')), findsNothing);
    final List<String> labels = dispatcher.intents
        .map((RustIntent intent) => intent.debugLabel)
        .toList(growable: false);
    expect(labels, contains('setup_complete:skipped'));
    expect(labels, contains('appearance_opacity:100'));
    expect(labels, contains('appearance_accent_hue:300'));
    expect(labels, contains('appearance_position:bottom'));
  });

  testWidgets('keyboard claims survive overlapping overlays', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final List<String> modes = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(_keyboardModeChannel.name, (
          ByteData? message,
        ) async {
          final Object? decoded = _keyboardModeChannel.codec.decodeMessage(
            message,
          );
          final List<Object?> arguments = decoded! as List<Object?>;
          modes.add((arguments.single! as NativeLayerShellKeyboardMode).name);
          return _keyboardModeChannel.codec.encodeMessage(<Object?>[null]);
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(_keyboardModeChannel.name, null);
    });

    try {
      // Claims are scoped to the view's controller: one fresh controller
      // behaves like one fresh bar, with no claims leaking in.
      final LayerShellController controller =
          LayerShellController.defaultView();
      await controller.claimKeyboard('settings-modal');
      await controller.claimKeyboard('setup-guide');
      // The settings modal closes underneath the guide. Its teardown must
      // not release the guide's still-open claim.
      await controller.releaseKeyboard('settings-modal');

      expect(modes, <String>['exclusive', 'exclusive']);

      await controller.releaseKeyboard('setup-guide');

      expect(modes, <String>['exclusive', 'exclusive', 'none']);
    } finally {
      // Invariants are verified before tearDowns run, so the platform
      // override must be restored in the body itself.
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('setup guide text roles draw from the shared type vocabulary', () {
    final List<TextStyle> roles = <TextStyle>[
      SetupGuideTypography.stepTitle,
      SetupGuideTypography.stepSubtitle,
      SetupGuideTypography.cardTitle,
      SetupGuideTypography.rowTitle,
      SetupGuideTypography.cardSubtitle,
      SetupGuideTypography.summaryRow,
      SetupGuideTypography.glyph(active: true),
      SetupGuideTypography.glyph(active: false),
      setupMono(),
    ];

    for (final TextStyle role in roles) {
      expect(
        role.fontFamily,
        anyOf(HyprTypography.uiFamily, HyprTypography.monoFamily),
        reason: 'roles must not hardcode a family literal',
      );
      expect(role.fontSize, isNotNull);
      expect(
        role.fontSize,
        HyprTypography.size(role.fontSize!),
        reason: 'sizes must be snapped to the device pixel grid',
      );
    }
  });
}

Widget _surface(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      extensions: const <ThemeExtension<dynamic>>[HyprPalette.fallback],
    ),
    home: Scaffold(body: Stack(children: <Widget>[child])),
  );
}

class _ManualLaunchButton extends ConsumerWidget {
  const _ManualLaunchButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () => ref.read(setupGuideRequestProvider.notifier).show(),
      child: const Text('Launch'),
    );
  }
}

class _AppearanceWatcher extends ConsumerWidget {
  const _AppearanceWatcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(currentAppearanceProvider);
    return const SizedBox.shrink();
  }
}

class _RecordingDispatcher extends RustCommandDispatcher {
  final List<RustIntent> intents = <RustIntent>[];

  @override
  void dispatch(RustIntent intent) {
    intents.add(intent);
  }
}
