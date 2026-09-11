import 'package:flutter/foundation.dart';

/// One searchable documentation page, as emitted by
/// `website/scripts/build-search-index.mjs`.
@immutable
class DocsSearchEntry {
  const DocsSearchEntry({
    required this.title,
    required this.url,
    required this.section,
    this.headings = const <String>[],
    this.body = '',
  });

  final String title;
  final String url;
  final String section;
  final List<String> headings;
  final String body;

  static DocsSearchEntry? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? title = json['title'];
    final Object? url = json['url'];
    final Object? section = json['section'];
    if (title is! String || url is! String || section is! String) {
      return null;
    }
    final Object? headings = json['headings'];
    final Object? body = json['body'];
    return DocsSearchEntry(
      title: title,
      url: url,
      section: section,
      headings: headings is List
          ? headings.whereType<String>().toList(growable: false)
          : const <String>[],
      body: body is String ? body : '',
    );
  }
}

/// Scores [query] against [entries], best first.
///
/// Pure so it stays unit-tested without a browser: every query token must
/// appear somewhere, with title matches weighing most, then headings, then
/// body. An empty query matches nothing; callers show curated links instead.
///
/// ```dart
/// final hits = rankDocsResults('instal', entries);
/// expect(hits.first.title, 'Installation');
/// ```
List<DocsSearchEntry> rankDocsResults(
  String query,
  List<DocsSearchEntry> entries, {
  int limit = 7,
}) {
  final List<String> tokens = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((String token) => token.isNotEmpty)
      .toList(growable: false);
  if (tokens.isEmpty) {
    return const <DocsSearchEntry>[];
  }

  final List<({DocsSearchEntry entry, int score})> scored =
      <({DocsSearchEntry entry, int score})>[];
  for (final DocsSearchEntry entry in entries) {
    final String title = entry.title.toLowerCase();
    final String headings = entry.headings.join('\n').toLowerCase();
    final String body = entry.body.toLowerCase();

    int score = 0;
    bool matchesAll = true;
    for (final String token in tokens) {
      int tokenScore = 0;
      if (title == token) {
        tokenScore += 100;
      } else if (title.startsWith(token)) {
        tokenScore += 60;
      } else if (title.contains(token)) {
        tokenScore += 40;
      }
      if (headings.contains(token)) {
        tokenScore += 20;
      }
      if (body.contains(token)) {
        tokenScore += 5;
      }
      if (tokenScore == 0) {
        matchesAll = false;
        break;
      }
      score += tokenScore;
    }
    if (matchesAll) {
      scored.add((entry: entry, score: score));
    }
  }
  scored.sort(
    (({DocsSearchEntry entry, int score}) a, ({DocsSearchEntry entry, int score}) b) =>
        b.score.compareTo(a.score),
  );
  return <DocsSearchEntry>[
    for (final ({DocsSearchEntry entry, int score}) hit in scored.take(limit))
      hit.entry,
  ];
}
