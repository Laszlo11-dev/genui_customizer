import 'package:a2ui_tech_reader/models.dart';
import 'package:a2ui_tech_reader/rss/rss_service.dart';

/// A fixed, curated RSS reading list of publisher articles and package pages.
/// Summaries are short paraphrases; links point to the original sources.
List<NewsItem> demoRssStories() => RssService.parse(
  '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel><title>GenUI Touch demo reading list</title>
  <item>
    <title>A2UI 1.0: Build delightful, fast, reliable, agentic experiences</title>
    <link>https://developers.googleblog.com/a2ui-10-build-delightful-fast-reliable-agentic-experiences/</link>
    <source>Google Developers Blog</source>
    <description>Google introduces A2UI 1.0, a stable protocol for interactive agent interfaces rendered with native app components.</description>
    <pubDate>Wed, 11 Nov 2026 00:00:00 GMT</pubDate>
    <enclosure url="https://storage.googleapis.com/gweb-developer-goog-blog-assets/images/06_atlassian_jira.original.png" type="image/png" />
  </item>
  <item>
    <title>What's new in Flutter 3.50</title>
    <link>https://flutter.dev/blog/whats-new-in-flutter-3-50</link>
    <source>Flutter Blog</source>
    <description>Flutter 3.50 adds stable native interop, faster web rendering, accessibility improvements, and new tools for package authors.</description>
    <pubDate>Wed, 11 Nov 2026 00:00:00 GMT</pubDate>
    <enclosure url="https://flutter.dev/assets/hero_image.b6c0d9689da0f65c9bb69711c24105f7.webp" type="image/webp" />
  </item>
  <item>
    <title>A2UI Flutter renderer on pub.dev</title>
    <link>https://pub.dev/packages/a2ui_flutter</link>
    <source>pub.dev</source>
    <description>The Flutter renderer turns A2UI messages into native widgets across mobile, web, and desktop.</description>
    <pubDate>Wed, 11 Nov 2026 00:00:00 GMT</pubDate>
  </item>
  <item>
    <title>New updates to A2UI and Flutter’s GenUI package</title>
    <link>https://flutter.dev/blog/new-updates-to-a2ui-and-flutters-genui-package</link>
    <source>Flutter Blog</source>
    <description>Flutter explains changes to its GenUI package and the A2UI protocol behind agent-generated interfaces.</description>
    <pubDate>Thu, 14 May 2026 00:00:00 GMT</pubDate>
    <enclosure url="https://flutter.dev/assets/1yPatUacknopOAVF_Vr86OA.e383b476686514af49da58912a71cfcd.webp" type="image/webp" />
  </item>
  <item>
    <title>GenUI Touch: customize A2UI Flutter surfaces</title>
    <link>https://github.com/Laszlo11-dev/genui_customizer</link>
    <source>GenUI Touch</source>
    <description>GenUI Touch lets people edit approved A2UI presentation values and save appearance preferences in a Flutter app.</description>
  </item>
</channel></rss>''',
  source: 'Curated RSS snapshot',
  baseUri: Uri.parse('https://example.com/feed.xml'),
);
