import 'dart:js_interop';

import 'package:flutter/widgets.dart';

import 'audio/docs_bar_preview.dart';

/// Documentation-site embed for the bar iframe.
///
/// Unlike the multi-view panel previews, the bar owns its engine and renders
/// into the iframe viewport as the implicit single view. Sizing an engine
/// view to an arbitrary host element is unreliable once several views share
/// one engine (every view converges onto the latest one's size); the iframe
/// viewport sizes this view exactly, so the bar, its popups, and their input
/// regions always agree.
///
/// The host page loads `flutter/bar/index.html?base=<site-root>` and listens
/// for `{source: 'hyprbaric-bar', url}` messages to route client-side.
void main() {
  final String baseUrl = Uri.base.queryParameters['base'] ?? '/';

  runApp(DocsBarPreview(baseUrl: baseUrl, onNavigate: _postNavigate));
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
      '*'.toJS,
    );
  } catch (_) {
    // No listening host: keep the bar itself usable.
  }
}
