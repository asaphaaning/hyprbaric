import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/widgets/primitives/primitives.dart';

void main() {
  const Duration hold = Duration(milliseconds: 30);

  test('an exact backend echo clears the preview immediately', () {
    final HyprPreviewValue preview = HyprPreviewValue(hold: hold);
    addTearDown(preview.dispose);

    preview.show(47);
    expect(preview.settle(62), 47);
    expect(preview.settle(47), 47);
    expect(preview.isActive, isFalse);
    expect(preview.settle(47), 47);
  });

  test('a backend that never echoes still wins once the hold expires', () async {
    final HyprPreviewValue preview = HyprPreviewValue(hold: hold);
    addTearDown(preview.dispose);
    int notifications = 0;
    preview.addListener(() => notifications += 1);

    // PipeWire rounds percentages, so 48 is answered with 47 and the two never
    // meet. Waiting for an exact match would strand the readout on 48 forever.
    preview.show(48);
    expect(preview.settle(47), 48);

    await Future<void>.delayed(hold * 2);

    expect(preview.isActive, isFalse);
    expect(preview.settle(47), 47);
    expect(notifications, greaterThan(1));
  });

  test('the hold restarts while the value is still moving', () async {
    final HyprPreviewValue preview = HyprPreviewValue(hold: hold);
    addTearDown(preview.dispose);

    preview.show(10);
    await Future<void>.delayed(hold ~/ 2);
    preview.show(20);
    await Future<void>.delayed(hold ~/ 2);

    expect(preview.settle(99), 20);
  });

  test('a preview is dropped when its scope changes', () {
    final HyprPreviewValue preview = HyprPreviewValue(hold: hold);
    addTearDown(preview.dispose);

    preview.show(30, scope: 'sink-a');
    expect(preview.settle(10, scope: 'sink-a'), 30);
    expect(preview.settle(10, scope: 'sink-b'), 10);
    expect(preview.isActive, isFalse);
  });
}
