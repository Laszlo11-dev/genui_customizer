import 'package:a2ui_tech_reader/a2ui_builder.dart';
import 'package:a2ui_tech_reader/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final items = List.generate(
    4,
    (i) => NewsItem(
      title: 'Story $i',
      link: Uri.parse('https://example.com/$i'),
      source: 'test',
    ),
  );

  test('generates A2UI 1.0 surface and updates', () {
    final messages = NewsA2uiBuilder.build(items, Occasion.everyday);
    expect(messages.first['version'], '1.0');
    expect(messages.first.containsKey('createSurface'), true);
    expect(messages.last.containsKey('updateComponents'), true);
    final updated = messages.last['updateComponents']! as Map<String, Object?>;
    final components = updated['components']! as List<Map<String, Object?>>;
    expect(components.any((c) => c['component'] == 'NewsStory'), true);
    expect(components.any((c) => c['component'] == 'NewsGrid'), true);
  });

  test('all four editions generate distinct A2UI trees', () {
    final trees = [
      for (final occasion in [
        Occasion.everyday,
        Occasion.christmas,
        Occasion.winter,
        Occasion.easter,
      ])
        NewsA2uiBuilder.build(items, occasion).last.toString(),
    ];
    expect(trees.toSet().length, 4);
  });

  test('saved composition restores grouping and headings', () {
    const custom = OccasionComposition(
      layout: Occasion.christmas,
      labels: {
        'lead': 'Custom holiday',
        'leadEyebrow': 'A seasonal edition',
        'group': 'Picked stories',
        'groupEyebrow': 'For this feed',
        'latest': 'Everything else',
      },
      terms: ['story 2'],
      columns: 2,
    );
    final restored = OccasionComposition.fromJson(custom.toJson());
    final update =
        NewsA2uiBuilder.build(
              items,
              Occasion.christmas,
              occasionComposition: restored,
            ).last['updateComponents']
            as Map<String, Object?>;
    final nodes = update['components'] as List<Map<String, Object?>>;
    expect(
      nodes.firstWhere((node) => node['id'] == 'lead')['title'],
      'Custom holiday',
    );
    expect(
      nodes.firstWhere((node) => node['id'] == 'gifts')['title'],
      'Picked stories',
    );
    expect(
      nodes.firstWhere((node) => node['id'] == 'holiday_latest')['title'],
      'Everything else',
    );
  });

  test('occasion changes gallery presentation properties', () {
    Map<String, Object?> lead(Occasion occasion) {
      final update =
          NewsA2uiBuilder.build(items, occasion).last['updateComponents']
              as Map<String, Object?>;
      final nodes = update['components'] as List<Map<String, Object?>>;
      return nodes.firstWhere((node) => node['id'] == 'lead');
    }

    expect(lead(Occasion.christmas)['backgroundColor'], '#153C35');
    expect(lead(Occasion.winter)['backgroundColor'], '#123B59');
    expect(lead(Occasion.easter)['accentColor'], '#75629A');
    final update =
        NewsA2uiBuilder.build(items, Occasion.winter).last['updateComponents']
            as Map<String, Object?>;
    final nodes = update['components'] as List<Map<String, Object?>>;
    expect(
      nodes
          .where((node) => node['component'] == 'NewsStory')
          .every((node) => node['buttonStyle'] == 'text'),
      true,
    );
  });

  test('feed metadata and actions stay in the A2UI tree', () {
    final article = NewsItem(
      title: 'A new laptop',
      link: Uri.parse('https://example.com/article'),
      source: 'Example',
      summary: 'A useful gadget',
      imageUrl: 'https://example.com/photo.jpg',
      published: DateTime.utc(2026, 1, 2),
    );
    final messages = NewsA2uiBuilder.build([article], Occasion.christmas);
    final update = messages.last['updateComponents'] as Map<String, Object?>;
    final nodes = update['components'] as List<Map<String, Object?>>;
    expect(
      nodes.any((n) => n['imageUrl'] == 'https://example.com/photo.jpg'),
      true,
    );
    expect(nodes.any((n) => n['date'] == '2026-01-02'), true);
    expect(nodes.any((n) => n['open'] != null), true);
    expect(
      nodes.any(
        (n) =>
            (n['title'] as String?)?.contains('Gift ideas from this feed') ==
            true,
      ),
      true,
    );
  });

  test('loading, error and empty states are A2UI components', () {
    for (final messages in [
      NewsA2uiBuilder.build([], Occasion.everyday, loading: true),
      NewsA2uiBuilder.build([], Occasion.everyday, error: 'CORS blocked'),
      NewsA2uiBuilder.build([], Occasion.everyday),
    ]) {
      final update = messages.last['updateComponents'] as Map<String, Object?>;
      final nodes = update['components'] as List<Map<String, Object?>>;
      expect(nodes.any((n) => n['component'] == 'Text'), true);
    }
  });

  test('feed error keeps last loaded stories with their source', () {
    final messages = NewsA2uiBuilder.build(
      [
        NewsItem(
          title: 'Earlier story',
          source: 'Example',
          link: Uri.parse('https://example.org/story'),
        ),
      ],
      Occasion.everyday,
      error: 'ClientException: Failed to fetch',
      staleSource: 'The Register',
    );
    final update = messages.last['updateComponents'] as Map<String, Object?>;
    final nodes = update['components'] as List<Map<String, Object?>>;
    expect(nodes.any((node) => node['title'] == 'Earlier story'), isTrue);
    expect(nodes.any((node) => node['eyebrow'] == 'From The Register'), isTrue);
    expect(
      nodes.any(
        (node) =>
            node['text'] ==
            'Could not refresh the selected feed. Showing the last loaded stories.',
      ),
      isTrue,
    );
    expect(
      nodes.any((node) => node['text'] == 'ClientException: Failed to fetch'),
      isFalse,
    );
    expect(nodes.any((node) => node['text'] == 'Feed unavailable'), isFalse);
  });

  test('rejects invalid saved composition values eagerly', () {
    expect(
      () => OccasionComposition.fromJson({
        'layout': 'christmas',
        'labels': {'lead': 42},
        'terms': ['gift'],
        'columns': 2,
      }),
      throwsFormatException,
    );
  });
}
