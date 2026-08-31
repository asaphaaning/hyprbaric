import 'dart:ui';

import 'package:flutter/material.dart';

import 'catalog/catalog_theme.dart';
import 'stories/audio_mixer_preview.dart';

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
            child: const _MixerEmbed(),
          ),
      ],
    );
  }
}

class _MixerEmbed extends StatelessWidget {
  const _MixerEmbed();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: catalogTheme.copyWith(scaffoldBackgroundColor: Colors.transparent),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: const SizedBox(
              width: 336,
              child: RepaintBoundary(child: AudioMixerPreview()),
            ),
          ),
        ),
      ),
    );
  }
}
