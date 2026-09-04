import 'dart:js_interop';
import 'dart:ui';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import 'audio/preview_registry.dart';
import 'embed/embed_theme.dart';

void main() => runWidget(const _EmbedViews());

/// Hosts every landing-page preview as a view of one shared engine.
///
/// The page adds a view per preview through `app.addView`, so the whole
/// landing page pays for one engine and one CanvasKit instead of one per
/// preview.
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

  /// Adding or removing a view reports a metrics change, which is how a new
  /// host element finds its way into [ViewCollection].
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

@immutable
class _Configuration {
  const _Configuration({required this.preview, required this.onReady});

  /// Null when the host asked for a preview this build does not carry.
  final LandingPreview? preview;
  final JSFunction? onReady;

  factory _Configuration.from(FlutterView view) {
    final _EmbedInitialData? data =
        ui_web.views.getInitialData(view.viewId) as _EmbedInitialData?;

    return _Configuration(
      preview: LandingPreview.byName(data?.preview),
      onReady: data?.onReady,
    );
  }

  /// Reports the first painted frame, or the unknown name, back to the page.
  void report() {
    final JSFunction? callback = onReady;
    if (callback == null) {
      return;
    }

    final LandingPreview? resolved = preview;
    callback.callAsFunction(
      null,
      resolved == null
          ? 'Unknown preview requested'.toJS
          : null,
    );
  }
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
  bool _reported = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_reported) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _reported) {
        return;
      }

      _reported = true;
      widget.configuration.report();
    });
  }

  @override
  Widget build(BuildContext context) {
    final LandingPreview? preview = widget.configuration.preview;
    if (preview == null) {
      // The page shows its own error state once `report` hands back a reason,
      // so an unknown name must not quietly render some other panel.
      return const SizedBox.shrink();
    }

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
              child: RepaintBoundary(child: preview.build()),
            ),
          ),
        ),
      ),
    );
  }
}
