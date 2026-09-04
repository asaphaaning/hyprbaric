import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../audio/audio_fixtures.dart';
import '../../catalog/catalog_frame.dart';

@UseCase(
  name: 'Endpoint strips',
  type: AudioChannelStrip,
  path: '[Building blocks]/Audio',
)
Widget buildAudioChannelStripStates(BuildContext context) {
  return CatalogFrame(
    width: 500,
    child: SizedBox(
      height: 265,
      child: Row(
        children: <Widget>[
          Expanded(
            child: AudioChannelStrip(
              channel: AudioMixerChannel.output,
              endpoint: AudioFixtures.output,
              fallbackName: 'No output device',
              onSetVolume: _ignoreVolume,
              onSetMuted: _ignoreMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AudioChannelStrip(
              channel: AudioMixerChannel.input,
              endpoint: AudioFixtures.muted.output,
              fallbackName: 'No input device',
              onSetVolume: _ignoreVolume,
              onSetMuted: _ignoreMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AudioChannelStrip(
              channel: AudioMixerChannel.input,
              endpoint: null,
              fallbackName: 'No input device',
              onSetVolume: _ignoreVolume,
              onSetMuted: _ignoreMuted,
            ),
          ),
        ],
      ),
    ),
  );
}

@UseCase(
  name: 'Fader states',
  type: AudioFader,
  path: '[Building blocks]/Audio',
)
Widget buildAudioFaderStates(BuildContext context) {
  return CatalogFrame(
    width: 430,
    child: SizedBox(
      height: 190,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          AudioFader(
            endpoint: AudioFixtures.updateEndpoint(
              AudioFixtures.output,
              volume: 28,
            ),
            accent: const Color(0xFF3BCB7C),
            onPreviewVolume: _ignoreInt,
            onSetVolume: _ignoreVolume,
          ),
          AudioFader(
            endpoint: AudioFixtures.output,
            accent: const Color(0xFF3BCB7C),
            onPreviewVolume: _ignoreInt,
            onSetVolume: _ignoreVolume,
          ),
          AudioFader(
            endpoint: AudioFixtures.updateEndpoint(
              AudioFixtures.input,
              volume: 92,
            ),
            accent: const Color(0xFF43D879),
            onPreviewVolume: _ignoreInt,
            onSetVolume: _ignoreVolume,
          ),
          const AudioDisabledFader(accent: Color(0xFF43D879)),
        ],
      ),
    ),
  );
}

