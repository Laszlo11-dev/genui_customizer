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
    expect(components.any((c) => c['component'] == 'Card'), true);
    expect(components.any((c) => c['component'] == 'Button'), true);
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
    expect(nodes.any((n) => n['component'] == 'Image'), true);
    expect(nodes.any((n) => n['text'] == '2026-01-02'), true);
    expect(nodes.any((n) => n['action'] != null), true);
    expect(nodes.any((n) => (n['text'] as String?)?.contains('Gift ideas from this feed') == true), true);
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
}
