import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/bindings/bindings.dart';
import 'package:hyprbaric/src/features/audio/audio_output_selection.dart'
    as selection;

const AudioOutputId _usb = AudioOutputId(name: 'usb');
const AudioOutputId _speakers = AudioOutputId(name: 'speakers');

AudioOutputs _outputs(AudioOutputId selected) =>
    AudioOutputsAvailable(devices: const <AudioOutput>[], selected: selected);

AudioCommandResult _rejected(AudioOutputId id) => AudioCommandResultFailed(
  command: AudioCommandSelectOutput(id: id),
  message: 'Device disconnected',
);

void main() {
  test('only the requested output can confirm a selection', () {
    final selection.State state = selection.Selecting(_speakers);
    expect(state.confirm(_usb), same(state));
    expect(state.confirm(null), same(state));
    expect(state.confirm(_speakers), isA<selection.Idle>());
  });

  test('unrelated commands and outputs cannot reject a selection', () {
    final selection.State state = selection.Selecting(_speakers);
    expect(state.reject(_rejected(_usb)), same(state));
    expect(
      state.reject(
        const AudioCommandResultFailed(
          command: AudioCommandSetMuted(
            kind: AudioEndpointKind.output,
            muted: true,
          ),
          message: 'Mute failed',
        ),
      ),
      same(state),
    );
    expect(
      state.reject(_rejected(_speakers)),
      isA<selection.Failed>().having(
        (state) => state.message,
        'message',
        'Device disconnected',
      ),
    );
  });

  test('an expired attempt cannot fail a retry for the same output', () {
    final selection.Selecting previous = selection.Selecting(_speakers);
    final selection.State retry = selection.Selecting(_speakers);
    expect(previous.expire(previous), isA<selection.Failed>());
    expect(retry.expire(previous), same(retry));
    expect(const selection.Idle().expire(previous), isA<selection.Idle>());
  });

  test('clearing feedback preserves an in-flight selection', () {
    final selection.State selecting = selection.Selecting(_speakers);
    expect(selecting.clearFailure(), same(selecting));
    expect(
      const selection.Failed('Disconnected').clearFailure(),
      isA<selection.Idle>(),
    );
  });

  testWidgets('unrelated backend updates preserve the original deadline', (
    tester,
  ) async {
    final control = selection.Control(timeout: const Duration(seconds: 10));
    addTearDown(control.dispose);
    control.select(_speakers);
    await tester.pump(const Duration(seconds: 6));
    expect(
      control.receive(_outputs(_usb), result: _rejected(_usb)),
      selection.Confirmation.none,
    );
    control.clearFailure();
    await tester.pump(const Duration(seconds: 4));
    expect(control.state, isA<selection.Failed>());
  });

  testWidgets('confirmation wins over a failure and cancels the deadline', (
    tester,
  ) async {
    final control = selection.Control(timeout: const Duration(seconds: 10));
    addTearDown(control.dispose);
    control.select(_speakers);
    expect(
      control.receive(_outputs(_speakers), result: _rejected(_speakers)),
      selection.Confirmation.received,
    );
    expect(control.state, isA<selection.Idle>());
    await tester.pump(const Duration(seconds: 11));
    expect(control.state, isA<selection.Idle>());
  });

  testWidgets('retry gets a fresh deadline after a rejection', (tester) async {
    final control = selection.Control(timeout: const Duration(seconds: 10));
    addTearDown(control.dispose);
    control.select(_speakers);
    await tester.pump(const Duration(seconds: 6));
    control.receive(_outputs(_usb), result: _rejected(_speakers));
    expect(control.state, isA<selection.Failed>());
    control.select(_speakers);
    await tester.pump(const Duration(seconds: 4));
    expect(control.state, isA<selection.Selecting>());
    await tester.pump(const Duration(seconds: 6));
    expect(control.state, isA<selection.Failed>());
  });

  testWidgets('discovery loss cancels without falsely confirming selection', (
    tester,
  ) async {
    final control = selection.Control(timeout: const Duration(seconds: 10));
    addTearDown(control.dispose);
    control.select(_speakers);
    expect(
      control.receive(const AudioOutputsUnavailable(message: 'Offline')),
      selection.Confirmation.none,
    );
    await tester.pump(const Duration(seconds: 11));
    expect(control.state, isA<selection.Idle>());
  });

  testWidgets('disposing the controller cancels its pending timeout', (
    tester,
  ) async {
    final control = selection.Control(timeout: const Duration(seconds: 10));
    int notifications = 0;
    control.addListener(() => notifications++);
    control.select(_speakers);
    control.dispose();
    await tester.pump(const Duration(seconds: 11));
    expect(notifications, 1);
    expect(tester.takeException(), isNull);
  });
}
