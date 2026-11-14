import 'package:flutter/material.dart';

import 'ai_layout.dart';

class NewsItem {
  const NewsItem({
    required this.title,
    required this.link,
    required this.source,
    this.summary = '',
    this.published,
    this.imageUrl,
    this.categories = const [],
  });

  final String title;
  final Uri link;
  final String source;
  final String summary;
  final DateTime? published;
  final String? imageUrl;
  final List<String> categories;
}

class FeedPreset {
  const FeedPreset(this.name, this.url);
  final String name;
  final String url;
}

const registerFeedPreset = FeedPreset(
  'The Register',
  'https://api.theregister.com/api/v1/article?orderBy=published&site_id=2&remapper=rss&content=node',
);
const nasaFeedPreset = FeedPreset('NASA', 'https://www.nasa.gov/feed/');

const feedPresets = <FeedPreset>[
  registerFeedPreset,
  FeedPreset('The Verge', 'https://www.theverge.com/rss/index.xml'),
  nasaFeedPreset,
  FeedPreset('Hacker News', 'https://news.ycombinator.com/rss'),
];

// These presets allow browser requests from the app's origin.
const webFeedPresets = <FeedPreset>[registerFeedPreset, nasaFeedPreset];

enum Occasion { auto, everyday, christmas, winter, easter, askAi }

extension OccasionInfo on Occasion {
  String get label => switch (this) {
    Occasion.auto => 'Automatikus',
    Occasion.everyday => 'Everyday',
    Occasion.christmas => 'Christmas',
    Occasion.winter => 'Winter Games',
    Occasion.easter => 'Easter',
    Occasion.askAi => 'Ask AI',
  };

  IconData get icon => switch (this) {
    Occasion.auto => Icons.auto_awesome_outlined,
    Occasion.everyday => Icons.public,
    Occasion.christmas => Icons.celebration_outlined,
    Occasion.winter => Icons.ac_unit,
    Occasion.easter => Icons.local_florist_outlined,
    Occasion.askAi => Icons.auto_awesome,
  };
}

// Gregorian computus; Easter Sunday falls in March or April.
DateTime easterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(year, month, day);
}

Occasion resolvedOccasion(Occasion selected, DateTime now) {
  if (selected != Occasion.auto) return selected;
  if (now.month == 12 && now.day >= 1) return Occasion.christmas;
  final easter = easterSunday(now.year);
  final delta = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(easter).inDays;
  if (delta >= -7 && delta <= 1) return Occasion.easter;
  // 'Winter Games' is a manually selectable showcase edition. We don't
  // assume an Olympics is taking place every winter.
  return Occasion.everyday;
}

class PortalStyle {
  const PortalStyle({
    required this.accent,
    required this.background,
    required this.surface,
    required this.ink,
    required this.headline,
    required this.kicker,
    required this.heroLabel,
  });
  final Color accent;
  final Color background;
  final Color surface;
  final Color ink;
  final String headline;
  final String kicker;
  final String heroLabel;

  Map<String, Object?> toJson() => {
    'accent': accent.toARGB32(),
    'background': background.toARGB32(),
    'surface': surface.toARGB32(),
    'ink': ink.toARGB32(),
    'headline': headline,
    'kicker': kicker,
    'heroLabel': heroLabel,
  };

  factory PortalStyle.fromJson(Map<String, Object?> json) => PortalStyle(
    accent: Color(json['accent'] as int),
    background: Color(json['background'] as int),
    surface: Color(json['surface'] as int),
    ink: Color(json['ink'] as int),
    headline: json['headline'] as String,
    kicker: json['kicker'] as String,
    heroLabel: json['heroLabel'] as String,
  );
}

PortalStyle styleForAi(AiLayout layout) => PortalStyle(
  accent: _hexColor(layout.accentColor),
  background: _hexColor(layout.pageColor),
  surface: _hexColor(layout.surfaceColor),
  ink: _inkForBackground(layout.pageColor),
  headline: layout.headline,
  kicker: layout.kicker,
  heroLabel: layout.bannerEyebrow,
);

Color _hexColor(String value) =>
    Color(int.parse('FF${value.substring(1)}', radix: 16));

Color _inkForBackground(String hex) {
  final red = int.parse(hex.substring(1, 3), radix: 16);
  final green = int.parse(hex.substring(3, 5), radix: 16);
  final blue = int.parse(hex.substring(5, 7), radix: 16);
  return (red * 299 + green * 587 + blue * 114) / 1000 >= 145
      ? const Color(0xFF21203C)
      : Colors.white;
}

PortalStyle styleFor(Occasion occasion) => switch (occasion) {
  Occasion.askAi => const PortalStyle(
    accent: Color(0xFF6B4BC3),
    background: Color(0xFFF6F3FC),
    surface: Colors.white,
    ink: Color(0xFF21203C),
    headline: 'Ask AI layout',
    kicker: 'TECH / ASK AI EDITION',
    heroLabel: 'AI CURATED · ORIGINAL STORIES',
  ),
  Occasion.christmas => const PortalStyle(
    accent: Color(0xFFAB3439),
    background: Color(0xFFF8F5EF),
    surface: Colors.white,
    ink: Color(0xFF153C35),
    headline: 'The holiday edit',
    kicker: 'TECH / FESTIVE EDITION',
    heroLabel: 'GIFT-WORTHY IDEAS · WINTER TECH',
  ),
  Occasion.winter => const PortalStyle(
    accent: Color(0xFF1768A0),
    background: Color(0xFFEDF6FB),
    surface: Colors.white,
    ink: Color(0xFF122C42),
    headline: 'Technology in motion',
    kicker: 'TECH / WINTER GAMES EDITION',
    heroLabel: 'WINTER GAMES · INNOVATION',
  ),
  Occasion.easter => const PortalStyle(
    accent: Color(0xFF6B779D),
    background: Color(0xFFFAF6FB),
    surface: Colors.white,
    ink: Color(0xFF343455),
    headline: 'Fresh ideas, new season',
    kicker: 'TECH / SPRING EDITION',
    heroLabel: 'SPRING · FRESH FINDS',
  ),
  _ => const PortalStyle(
    accent: Color(0xFF3957D7),
    background: Color(0xFFF3F5F9),
    surface: Colors.white,
    ink: Color(0xFF192336),
    headline: 'The future, in focus.',
    kicker: 'TECH / DAILY EDITION',
    heroLabel: 'TODAY IN TECHNOLOGY',
  ),
};
