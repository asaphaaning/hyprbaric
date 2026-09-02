import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/widgets/hypr_surface.dart';

void main() {
  test('one audio ramp governs every level readout', () {
    const HyprLevelRamp ramp = HyprLevelRamp.audio;

    expect(ramp.colorAt(0), HyprColors.levelNominal);
    expect(ramp.colorAt(ramp.warningAt - 0.01), HyprColors.levelNominal);
    expect(ramp.colorAt(ramp.warningAt), HyprColors.levelWarning);
    expect(ramp.colorAt(ramp.peakAt - 0.01), HyprColors.levelWarning);
    expect(ramp.colorAt(ramp.peakAt), HyprColors.levelPeak);
    expect(ramp.colorAt(1), HyprColors.levelPeak);
  });

  test('the peak band is the shared danger colour', () {
    expect(HyprLevelRamp.audio.peak, HyprColors.danger);
  });

  test('tinting the nominal band leaves the escalation intact', () {
    const HyprLevelRamp tinted = HyprLevelRamp.audio;
    final HyprLevelRamp channel = tinted.withNominal(HyprColors.accent);

    expect(channel.colorAt(0), HyprColors.accent);
    expect(channel.colorAt(1), tinted.peak);
    expect(channel.warningAt, tinted.warningAt);
    expect(channel.peakAt, tinted.peakAt);
  });

  test('brightness reads as warmth rather than escalation', () {
    const HyprLevelRamp ramp = HyprLevelRamp.brightness;

    expect(ramp.colorAt(0), HyprColors.lampCool);
    expect(ramp.colorAt(1), HyprColors.lampHot);
    expect(ramp.warningAt, lessThan(HyprLevelRamp.audio.warningAt));
  });
}
