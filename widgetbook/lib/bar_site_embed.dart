import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:hyprbaric/widget_catalog.dart';

import 'audio/docs_bar_preview.dart';
import 'audio/site_module.dart';

/// Documentation-site embed for the bar iframe.
///
/// Unlike the multi-view panel previews, the bar owns its engine and renders
/// into the iframe viewport as the implicit single view. Sizing an engine
/// view to an arbitrary host element is unreliable once several views share
/// one engine (every view converges onto the latest one's), while the iframe
/// viewport sizes a lone view exactly, so the bar, its popups, and their
/// input regions always agree.
///
/// The host page loads `flutter/bar/index.html?base=<site-root>` and listens
/// for `{source: 'hyprbaric-bar', url}` messages to route client-side. Open
/// menu geometry arrives as `{source: 'hyprbaric-bar-frost', rect}` messages
/// so the page can frost exactly the popup area instead of a whole layer.
void main() {
  final String baseUrl = Uri.base.queryParameters['base'] ?? '/';

  final ValueNotifier<DocsDestination> section = ValueNotifier<DocsDestination>(
    DocsDestination.hero,
  );
  _listen(
    'message'.toJS,
    ((HostMessage event) {
      if (event.origin != Uri.base.origin || event.source != _parentWindow) {
        return;
      }
      final Object? payload = event.data.dartify();
      if (payload is! Map || payload['source'] != 'hyprbaric-section') return;
      final Object? anchor = payload['anchor'];
      for (final DocsDestination destination in DocsDestination.values) {
        if (destination.target == '/#$anchor') {
          section.value = destination;
          return;
        }
      }
    }).toJS,
  );
  runApp(
    ValueListenableBuilder<DocsDestination>(
      valueListenable: section,
      builder: (context, activeSection, child) => DocsBarPreview(
        baseUrl: baseUrl,
        activeSection: activeSection,
        onNavigate: _postNavigate,
        onMenuRect: _postMenuRect,
        onModuleHint: _postModuleHint,
      ),
    ),
  );
  _reportReady();
}

/// Tells the host page the bar has painted, so it can retire its fallback.
///
/// Waits a few frames so async fixtures (menu headings, title) usually land
/// before the host swaps chrome. Failures mean there is no host listening.
void _reportReady() {
  int frames = 0;

  void tick(_) {
    if (++frames < 3) {
      WidgetsBinding.instance.addPostFrameCallback(tick);
      WidgetsBinding.instance.scheduleFrame();
      return;
    }
    try {
      _parentPostMessage(
        <String, String>{'source': 'hyprbaric-bar-ready'}.jsify(),
        Uri.base.origin.toJS,
      );
    } catch (_) {
      // No listening host: the bar itself is unaffected.
    }
  }

  WidgetsBinding.instance.addPostFrameCallback(tick);
}

@JS('window.parent.postMessage')
external JSVoid _parentPostMessage(JSAny? message, JSString targetOrigin);

/// Hands an absolute URL to the hosting page for client-side routing.
///
/// Failures mean there is no host listening (direct visits, tests), in which
/// case the request is dropped rather than breaking the bar.
void _postNavigate(String url) {
  try {
    _parentPostMessage(
      <String, String>{'source': 'hyprbaric-bar', 'url': url}.jsify(),
      Uri.base.origin.toJS,
    );
  } catch (_) {
    // No listening host: keep the bar itself usable.
  }
}

void _postMenuRect(LayerShellMenuRegion? region) {
  final Rect? rect = region?.rect;
  final BorderRadius? radius = region?.radius;

  try {
    _parentPostMessage(
      <String, Object?>{
        'source': 'hyprbaric-bar-frost',
        'rect': rect == null
            ? null
            : <String, Object>{
                'x': rect.left.round(),
                'y': rect.top.round(),
                'w': rect.width.round(),
                'h': rect.height.round(),
                'r': <int>[
                  radius?.topLeft.x.round() ?? 0,
                  radius?.topRight.x.round() ?? 0,
                  radius?.bottomRight.x.round() ?? 0,
                  radius?.bottomLeft.x.round() ?? 0,
                ],
              },
      }.jsify(),
      Uri.base.origin.toJS,
    );
  } catch (_) {
    // No listening host: keep the bar itself usable.
  }
}

@JS('window.addEventListener')
external void _listen(JSString type, JSFunction listener);

@JS('window.parent')
external JSObject get _parentWindow;

/// The browser message boundary; only same-origin parent messages are accepted.
extension type HostMessage(JSObject _) implements JSObject {
  external String get origin;
  external JSObject? get source;
  external JSAny? get data;
}

/// The host draws introductions outside the clipped bar viewport.
///
/// Failures mean there is no host listening, in which case the request is
/// dropped rather than breaking the bar.
void _postModuleHint(ModuleHint? hint) {
  try {
    _parentPostMessage(
      <String, Object?>{
        'source': 'hyprbaric-module-hint',
        'hint': hint == null
            ? null
            : <String, Object>{
                'title': hint.module.title,
                'description': hint.module.description,
                'x': hint.rect.center.dx,
                'bottom': hint.rect.bottom,
              },
      }.jsify(),
      Uri.base.origin.toJS,
    );
  } catch (_) {
    // No listening host: keep the bar itself usable.
  }
}
