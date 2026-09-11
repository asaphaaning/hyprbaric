import 'docs_search.dart';

/// Off the web there is no index to fetch; callers fall back to curated
/// links. See [fetchDocsSearchIndex] for the browser implementation.
Future<List<DocsSearchEntry>?> fetchDocsSearchIndex() async => null;
