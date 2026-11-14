import 'models.dart';
import 'rss_service.dart';

/// A fixed, curated RSS snapshot of real publisher pages. The summaries are
/// short paraphrases; links and image URLs point to the original sources.
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
    <title>The Flutter Create winners are…</title>
    <link>https://flutter.dev/blog/the-flutter-create-winners-are</link>
    <source>Flutter Blog</source>
    <description>Explore the winners of Flutter Create and the apps they built with five kilobytes of Dart code or less.</description>
    <pubDate>Tue, 07 May 2019 00:00:00 GMT</pubDate>
    <enclosure url="https://flutter.dev/assets/09r31IUKmyYJdBwX0.000e4c1615a7433702d22181625203f5.webp" type="image/webp" />
  </item>
  <item>
    <title>Rich and dynamic user interfaces with Flutter and generative UI</title>
    <link>https://flutter.dev/blog/rich-and-dynamic-user-interfaces-with-flutter-and-generative-ui</link>
    <source>Flutter Blog</source>
    <description>The Flutter team introduces its GenUI SDK for creating dynamic interfaces from a trusted widget catalog.</description>
    <pubDate>Tue, 18 Nov 2025 00:00:00 GMT</pubDate>
    <enclosure url="https://flutter.dev/assets/1yZgCoXy4aivZfEjgTJMOrA.7dd0988f6d1502d1f696a56cb2fd05f4.webp" type="image/webp" />
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
    <title>Alibaba’s ‘Wonder on Ice’ brings interactive AI showcase to Milano Cortina 2026</title>
    <link>https://www.olympics.com/ioc/news/alibaba-s-wonder-on-ice-brings-interactive-ai-showcase-to-milano-cortina-2026</link>
    <source>Olympics.com</source>
    <description>An interactive AI and cloud showcase opened at the Olympic Winter Games in Milan.</description>
    <pubDate>Sat, 07 Feb 2026 00:00:00 GMT</pubDate>
    <enclosure url="https://img.olympics.com/images/image/private/t_s_16_9_g_auto/t_s_w960/f_auto/primary/ldkrsci6njjuub2nmr4w" type="image/jpeg" />
  </item>
</channel></rss>''',
  source: 'Curated RSS snapshot',
  baseUri: Uri.parse('https://example.com/feed.xml'),
);
