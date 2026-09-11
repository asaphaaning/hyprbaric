import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric_widgetbook/audio/docs_search.dart';

const List<DocsSearchEntry> _index = <DocsSearchEntry>[
  DocsSearchEntry(
    title: 'Installation',
    url: '/docs/installation',
    section: 'Get started',
    headings: <String>['Requirements', 'Verify the install'],
    body: 'Download the DEB package and install it with apt on Debian.',
  ),
  DocsSearchEntry(
    title: 'Configuration',
    url: '/docs/configuration',
    section: 'Configuration',
    headings: <String>['Appearance', 'Workspaces'],
    body: 'Everything lives in one TOML file at startup.',
  ),
  DocsSearchEntry(
    title: 'Configuration reference',
    url: '/docs/configuration-reference',
    section: 'Configuration',
    headings: <String>['Appearance reference'],
    body: 'Every key the configuration file understands.',
  ),
  DocsSearchEntry(
    title: 'Shortcuts',
    url: '/docs/shortcuts',
    section: 'Configuration',
    headings: <String>['Install the global shortcut'],
    body: 'Keybinds for capture, recording, and toggles.',
  ),
];

void main() {
  test('entry round-trips valid JSON and rejects the rest', () {
    expect(
      DocsSearchEntry.fromJson(<String, Object?>{
        'title': 'Installation',
        'url': '/docs/installation',
        'section': 'Get started',
        'headings': <String>['Requirements'],
        'body': 'Download the DEB.',
      }),
      isA<DocsSearchEntry>(),
    );
    expect(DocsSearchEntry.fromJson(null), isNull);
    expect(DocsSearchEntry.fromJson(<String>[]), isNull);
    expect(
      DocsSearchEntry.fromJson(<String, Object?>{
        'title': 'Installation',
        'url': '/docs/installation',
      }),
      isNull,
    );
  });

  test('an empty query matches nothing', () {
    expect(rankDocsResults('', _index), isEmpty);
    expect(rankDocsResults('   ', _index), isEmpty);
  });

  test('title matches outrank heading and body matches', () {
    final List<DocsSearchEntry> hits = rankDocsResults('configuration', _index);

    expect(
      hits.map((DocsSearchEntry entry) => entry.title),
      <String>['Configuration', 'Configuration reference'],
    );
  });

  test('prefix and substring matches surface the right page', () {
    expect(
      rankDocsResults('instal', _index).map((entry) => entry.title),
      <String>['Installation', 'Shortcuts'],
    );
    expect(
      rankDocsResults('toml', _index).map((entry) => entry.title),
      <String>['Configuration'],
    );
  });

  test('every token must match somewhere', () {
    expect(
      rankDocsResults('configuration toml', _index).map((entry) => entry.title),
      <String>['Configuration'],
    );
    expect(rankDocsResults('configuration missingword', _index), isEmpty);
  });

  test('results are capped at the limit', () {
    expect(rankDocsResults('the', _index, limit: 2), hasLength(2));
  });
}
