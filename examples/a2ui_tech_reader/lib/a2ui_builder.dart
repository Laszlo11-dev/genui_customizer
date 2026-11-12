import 'package:a2ui_core/a2ui_core.dart';

import 'models.dart';

/// Produces real A2UI 1.0 messages. Layout changes with the occasion,
/// without replacing the A2UI renderer with hand-coded Flutter article cards.
class NewsA2uiBuilder {
  static const surfaceId = 'news';

  static List<Map<String, Object?>> build(List<NewsItem> articles, Occasion occasion) {
    final style = styleFor(occasion);
    final nodes = <Map<String, Object?>>[];
    final rootChildren = <String>['intro', 'rule'];
    void text(String id, String value) {
      nodes.add({'id': id, 'component': 'Text', 'text': value});
    }

    text('intro', style.heroLabel);
    nodes.add({'id': 'rule', 'component': 'Divider'});
    final count = articles.length > 18 ? 18 : articles.length;
    final featured = occasion == Occasion.christmas
        ? 3
        : occasion == Occasion.winter
        ? 2
        : occasion == Occasion.easter
        ? 2
        : 1;

    if (count == 0) {
      text('empty', 'No articles found. Choose another RSS source or refresh.');
      rootChildren.add('empty');
    }

    for (var index = 0; index < count; index++) {
      final article = articles[index];
      final id = 'story_$index';
      final elements = <String>['${id}_tag', '${id}_title'];
      final category = index < featured ? 'FEATURED STORY' : 'LATEST';
      text('${id}_tag', '$category  •  ${article.source.toUpperCase()}');
      text('${id}_title', index < featured ? '★  ${article.title}' : article.title);
      if (article.summary.isNotEmpty) {
        text('${id}_summary', article.summary);
        elements.add('${id}_summary');
      }
      text('${id}_read', 'Read original article  ↗');
      nodes.add({
        'id': '${id}_button',
        'component': 'Button',
        'child': '${id}_read',
        'action': {
          'event': {'name': 'open_$index'},
        },
      });
      elements.add('${id}_button');
      nodes.add({'id': '${id}_content', 'component': 'Column', 'children': elements});
      nodes.add({'id': id, 'component': 'Card', 'child': '${id}_content'});
      rootChildren.add(id);
      if (occasion == Occasion.winter && index == 1) {
        text('winter_break', '❄  THE WINTER EDIT  /  MORE STORIES');
        rootChildren.add('winter_break');
      }
      if (occasion == Occasion.christmas && index == 2) {
        text('holiday_break', '✦  THE HOLIDAY READING LIST');
        rootChildren.add('holiday_break');
      }
      if (occasion == Occasion.easter && index == 1) {
        text('spring_break', '✿  MORE TO DISCOVER THIS SPRING');
        rootChildren.add('spring_break');
      }
    }
    nodes.insert(0, {'id': 'root', 'component': 'Column', 'children': rootChildren});
    return [
      {
        'version': '1.0',
        'createSurface': {'surfaceId': surfaceId, 'catalogId': BasicCatalog.v1_0Id},
      },
      {
        'version': '1.0',
        'updateComponents': {'surfaceId': surfaceId, 'components': nodes},
      },
    ];
  }
}
