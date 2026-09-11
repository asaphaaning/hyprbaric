import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/bindings/bindings.dart';
import 'package:hyprbaric/src/features/audio/audio_mixer_layout.dart';
import 'package:hyprbaric/src/features/audio/audio_output_menu.dart';
import 'package:hyprbaric/src/features/audio/audio_output_picker.dart';

const AudioOutputId _usb = AudioOutputId(name: 'usb');
const AudioOutputId _speakers = AudioOutputId(name: 'speakers');
const List<AudioOutput> _devices = <AudioOutput>[
  AudioOutput(id: _usb, name: 'EVO4'),
  AudioOutput(id: _speakers, name: 'Built-in Speakers'),
];
const AudioEndpoint _endpoint = AudioEndpoint(
  kind: AudioEndpointKind.output,
  name: 'EVO4',
  volume: 19,
  muted: false,
);

Widget _picker({
  AudioOutputs outputs = const AudioOutputsAvailable(
    devices: _devices,
    selected: _usb,
  ),
  AudioCommandResult? result,
  required ValueChanged<AudioOutputId> select,
}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 354,
      child: AudioOutputPicker(
        output: _endpoint,
        outputs: outputs,
        commandResult: result,
        onSelected: select,
        child: const SizedBox(height: 320),
      ),
    ),
  ),
);

AudioCommandResult _failed(String message) => AudioCommandResultFailed(
  command: const AudioCommandSelectOutput(id: _speakers),
  message: message,
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byType(AudioOutputSelector));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('selects a stable output and waits for backend confirmation', (
    tester,
  ) async {
    final List<AudioOutputId> requests = <AudioOutputId>[];
    await tester.pumpWidget(_picker(select: requests.add));
    await _open(tester);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.tap(find.text('Built-in Speakers'));
    await tester.pump();
    expect(requests, <AudioOutputId>[_speakers]);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('OUTPUT DEVICE'), findsOneWidget);

    await tester.pumpWidget(
      _picker(
        outputs: const AudioOutputsAvailable(
          devices: _devices,
          selected: _speakers,
        ),
        select: requests.add,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('OUTPUT DEVICE'), findsNothing);
    await _open(tester);
    final AudioOutputChoice selected = tester.widget<AudioOutputChoice>(
      find.ancestor(
        of: find.text('Built-in Speakers'),
        matching: find.byType(AudioOutputChoice),
      ),
    );
    expect(selected.selected, isTrue);
  });

  testWidgets('selecting the current device closes without a command', (
    tester,
  ) async {
    final List<AudioOutputId> requests = <AudioOutputId>[];
    await tester.pumpWidget(_picker(select: requests.add));
    await _open(tester);
    await tester.tap(find.widgetWithText(TextButton, 'EVO4'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    expect(find.text('OUTPUT DEVICE'), findsNothing);
  });

  testWidgets('a disconnected-device failure is visible and can be retried', (
    tester,
  ) async {
    final List<AudioOutputId> requests = <AudioOutputId>[];
    await tester.pumpWidget(_picker(select: requests.add));
    await _open(tester);
    for (int attempt = 0; attempt < 2; attempt++) {
      await tester.tap(find.text('Built-in Speakers'));
      await tester.pump();
      await tester.pumpWidget(
        _picker(select: requests.add, result: _failed('Device disconnected')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Device disconnected'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    }
    expect(requests, <AudioOutputId>[_speakers, _speakers]);
  });

  testWidgets(
    'unconfirmed selection times out without leaving controls disabled',
    (tester) async {
      await tester.pumpWidget(_picker(select: (_) {}));
      await _open(tester);
      await tester.tap(find.text('Built-in Speakers'));
      await tester.pump(const Duration(seconds: 16));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.text('Output change was not confirmed. Please try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('keyboard opens, selects and dismisses the chooser', (
    tester,
  ) async {
    final List<AudioOutputId> requests = <AudioOutputId>[];
    await tester.pumpWidget(_picker(select: requests.add));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('OUTPUT DEVICE'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(requests, <AudioOutputId>[_speakers]);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('OUTPUT DEVICE'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('discovery failure does not hide the current endpoint', (
    tester,
  ) async {
    await tester.pumpWidget(
      _picker(
        outputs: const AudioOutputsUnavailable(
          message: 'PipeWire did not respond',
        ),
        select: (_) {},
      ),
    );
    await _open(tester);
    expect(find.text('EVO4'), findsOneWidget);
    expect(find.text('PipeWire did not respond'), findsOneWidget);
  });
}
