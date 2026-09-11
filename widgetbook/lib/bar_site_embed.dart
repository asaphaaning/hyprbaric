import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';

import 'audio/docs_bar_preview.dart';

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
/// menu geometry is reported as `{source: 'hyprbaric-bar-frost', rect}`
/// messages so the page can frost exactly the popup area instead of a whole
/// layer.
void main() {
  final String baseUrl = Uri.base.queryParameters['base'] ?? '/';
  final String home = DocsDestination.home.resolve(baseUrl);

  runApp(
    ProviderScope(
      overrides: docsBarOverrides(
        baseUrl: baseUrl,
        onNavigate: _postNavigate,
      ),
      // Above the MaterialApp Hyprbaric builds, so this alignment must not
      // need a Directionality.
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          Hyprbaric(onTitleTap: () => _postNavigate(home)),
          const _MenuFrostReporter(),
        ],
      ),
    ),
  );
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

/// Forwards the open menu region to the hosting page for its frost island.
///
/// The dropdowns already measure this rect for the native input region; the
/// site embed reuses the same geometry so the page can blur exactly the
/// popup area. Reports null when no menu is open so the island hides.
class _MenuFrostReporter extends ConsumerStatefulWidget {
  const _MenuFrostReporter();

  @override
  ConsumerState<_MenuFrostReporter> createState() => _MenuFrostReporterState();
}

class _MenuFrostReporterState extends ConsumerState<_MenuFrostReporter> {
  VoidCallback? _detach;

  @override
  void initState() {
    super.initState();
    final LayerShellRegionManager manager = ref.read(
      layerShellRegionManagerProvider,
    );

    void report() {
      final LayerShellMenuRegion? region = manager.menuRegion.value;
      _postMenuRect(region?.rect, region?.radius);
    }

    manager.menuRegion.addListener(report);
    _detach = () => manager.menuRegion.removeListener(report);
    report();
  }

  @override
  void dispose() {
    _detach?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void _postMenuRect(Rect? rect, BorderRadius? radius) {
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
      '*'.toJS,
    );
  } catch (_) {
    // No listening host: keep the bar itself usable.
  }
}
