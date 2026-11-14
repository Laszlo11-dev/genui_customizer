import 'package:a2ui_core/a2ui_core.dart';

import 'models.dart';
import 'ai_layout.dart';
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
    String? staleSource,
    AiLayout? aiLayout,
    String? aiError,
    OccasionPalette? occasionPalette,
    OccasionComposition? occasionComposition,
    String? pageBackgroundColor,
  }) {
    final nodes = <Map<String, Object?>>[];
    final children = <String>[];
    final edition = occasion == Occasion.auto ? Occasion.everyday : occasion;
    final palette = occasionPalette ?? paletteFor(edition);
    final composition = occasionComposition ?? compositionFor(edition);

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
        'backgroundColor': banner
            ? (aiLayout?.bannerColor ?? palette.banner)
            : palette.card,
        'textColor': banner
            ? (aiLayout == null
                  ? palette.bannerInk
                  : _inkFor(aiLayout.bannerColor))
            : palette.ink,
        'accentColor': banner
            ? (aiLayout == null
                  ? palette.bannerAccent
                  : _inkFor(aiLayout.bannerColor))
            : (aiLayout?.accentColor ?? palette.accent),
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
        'backgroundColor':
            aiLayout?.cardColor ?? (feature ? palette.feature : palette.card),
        'textColor': aiLayout == null
            ? palette.ink
            : _inkFor(aiLayout.cardColor),
        'mutedColor': aiLayout == null
            ? palette.muted
            : (_inkFor(aiLayout.cardColor) == '#FFFFFF'
                  ? '#E0DBF2'
                  : palette.muted),
        'accentColor': aiLayout?.accentColor ?? palette.accent,
        'borderColor': aiLayout?.borderColor ?? palette.border,
        'cornerRadius':
            aiLayout?.cornerRadius ?? (feature ? 24 : palette.radius),
        'padding': feature ? 22 : 16,
        'imageHeight':
            aiLayout?.imageHeight ?? (feature ? 250 : (wire ? 96 : 150)),
        'imagePosition': aiLayout?.imagePosition ?? (wire ? 'left' : 'top'),
        'imageFit': 'cover',
        'titleSize':
            aiLayout?.cardTitleSize ?? (feature ? 30 : (wire ? 19 : 22)),
        'titleWeight': feature ? 'bold' : 'medium',
        'summarySize': 14,
        'showSummary': !short,
        'showDate': true,
        'buttonStyle':
            aiLayout?.buttonStyle ??
            (feature ? 'filled' : (wire ? 'text' : 'outline')),
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
        'columns': compact ? 1 : (aiLayout?.columns ?? columns),
        'gap': aiLayout?.gap ?? (edition == Occasion.winter ? 12 : 18),
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
      if (all.isNotEmpty) {
        nodes.add({
          'id': 'refresh_notice',
          'component': 'Text',
          'text':
              'Could not refresh the selected feed. Showing the last loaded stories.',
        });
        children.add('refresh_notice');
        section(
          'last_loaded',
          'Last loaded stories',
          eyebrow: staleSource == null ? null : 'From $staleSource',
        );
        grid('last_loaded_grid', all, composition.columns);
      } else {
        status('Feed unavailable', error);
      }
    } else if (all.isEmpty) {
      status(
        'No stories found',
        'Choose another RSS source or refresh this feed.',
      );
    } else if (composition.layout == Occasion.askAi && aiLayout == null) {
      if (aiError == null) {
        status(
          'Ask AI is designing the A2UI layout…',
          'Gemini is choosing presentation values for the feed.',
        );
      } else {
        section('status_title', 'Ask AI unavailable', banner: true);
        section('ai_error_detail', aiError, eyebrow: 'Gemini response');
      }
      grid('ai_grid', all, 2);
    } else {
      switch (composition.layout) {
        case Occasion.askAi:
          section(
            'lead',
            aiLayout!.bannerTitle,
            eyebrow: aiLayout.bannerEyebrow,
            banner: true,
          );
          switch (aiLayout.layoutStyle) {
            case 'feature':
              children.add(story(0, variant: 'feature'));
              grid('ai_grid', all.skip(1).toList(), 2);
            case 'wire':
              grid('ai_grid', all, 1, variant: 'wire');
            default:
              grid('ai_grid', all, 2);
          }
        case Occasion.everyday:
          section(
            'lead',
            '${composition.text('lead')} · ${all.length} STORIES',
            eyebrow: composition.text('leadEyebrow'),
            banner: true,
          );
          children.add(story(0, variant: 'feature'));
          section('latest', composition.text('latest'));
          grid('daily', all.skip(1).toList(), composition.columns);
        case Occasion.christmas:
          section(
            'lead',
            composition.text('lead'),
            eyebrow: composition.text('leadEyebrow'),
            banner: true,
          );
          final gifts = all
              .where((i) => _matches(articles[i], composition.terms))
              .toList();
          if (gifts.isNotEmpty) {
            section(
              'gifts',
              composition.text('group'),
              eyebrow: composition.text('groupEyebrow'),
            );
            grid('gifts_grid', gifts, composition.columns, variant: 'feature');
          }
          section('holiday_latest', composition.text('latest'));
          grid(
            'holiday',
            all.where((i) => !gifts.contains(i)).toList(),
            composition.columns,
          );
        case Occasion.winter:
          section(
            'lead',
            composition.text('lead'),
            eyebrow: composition.text('leadEyebrow'),
            banner: true,
          );
          final sports = all
              .where((i) => _matches(articles[i], composition.terms))
              .toList();
          if (sports.isNotEmpty) {
            section('winter_sport', composition.text('group'));
            grid('sport', sports, composition.columns);
          }
          section('winter_latest', composition.text('latest'));
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
            composition.text('lead'),
            eyebrow: composition.text('leadEyebrow'),
            banner: true,
          );
          final spring = all
              .where((i) => _matches(articles[i], composition.terms))
              .toList();
          if (spring.isNotEmpty) {
            section(
              'spring',
              composition.text('group'),
              eyebrow: composition.text('groupEyebrow'),
            );
            grid(
              'spring_cards',
              spring,
              composition.columns,
              variant: 'feature',
            );
          }
          section('spring_latest', composition.text('latest'));
          grid(
            'easter',
            all.where((i) => !spring.contains(i)).toList(),
            composition.columns,
            short: true,
          );
        case Occasion.auto:
          break;
      }
    }
    nodes.insert(0, {
      'id': 'feed_column',
      'component': 'Column',
      'children': children,
    });
    final background =
        pageBackgroundColor ??
        aiLayout?.pageColor ??
        '#${(styleFor(edition).background.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    nodes.insert(0, {
      'id': 'root',
      'component': 'NewsPage',
      'catalogId': newsGalleryCatalogId,
      'children': ['feed_column'],
      'backgroundColor': background,
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
}