@UseCase(
  name: 'Decibel states',
  type: AudioDbReadout,
  path: '[Building blocks]/Audio',
)
Widget buildAudioDbReadoutStates(BuildContext context) {
  return CatalogFrame(
    width: 500,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Row(
          children: <Widget>[
            Expanded(
              child: AudioDbReadout(
                value: 72,
                muted: false,
                accent: Color(0xFF3BCB7C),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: AudioDbReadout(
                value: 72,
                muted: true,
                accent: Color(0xFF43D879),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: AudioDbReadout(
                value: null,
                muted: true,
                accent: Color(0xFF43D879),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

@UseCase(
  name: 'Mute states',
  type: AudioMuteButton,
  path: '[Building blocks]/Audio',
)
Widget buildAudioMuteButtonStates(BuildContext context) {
  return const CatalogFrame(
    width: 500,
    child: Row(
      children: <Widget>[
        Expanded(
          child: AudioMuteButton(
            muted: false,
            label: 'Mute output',
            onPressed: _noop,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: AudioMuteButton(
            muted: true,
            label: 'Unmute output',
            onPressed: _noop,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: AudioMuteButton(
            muted: true,
            label: 'No output device',
            onPressed: null,
          ),
        ),
      ],
    ),
  );
}

@UseCase(
  name: 'Unavailable',
  type: AudioDisabledFader,
  path: '[Building blocks]/Audio',
)
Widget buildAudioDisabledFader(BuildContext context) {
  return const CatalogFrame(
    width: 180,
    child: SizedBox(
      height: 190,
      child: Center(child: AudioDisabledFader(accent: Color(0xFF43D879))),
    ),
  );
}

@UseCase(
  name: 'Brightness control',
  type: BrightnessControl,
  path: '[Building blocks]/Audio',
)
Widget buildBrightnessControlStates(BuildContext context) {
  return CatalogFrame(
    width: 440,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        BrightnessControl(
          status: AudioFixtures.brightness,
          loading: false,
          onSetBrightness: _ignoreInt,
        ),
        BrightnessControl(
          status: const BrightnessStatusUnavailable(
            message: 'No display backlight',
          ),
          loading: false,
          onSetBrightness: _ignoreInt,
        ),
      ],
    ),
  );
}

@UseCase(
  name: 'Console knob',
  type: BrightnessKnob,
  path: '[Building blocks]/Audio',
)
Widget buildBrightnessKnobStates(BuildContext context) {
  return CatalogFrame(
    width: 400,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        BrightnessKnob(
          value: 25,
          enabled: true,
          presentation: BrightnessKnobPresentation.console,
          onChanged: _ignoreInt,
          onChangeEnd: _ignoreInt,
        ),
        BrightnessKnob(
          value: 75,
          enabled: true,
          presentation: BrightnessKnobPresentation.console,
          onChanged: _ignoreInt,
          onChangeEnd: _ignoreInt,
        ),
        BrightnessKnob(
          value: 75,
          enabled: false,
          presentation: BrightnessKnobPresentation.console,
          onChanged: _ignoreInt,
          onChangeEnd: _ignoreInt,
        ),
      ],
    ),
  );
}

@UseCase(
  name: 'Brightness readout',
  type: BrightnessKnobReadout,
  path: '[Building blocks]/Audio',
)
Widget buildBrightnessKnobReadoutStates(BuildContext context) {
  return const CatalogFrame(
    width: 300,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        BrightnessKnobReadout(value: 25),
        BrightnessKnobReadout(value: 75),
        BrightnessKnobReadout(value: 100),
      ],
    ),
  );
}

@UseCase(
  name: 'Mixer header',
  type: AudioMixerHeader,
  path: '[Building blocks]/Audio',
)
Widget buildAudioMixerHeaderStates(BuildContext context) {
  return CatalogFrame(
    width: 420,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: const <Widget>[
        AudioMixerHeader(output: AudioFixtures.output),
        SizedBox(height: 12),
        AudioMixerHeader(output: null),
      ],
    ),
  );
}

@UseCase(
  name: 'Mixer stage',
  type: AudioMixerStage,
  path: '[Building blocks]/Audio',
)
Widget buildAudioMixerStage(BuildContext context) {
  return CatalogCanvas(
    child: SizedBox(
      width: 336,
      child: AudioMixerStage(
        output: AudioFixtures.output,
        input: AudioFixtures.input,
        brightnessStatus: AudioFixtures.brightness,
        brightnessLoading: false,
        onSetVolume: _ignoreVolume,
        onSetMuted: _ignoreMuted,
        onSetBrightness: _ignoreInt,
      ),
    ),
  );
}

@UseCase(name: 'States', type: AudioMasterRail, path: '[Building blocks]/Audio')
Widget buildAudioMasterRailStates(BuildContext context) {
  return CatalogFrame(
    width: 420,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: const <Widget>[
        AudioMasterRail(output: AudioFixtures.output),
        SizedBox(height: 12),
        AudioMasterRail(output: null),
      ],
    ),
  );
}

@UseCase(
  name: 'External mixer',
  type: AudioMixerFooter,
  path: '[Building blocks]/Audio',
)
Widget buildAudioMixerFooter(BuildContext context) {
  return const CatalogFrame(
    width: 420,
    child: AudioMixerFooter(input: null, onOpenMixer: _noop),
  );
}

@UseCase(
  name: 'Vertical divider',
  type: HyprPanelDivider,
  path: '[Building blocks]/Audio',
)
Widget buildAudioChromeAtoms(BuildContext context) {
  return const CatalogFrame(
    width: 420,
    child: SizedBox(height: 44, child: Center(child: HyprPanelDivider())),
  );
}

@UseCase(
  name: 'Unavailable message',
  type: AudioMessage,
  path: '[Building blocks]/Audio',
)
Widget buildAudioMessageStates(BuildContext context) {
  return const CatalogFrame(
    width: 420,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AudioMessage(message: 'PipeWire is offline'),
        SizedBox(height: 12),
        AudioMessage(message: 'No input device detected'),
      ],
    ),
  );
}

void _noop() {}

void _ignoreInt(int _) {}

void _ignoreVolume(AudioEndpointKind _, int _) {}

void _ignoreMuted(AudioEndpointKind _, {required bool muted}) {}
