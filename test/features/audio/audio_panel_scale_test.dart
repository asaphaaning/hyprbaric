import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/bindings/bindings.dart';
import 'package:hyprbaric/src/features/audio/audio_panel.dart';

const AudioStatus _status = AudioStatusAvailable(
  output: AudioEndpoint(
    id: 'out',
    name: 'EVO4 Analog Surround 4.0',
    kind: AudioEndpointKind.output,
    volume: 62,
    muted: false,
  ),
  input: AudioEndpoint(
    id: 'in',
    name: 'Built-in Mic',
    kind: AudioEndpointKind.input,
    volume: 80,
    muted: false,
  ),
);

Widget _panel(double scale) => ProviderScope(
  child: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: AudioPanel(
            borderRadius: BorderRadius.circular(8),
            status: const AsyncData<AudioStatus>(_status),
            brightnessStatus: const AsyncData<BrightnessStatus>(
              BrightnessStatusAvailable(device: 'eDP-1', value: 72),
            ),
            onSetVolume: (_, _) {},
            onSetMuted: (_, {required bool muted}) {},
            onSetBrightness: (_) {},
            onOpenMixer: () {},
          ),
        ),
      ),
    ),
  ),
);

void main() {
  for (final double scale in <double>[1, 1.15, 1.3, 1.5, 2]) {
    testWidgets('mixer console absorbs text scale $scale', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_panel(scale));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  }
}
