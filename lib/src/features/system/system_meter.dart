import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';
import '../audio/audio_chrome.dart';
import '../audio/audio_meter.dart';
import 'system_console.dart';
import 'system_icon.dart';

/// One labelled occupancy ladder in the system popover.
class SystemMeterRow extends StatelessWidget {
  const SystemMeterRow({
    super.key,
    required this.symbol,
    required this.label,
    required this.value,
    required this.ratio,
  });

  final SystemSymbol symbol;
  final String label;
  final String value;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            SystemIcon(symbol, color: HyprInstrumentColors.secondary, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: SystemConsole.label.copyWith(
                  color: HyprInstrumentColors.secondary,
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Text(value, style: SystemConsole.value.copyWith(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 7),
        AudioMeter(
          level: ratio.clamp(0, 1).toDouble(),
          accent: AudioMixerColors.output,
          rail: true,
        ),
      ],
    );
  }
}

/// Footer measurement shared with the battery instrument's metric strip.
class SystemStat extends StatelessWidget {
  const SystemStat({
    super.key,
    required this.symbol,
    required this.value,
    required this.label,
  });

  final SystemSymbol symbol;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SystemGlyphWell(symbol: symbol),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: SystemConsole.value.copyWith(fontSize: 14.5),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: SystemConsole.label.copyWith(
                  fontSize: 10.5,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
