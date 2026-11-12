import 'package:a2ui_core/a2ui_core.dart';

import 'models.dart';
import 'news_gallery.dart';

/// Produces the news stream as A2UI data, including its occasion styling.
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
    final edition = occasion == Occasion.auto ? Occasion.everyday : occasion;
    final palette = _palettes[edition]!;

    void section(
      String id,
      String title, {
      String? eyebrow,
      bool banner = false,
    }) {
      nodes.add({
        'id': id,
        'component': 'NewsSection',
        'catalogId': newsGalleryCatalogId,
        'title': title,
        'eyebrow': ?eyebrow,
        'backgroundColor': banner ? palette.banner : palette.card,
        'textColor': banner ? palette.bannerInk : palette.ink,
        'accentColor': banner ? palette.bannerAccent : palette.accent,
        'titleSize': banner ? 31 : 25,
        'padding': banner ? 22 : 0,
        'cornerRadius': banner ? 20 : 0,
        'showRule': banner,
      });
      children.add(id);
    }

    String story(int index, {String variant = 'standard', bool short = false}) {
      final article = articles[index];
      final id = 'story_$index';
      final feature = variant == 'feature';
      final wire = variant == 'wire';
      final date = article.published?.toLocal();
      nodes.add({
        'id': id,
        'component': 'NewsStory',
        'catalogId': newsGalleryCatalogId,
        'title': article.title,
        'source': article.source,
        if (article.summary.isNotEmpty) 'summary': article.summary,
        if (article.imageUrl != null) 'imageUrl': article.imageUrl,
        if (date != null)
          'date':
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'openLabel': 'Read original ↗',
        'open': {
          'event': {'name': 'open_$index'},
        },
        'backgroundColor': feature ? palette.feature : palette.card,
        'textColor': palette.ink,
        'mutedColor': palette.muted,
        'accentColor': palette.accent,
        'borderColor': palette.border,
        'cornerRadius': feature ? 24 : palette.radius,
        'padding': feature ? 22 : 16,
        'imageHeight': feature ? 250 : (wire ? 96 : 150),
        'imagePosition': wire ? 'left' : 'top',
        'imageFit': 'cover',
        'titleSize': feature ? 30 : (wire ? 19 : 22),
        'titleWeight': feature ? 'bold' : 'medium',
        'summarySize': 14,
        'showSummary': !short,
        'showDate': true,
        'buttonStyle': feature ? 'filled' : (wire ? 'text' : 'outline'),
        'elevation': feature ? 2 : 0,
      });
      return id;
    }

    void grid(
      String id,
      List<int> indices,
      int columns, {
      bool short = false,
      String variant = 'standard',
    }) {
      if (indices.isEmpty) return;
      nodes.add({
        'id': id,
        'component': 'NewsGrid',
        'catalogId': newsGalleryCatalogId,
        'children': [
          for (final index in indices)
            story(index, variant: variant, short: short),
        ],
        'columns': compact ? 1 : columns,
        'gap': edition == Occasion.winter ? 12 : 18,
      });
      children.add(id);
    }

    void status(String title, String detail) {
      section('status_title', title, banner: true);
      nodes.add({'id': 'status_detail', 'component': 'Text', 'text': detail});
      children.add('status_detail');
    }

    final all = List<int>.generate(
      articles.length > 24 ? 24 : articles.length,
      (i) => i,
    );
    if (loading) {
      status('Loading stories…', 'Fetching the selected RSS / Atom feed.');
    } else if (error != null) {
      status('Feed unavailable', error);
    } else if (all.isEmpty) {
      status(
        'No stories found',
        'Choose another RSS source or refresh this feed.',
      );
    } else {
      switch (edition) {
        case Occasion.everyday:
          section(
            'lead',
            'THE DAILY EDIT · ${all.length} STORIES',
            eyebrow: 'Today in technology',
            banner: true,
          );
          children.add(story(0, variant: 'feature'));
          section('latest', 'Latest in technology');
          grid('daily', all.skip(1).toList(), 3);
        case Occasion.christmas:
          section(
            'lead',
            'THE HOLIDAY EDIT',
            eyebrow: '✦ Tech / festive edition',
            banner: true,
          );
          final gifts = all
              .where((i) => _matches(articles[i], _giftTerms))
              .toList();
          if (gifts.isNotEmpty) {
            section(
              'gifts',
              'Gift ideas from this feed',
              eyebrow: 'Selected stories',
            );
            grid('gifts_grid', gifts, 2, variant: 'feature');
          }
          section('holiday_latest', 'More from the feed');
          grid('holiday', all.where((i) => !gifts.contains(i)).toList(), 2);
        case Occasion.winter:
          section(
            'lead',
            'WINTER GAMES / TECH WATCH',
            eyebrow: '❄ Technology in motion',
            banner: true,
          );
          final sports = all
              .where((i) => _matches(articles[i], _winterTerms))
              .toList();
          if (sports.isNotEmpty) {
            section('winter_sport', 'Winter sport technology');
            grid('sport', sports, 2);
          }
          section('winter_latest', 'The news wire');
          grid(
            'winter',
            all.where((i) => !sports.contains(i)).toList(),
            1,
            short: true,
            variant: 'wire',
          );
        case Occasion.easter:
          section(
            'lead',
            'FRESH IDEAS / SPRING EDIT',
            eyebrow: '✿ New season',
            banner: true,
          );
          final spring = all
              .where((i) => _matches(articles[i], _springTerms))
              .toList();
          if (spring.isNotEmpty) {
            section('spring', 'Spring discoveries', eyebrow: 'From this feed');
            grid('spring_cards', spring, 2, variant: 'feature');
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

class _Palette {
  const _Palette(
    this.accent,
    this.ink,
    this.muted,
    this.card,
    this.feature,
    this.border,
    this.banner,
    this.bannerInk,
    this.bannerAccent,
    this.radius,
  );
  final String accent,
      ink,
      muted,
      card,
      feature,
      border,
      banner,
      bannerInk,
      bannerAccent;
  final int radius;
}

const _palettes = <Occasion, _Palette>{
  Occasion.everyday: _Palette(
    '#3957D7',
    '#192336',
    '#536079',
    '#FFFFFF',
    '#FFFFFF',
    '#E1E5EF',
    '#E7ECFF',
    '#192336',
    '#3957D7',
    18,
  ),
  Occasion.christmas: _Palette(
    '#AB3439',
    '#153C35',
    '#526B62',
    '#FFFFFF',
    '#FFF8F0',
    '#E8D6CE',
    '#153C35',
    '#FFFFFF',
    '#E8C783',
    20,
  ),
  Occasion.winter: _Palette(
    '#1768A0',
    '#122C42',
    '#536C7C',
    '#FFFFFF',
    '#EAF5FB',
    '#C7DFEA',
    '#123B59',
    '#FFFFFF',
    '#9DDBF5',
    10,
  ),
  Occasion.easter: _Palette(
    '#6B779D',
    '#343455',
    '#6B687B',
    '#FFFFFF',
    '#F6F0FA',
    '#E5DBEB',
    '#E6DDF2',
    '#343455',
    '#75629A',
    28,
  ),
};
