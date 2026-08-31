import 'dart:js_interop';
import 'dart:ui';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import 'audio/audio_mixer_preview.dart';
import 'audio/controls_panel_preview.dart';
import 'embed/embed_theme.dart';

void main() => runWidget(const _EmbedViews());

class _EmbedViews extends StatefulWidget {
  const _EmbedViews();

  @override
  State<_EmbedViews> createState() => _EmbedViewsState();
}

class _EmbedViewsState extends State<_EmbedViews> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return ViewCollection(
      views: <Widget>[
        for (final FlutterView view
            in WidgetsBinding.instance.platformDispatcher.views)
          View(
            key: ValueKey<int>(view.viewId),
            view: view,
            child: _PreviewEmbed(preview: _Preview.from(view)),
          ),
      ],
    );
  }
}

enum _Preview {
  mixer(width: 336),
  controls(width: 432);

  const _Preview({required this.width});

  final double width;

  static _Preview from(FlutterView view) {
    final _EmbedInitialData? data =
        ui_web.views.getInitialData(view.viewId) as _EmbedInitialData?;

    return switch (data?.preview) {
      'controls' => _Preview.controls,
      _ => _Preview.mixer,
    };
  }
}

extension type _EmbedInitialData._(JSObject _) implements JSObject {
  external String? get preview;
}

class _PreviewEmbed extends StatelessWidget {
  const _PreviewEmbed({required this.preview});

  final _Preview preview;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: embedTheme,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: preview.width,
              child: RepaintBoundary(
                child: switch (preview) {
                  _Preview.mixer => const AudioMixerPreview(),
                  _Preview.controls => const ControlsPanelPreview.landing(),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