/// The content-independent A2UI arrangement and labels of an occasion.
class OccasionComposition {
  const OccasionComposition({
    required this.layout,
    required this.labels,
    this.terms = const [],
    this.columns = 2,
  });

  final Occasion layout;
  final Map<String, String> labels;
  final List<String> terms;
  final int columns;

  String text(String key) => labels[key] ?? '';

  Map<String, Object?> toJson() => {
    'layout': layout.name,
    'labels': labels,
    'terms': terms,
    'columns': columns,
  };

  factory OccasionComposition.fromJson(Map<String, Object?> json) {
    final layout = Occasion.values.byName(json['layout'] as String);
    if (layout == Occasion.auto) {
      throw const FormatException('Auto is not an occasion composition.');
    }
    final rawLabels = json['labels'];
    final rawTerms = json['terms'];
    final columns = json['columns'];
    if (rawLabels is! Map ||
        rawLabels.keys.any((key) => key is! String) ||
        rawLabels.values.any((value) => value is! String) ||
        rawTerms is! List ||
        rawTerms.any((term) => term is! String) ||
        columns is! int ||
        columns < 1 ||
        columns > 4) {
      throw const FormatException('Invalid occasion composition.');
    }
    return OccasionComposition(
      layout: layout,
      labels: Map<String, String>.from(rawLabels),
      terms: List<String>.from(rawTerms),
      columns: columns,
    );
  }
}

