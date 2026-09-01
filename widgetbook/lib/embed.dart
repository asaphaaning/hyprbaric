import 'dart:js_interop';
import 'dart:ui';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import 'audio/audio_mixer_preview.dart';
import 'audio/controls_panel_preview.dart';
import 'audio/network_panel_preview.dart';
import 'audio/notification_panel_preview.dart';
import 'audio/power_panel_preview.dart';
import 'audio/workspace_strip_preview.dart';
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
            child: _PreviewEmbed(configuration: _Configuration.from(view)),
          ),
      ],
    );
  }
}

enum _Preview {
  mixer(width: 336),
  controls(width: 432),
  network(width: 340),
  power(width: 320),
  notifications(width: 380),
  workspaces(width: 340);

  const _Preview({required this.width});

  final double width;

  static _Preview from(_EmbedInitialData? data) {
    return switch (data?.preview) {
      'controls' => _Preview.controls,
      'network' => _Preview.network,
      'power' => _Preview.power,
      'notifications' => _Preview.notifications,
      'workspaces' => _Preview.workspaces,
      _ => _Preview.mixer,
    };
  }
}

class _Configuration {
  const _Configuration({required this.preview, required this.onReady});

  final _Preview preview;
  final JSFunction? onReady;

  factory _Configuration.from(FlutterView view) {
    final _EmbedInitialData? data =
        ui_web.views.getInitialData(view.viewId) as _EmbedInitialData?;

    return _Configuration(preview: _Preview.from(data), onReady: data?.onReady);
  }

  void reportReady() => onReady?.callAsFunction();
}

extension type _EmbedInitialData._(JSObject _) implements JSObject {
  external String? get preview;

  external JSFunction? get onReady;
}

class _PreviewEmbed extends StatefulWidget {
  const _PreviewEmbed({required this.configuration});

  final _Configuration configuration;

  @override
  State<_PreviewEmbed> createState() => _PreviewEmbedState();
}

class _PreviewEmbedState extends State<_PreviewEmbed> {
  bool _reportedReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_reportedReady) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _reportedReady) {
        return;
      }

      _reportedReady = true;
      widget.configuration.reportReady();
    });
  }

  @override
  Widget build(BuildContext context) {
    final _Preview preview = widget.configuration.preview;

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
                  _Preview.network => const NetworkPanelPreview(),
                  _Preview.power => const PowerPanelPreview(),
                  _Preview.notifications => const NotificationPanelPreview(),
                  _Preview.workspaces => const WorkspaceStripPreview(),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
