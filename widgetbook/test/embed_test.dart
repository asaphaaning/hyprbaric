import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/audio_embed.dart';
import 'package:hyprbaric_widgetbook/audio/audio_mixer_preview.dart';
import 'package:hyprbaric_widgetbook/embed/embed_theme.dart';

void main() {
  test('audio meter dance remains normalized and changes by channel', () {
    final AudioMeterDance first = AudioMeterDance.sample(0);
    final AudioMeterDance later = AudioMeterDance.sample(.42);

    for (final double level in <double>[
      first.output,
      first.input,
      later.output,
      later.input,
    ]) {
      expect(level, inInclusiveRange(0, 1));
    }

    expect(later.output, isNot(later.input));
    expect(later.output, isNot(first.output));
  });

  testWidgets('embed preview composes the production audio panel', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: embedTheme,
        home: const AudioMixerPreview(animateMeters: false),
      ),
    );

    expect(find.byType(AudioPanel), findsOneWidget);
  });
}
