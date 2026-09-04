import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/widget_catalog.dart';

void main() {
  test('catalog exposes normalized audio meter levels', () {
    const AudioMeterLevels levels = AudioMeterLevels(output: .75, input: .42);

    expect(levels.output, .75);
    expect(levels.input, .42);
  });
}
