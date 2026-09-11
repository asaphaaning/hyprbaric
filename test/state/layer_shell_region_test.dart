import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/layer_shell_hit_region.dart';
import 'package:hyprbaric/src/native/layer_shell_api.g.dart';

const BasicMessageChannel<Object?> _regionChannel =
    BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.hyprbaric.NativeLayerShellHostApi.setRegion',
      NativeLayerShellHostApi.pigeonChannelCodec,
    );

/// Answers the region channel so delivery succeeds wherever the test runs.
void _answerRegionChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(_regionChannel.name, (ByteData? message) async {
        return _regionChannel.codec.encodeMessage(<Object?>[null]);
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(_regionChannel.name, null),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(_answerRegionChannel);

  test('the open menu region is observable without a compositor', () async {
    final LayerShellRegionManager manager = LayerShellRegionManager(
      barHeight: 40,
    );
    addTearDown(manager.dispose);

    expect(manager.menuRegion.value, isNull);

    final Object owner = Object();
    const Rect rect = Rect.fromLTWH(400, 48, 214, 320);
    await manager.updateRegion(
      owner: owner,
      menuRect: rect,
      debugLabel: 'test-open',
    );

    expect(manager.menuRegion.value?.rect, rect);

    await manager.updateRegion(
      owner: owner,
      menuRect: null,
      debugLabel: 'test-closed',
    );

    expect(manager.menuRegion.value, isNull);
  });

  test('repeat reports of the same region do not notify twice', () async {
    final LayerShellRegionManager manager = LayerShellRegionManager(
      barHeight: 40,
    );
    addTearDown(manager.dispose);

    int notifications = 0;
    manager.menuRegion.addListener(() => notifications++);

    const Rect rect = Rect.fromLTWH(400, 48, 214, 320);
    final Object owner = Object();
    await manager.updateRegion(
      owner: owner,
      menuRect: rect,
      debugLabel: 'test-open',
    );
    await manager.updateRegion(
      owner: owner,
      menuRect: rect,
      debugLabel: 'test-open-again',
    );

    expect(notifications, 1);
  });
}
