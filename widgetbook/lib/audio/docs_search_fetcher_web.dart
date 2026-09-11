import 'dart:convert';
import 'dart:js_interop';

import 'docs_search.dart';

/// Loads the site-built search index sitting next to the embed.
///
/// Returns null when the index cannot be loaded (direct visits, older
/// builds): callers fall back to curated links. Never throws.
Future<List<DocsSearchEntry>?> fetchDocsSearchIndex() async {
  try {
    final String? version = Uri.base.queryParameters['v'];
    final String bust =
        version == null || version.isEmpty ? '' : '?v=$version';
    final String body = await _fetchText('search-index.json$bust'.toJS);
    final Object? decoded = jsonDecode(body);
    if (decoded is! List) {
      return null;
    }
    return decoded
        .map(DocsSearchEntry.fromJson)
        .whereType<DocsSearchEntry>()
        .toList(growable: false);
  } catch (_) {
    return null;
  }
}

@JS('fetch')
external JSPromise<JSFetchResponse> _fetchUrl(JSString url);

extension type JSFetchResponse._(JSObject _) implements JSObject {
  external JSPromise<JSString> text();
}

Future<String> _fetchText(JSString url) async {
  final JSFetchResponse response = await _fetchUrl(url).toDart;
  final JSString text = await response.text().toDart;
  return text.toDart;
}
