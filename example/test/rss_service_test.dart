import 'package:a2ui_tech_reader/models.dart';
import 'package:a2ui_tech_reader/news_filter.dart';
import 'package:a2ui_tech_reader/rss_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('parses RSS 2.0', () {
    const rss =
        '''<rss version="2.0"><channel><item><title>A new processor</title><link>https://example.org/a</link><description>Test story</description></item></channel></rss>''';
    final result = RssService.parse(rss, source: 'Example');
    expect(result.length, 1);
    expect(result.single.title, 'A new processor');
    expect(result.single.link.toString(), 'https://example.org/a');
  });

  test('parses RSS dates and omits audio enclosures', () {
    const rss = '''<rss><channel><item><title>Hardware</title>
      <link>https://example.org/a</link>
      <pubDate>Tue, 10 Jun 2025 12:30:00 +0200</pubDate>
      <enclosure url="https://example.org/audio.mp3" type="audio/mpeg"/>
      </item></channel></rss>''';
    final article = RssService.parse(rss, source: 'Example').single;
    expect(article.published, DateTime.utc(2025, 6, 10, 10, 30));
    expect(article.imageUrl, isNull);
  });

  test('retains a media image for an RSS story', () {
    const rss = '''<rss xmlns:media="http://search.yahoo.com/mrss/">
      <channel><item><title>Hardware</title>
      <link>https://example.org/a</link>
      <media:content url="https://cdn.example.org/photo.jpg" type="image/jpeg"/>
      </item></channel></rss>''';
    final item = RssService.parse(rss, source: 'Example').single;
    expect(item.imageUrl, 'https://cdn.example.org/photo.jpg');
  });

  test('parses Atom links', () {
    const xml =
        '''<feed xmlns="http://www.w3.org/2005/Atom"><entry><title>Atom article</title><link href="https://example.org/b" rel="alternate"/><summary>News</summary></entry></feed>''';
    final result = RssService.parse(xml, source: 'Atom');
    expect(result.single.title, 'Atom article');
    expect(result.single.link.path, '/b');
  });

  test('resolves relative links and prefers the Atom alternate link', () {
    const xml = '''<feed><entry><title>Article</title>
      <link rel="alternate" href="/stories/42"/>
      <link rel="self" href="https://example.org/api/42"/>
      </entry></feed>''';
    final items = RssService.parse(
      xml,
      source: 'Example',
      baseUri: Uri.parse('https://example.org/feed.xml'),
    );
    expect(items.single.link.toString(), 'https://example.org/stories/42');
  });

  test('resolves xml:base on an Atom entry', () {
    const xml = '''<feed xml:base="https://example.org/news/">
      <entry><title>Article</title><link href="story"/></entry>
      </feed>''';
    final items = RssService.parse(
      xml,
      source: 'Example',
      baseUri: Uri.parse('https://example.org/feed.xml'),
    );
    expect(items.single.link.toString(), 'https://example.org/news/story');
  });

  test('rejects an oversized feed before XML parsing', () async {
    final service = RssService(
      client: MockClient(
        (_) async => http.Response('x' * (RssService.maxFeedBytes + 1), 200),
      ),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.load('https://example.org/feed.xml'),
      throwsA(isA<FormatException>()),
    );
  });

  test('loads and parses a streamed feed response', () async {
    final service = RssService(
      client: MockClient(
        (_) async => http.Response(
          '<rss><channel><item><title>Loaded</title>'
          '<link>/article</link></item></channel></rss>',
          200,
        ),
      ),
    );
    addTearDown(service.dispose);
    final items = await service.load('https://example.org/feed.xml');
    expect(items.single.title, 'Loaded');
    expect(items.single.link.toString(), 'https://example.org/article');
  });

  test('retains RSS and Atom item categories', () {
    const rss = '''<rss><channel><item><title>News</title>
      <link>https://example.org/a</link><category>Policy</category>
      <category>Ukraine</category><category>Policy</category>
      </item></channel></rss>''';
    expect(RssService.parse(rss, source: 'Example').single.categories, [
      'Policy',
      'Ukraine',
    ]);
    const atom = '''<feed xmlns="http://www.w3.org/2005/Atom"><entry>
      <title>News</title><link href="https://example.org/b"/>
      <category term="Elections" label="Politics"/>
      </entry></feed>''';
    expect(RssService.parse(atom, source: 'Example').single.categories, [
      'Elections',
    ]);
  });

  test('filters explicit politics and war, keeps ordinary tech policy', () {
    NewsItem article(String title, List<String> categories) => NewsItem(
      title: title,
      link: Uri.parse('https://example.org/article'),
      source: 'Example',
      categories: categories,
    );
    expect(
      isPoliticalNews(
        article('Cloud and drone strikes', [
          'AI',
          'Tech',
          'Russia invasion of Ukraine',
        ]),
      ),
      true,
    );
    expect(
      isPoliticalNews(
        article('Trump admin loses LinkedIn case', ['Policy', 'press freedom']),
      ),
      true,
    );
    expect(
      isPoliticalNews(
        article('Ukraine says it cannot stop Russian strikes', [
          'Policy',
          'starshield',
          'Ukraine',
        ]),
      ),
      true,
    );
    expect(
      isPoliticalNews(
        article('Google faces AI moratorium calls', [
          'AI',
          'Policy',
          'AI in education',
        ]),
      ),
      false,
    );
    expect(
      isPoliticalNews(
        article('T-Mobile broadband cap challenged', ['Policy', 't-mobile']),
      ),
      false,
    );
  });

  test('automatic Christmas edition', () {
    expect(
      resolvedOccasion(Occasion.auto, DateTime(2026, 12, 24)),
      Occasion.christmas,
    );
    expect(
      resolvedOccasion(Occasion.auto, DateTime(2026, 7, 10)),
      Occasion.everyday,
    );
  });
}