OccasionComposition compositionFor(Occasion occasion) => switch (occasion) {
  Occasion.auto || Occasion.everyday => const OccasionComposition(
    layout: Occasion.everyday,
    labels: {
      'lead': 'THE DAILY EDIT',
      'leadEyebrow': 'Today in technology',
      'latest': 'Latest in technology',
    },
    columns: 3,
  ),
  Occasion.christmas => const OccasionComposition(
    layout: Occasion.christmas,
    labels: {
      'lead': 'THE HOLIDAY EDIT',
      'leadEyebrow': '✦ Tech / festive edition',
      'group': 'Gift ideas from this feed',
      'groupEyebrow': 'Selected stories',
      'latest': 'More from the feed',
    },
    terms: [
      'gift',
      'present',
      'holiday',
      'christmas',
      'headphone',
      'laptop',
      'gadget',
    ],
  ),
  Occasion.winter => const OccasionComposition(
    layout: Occasion.winter,
    labels: {
      'lead': 'WINTER GAMES / TECH WATCH',
      'leadEyebrow': '❄ Technology in motion',
      'group': 'Winter sport technology',
      'latest': 'The news wire',
    },
    terms: ['ski', 'snow', 'winter sport', 'olympic', 'skate', 'bobsled'],
  ),
  Occasion.easter => const OccasionComposition(
    layout: Occasion.easter,
    labels: {
      'lead': 'FRESH IDEAS / SPRING EDIT',
      'leadEyebrow': '✿ New season',
      'group': 'Spring discoveries',
      'groupEyebrow': 'From this feed',
      'latest': 'Elsewhere in technology',
    },
    terms: ['spring', 'garden', 'solar', 'nature', 'climate', 'outdoor'],
  ),
  Occasion.askAi => const OccasionComposition(
    layout: Occasion.askAi,
    labels: {},
  ),
};

class OccasionPalette {
  const OccasionPalette(
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

  Map<String, Object?> toJson() => {
    'accent': accent,
    'ink': ink,
    'muted': muted,
    'card': card,
    'feature': feature,
    'border': border,
    'banner': banner,
    'bannerInk': bannerInk,
    'bannerAccent': bannerAccent,
    'radius': radius,
  };

  factory OccasionPalette.fromJson(Map<String, Object?> json) =>
      OccasionPalette(
        json['accent'] as String,
        json['ink'] as String,
        json['muted'] as String,
        json['card'] as String,
        json['feature'] as String,
        json['border'] as String,
        json['banner'] as String,
        json['bannerInk'] as String,
        json['bannerAccent'] as String,
        json['radius'] as int,
      );
}

OccasionPalette paletteFor(Occasion occasion) =>
    _palettes[occasion == Occasion.auto ? Occasion.everyday : occasion]!;

const _palettes = <Occasion, OccasionPalette>{
  Occasion.everyday: OccasionPalette(
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
  Occasion.christmas: OccasionPalette(
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
  Occasion.winter: OccasionPalette(
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
  Occasion.easter: OccasionPalette(
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
  Occasion.askAi: OccasionPalette(
    '#6B4BC3',
    '#21203C',
    '#625E78',
    '#FFFFFF',
    '#F5F0FF',
    '#DCD3F3',
    '#282145',
    '#FFFFFF',
    '#D3B9FF',
    20,
  ),
};

String _inkFor(String hex) {
  final red = int.parse(hex.substring(1, 3), radix: 16);
  final green = int.parse(hex.substring(3, 5), radix: 16);
  final blue = int.parse(hex.substring(5, 7), radix: 16);
  return (red * 299 + green * 587 + blue * 114) / 1000 >= 145
      ? '#21203C'
      : '#FFFFFF';
}
