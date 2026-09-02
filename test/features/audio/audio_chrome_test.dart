import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/features/audio/audio_chrome.dart';

void main() {
  test('audio decibel readout follows the cubic volume curve', () {
    // The figures pavucontrol shows for the same slider positions.
    expect(audioDecibelReadout(100, muted: false), '0.0');
    expect(audioDecibelReadout(50, muted: false), '−18.1');
    expect(audioDecibelReadout(25, muted: false), '−36.1');
    expect(audioDecibelReadout(0, muted: false), '−∞');
    expect(audioDecibelReadout(80, muted: true), '−∞');
  });

  test('audio decibels stay finite at the bottom of the scale', () {
    expect(audioDecibels(1), closeTo(-120, 0.1));
    expect(audioDecibelReadout(1, muted: false), '−120');
  });
}
