import 'package:a2ui_core/a2ui_core.dart';

import 'models.dart';

/// Builds the news stream as A2UI data. The Flutter shell owns only controls.
class NewsA2uiBuilder {
  static const surfaceId = 'news';

  static List<Map<String, Object?>> build(
    List<NewsItem> articles,
    Occasion occasion, {
    bool compact = false,
    bool loading = false,
    String? error,
  }) {
    final nodes = <Map<String, Object?>>[];
    final children = <String>[];

    void text(String id, String value, [String? variant]) => nodes.add({
      'id': id,
      'component': 'Text',
      'text': variant != null && variant.startsWith('h')
          ? '${List.filled(int.parse(variant.substring(1)), '#').join()} $value'
          : value,
      'variant': ?(variant == 'caption' ? variant : null),
    });
    void column(String id, List<String> items) =>
        nodes.add({'id': id, 'component': 'Column', 'children': items});
    void row(String id, List<String> items) =>
        nodes.add({'id': id, 'component': 'Row', 'children': items});
    void section(String id, String label) {
      text(id, label, 'h3');
      children.add(id);
    }

    String card(int index, {bool feature = false, bool short = false}) {
      final article = articles[index];
      final id = 'story_$index';
      final parts = <String>[];
      if (article.imageUrl != null) {
        nodes.add({
          'id': '${id}_image',
          'component': 'Image',
          'url': article.imageUrl,
          'description': article.title,
          'variant': feature ? 'header' : 'smallFeature',
        });
        parts.add('${id}_image');
      }
      text('${id}_source', article.source.toUpperCase(), 'caption');
      text('${id}_title', article.title, feature ? 'h2' : 'h4');
      parts.addAll(['${id}_source', '${id}_title']);
      if (!short && article.summary.isNotEmpty) {
        text('${id}_summary', article.summary);
        parts.add('${id}_summary');
      }
      if (article.published != null) {
        final date = article.published!.toLocal();
        text(
          '${id}_date',
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          'caption',
        );
        parts.add('${id}_date');
      }
      text('${id}_open_label', 'Read original ↗');
      nodes.add({
        'id': '${id}_open',
        'component': 'Button',
        'child': '${id}_open_label',
        'action': {
          'event': {'name': 'open_$index'},
        },
      });
      parts.add('${id}_open');
      column('${id}_content', parts);
      nodes.add({'id': id, 'component': 'Card', 'child': '${id}_content'});
      return id;
    }

    void grid(String id, List<int> indices, int columns, {bool short = false}) {
      for (var start = 0; start < indices.length; start += columns) {
        final cards = [
          for (final index in indices.skip(start).take(columns))
            card(index, short: short),
        ];
        if (cards.length == 1 || compact) {
          children.addAll(cards);
        } else {
          final rowId = '${id}_row_$start';
          row(rowId, cards);
          children.add(rowId);
        }
      }
    }

    final all = List<int>.generate(
      articles.length > 24 ? 24 : articles.length,
      (i) => i,
    );
    final edition = occasion == Occasion.auto ? Occasion.everyday : occasion;
    if (loading) {
      section('loading_title', 'Loading stories…');
      text('loading_detail', 'Fetching the selected RSS / Atom feed.');
      children.add('loading_detail');
    } else if (error != null) {
      section('error_title', 'Feed unavailable');
      text('error_detail', error);
      children.add('error_detail');
    } else if (all.isEmpty) {
      section('empty_title', 'No stories found');
      text('empty_detail', 'Choose another RSS source or refresh this feed.');
      children.add('empty_detail');
    } else {
      switch (edition) {
        case Occasion.everyday:
          section('lead', 'THE DAILY EDIT · ${all.length} STORIES');
          children.add(card(0, feature: true));
          section('latest', 'Latest in technology');
          grid('daily', all.skip(1).toList(), 3);
        case Occasion.christmas:
          section('lead', '✦ THE HOLIDAY EDIT');
          final gifts = all
              .where((i) => _matches(articles[i], _giftTerms))
              .toList();
          if (gifts.isNotEmpty) {
            section('gifts', 'Gift ideas from this feed');
            grid('gifts', gifts, 2);
          }
          section('holiday_latest', 'More from the feed');
          grid('holiday', all.where((i) => !gifts.contains(i)).toList(), 2);
        case Occasion.winter:
          section('lead', '❄ WINTER GAMES / TECH WATCH');
          final sports = all
              .where((i) => _matches(articles[i], _winterTerms))
              .toList();
          if (sports.isNotEmpty) {
            section('winter_sport', 'Winter sport technology');
            grid('sport', sports, 3, short: true);
          }
          section('winter_latest', 'The news wire');
          grid(
            'winter',
            all.where((i) => !sports.contains(i)).toList(),
            1,
            short: true,
          );
        case Occasion.easter:
          section('lead', '✿ FRESH IDEAS / SPRING EDIT');
          final spring = all
              .where((i) => _matches(articles[i], _springTerms))
              .toList();
          if (spring.isNotEmpty) {
            section('spring', 'Spring discoveries');
            grid('spring_cards', spring, 2);
          }
          section('spring_latest', 'Elsewhere in technology');
          grid(
            'easter',
            all.where((i) => !spring.contains(i)).toList(),
            2,
            short: true,
          );
        case Occasion.auto:
          break;
      }
    }
    nodes.insert(0, {
      'id': 'root',
      'component': 'Column',
      'children': children,
    });
    return [
      {
        'version': '1.0',
        'createSurface': {
          'surfaceId': surfaceId,
          'catalogId': BasicCatalog.v1_0Id,
        },
      },
      {
        'version': '1.0',
        'updateComponents': {'surfaceId': surfaceId, 'components': nodes},
      },
    ];
  }

  static bool _matches(NewsItem item, List<String> terms) {
    final content = '${item.title} ${item.summary}'.toLowerCase();
    return terms.any(content.contains);
  }

  static const _giftTerms = [
    'gift',
    'present',
    'holiday',
    'christmas',
    'headphone',
    'laptop',
    'gadget',
  ];
  static const _winterTerms = [
    'ski',
    'snow',
    'winter sport',
    'olympic',
    'skate',
    'bobsled',
  ];
  static const _springTerms = [
    'spring',
    'garden',
    'solar',
    'nature',
    'climate',
    'outdoor',
  ];
}
