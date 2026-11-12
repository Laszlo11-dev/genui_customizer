import 'package:a2ui_tech_reader/models.dart';
import 'package:a2ui_tech_reader/rss_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses RSS 2.0', () {
    const rss = '''<rss version="2.0"><channel><item><title>A new processor</title><link>https://example.org/a</link><description>Test story</description></item></channel></rss>''';
    final result = RssService.parse(rss, source: 'Example');
    expect(result.length, 1);
    expect(result.single.title, 'A new processor');
    expect(result.single.link.toString(), 'https://example.org/a');
  });

  test('parses Atom links', () {
    const xml = '''<feed xmlns="http://www.w3.org/2005/Atom"><entry><title>Atom article</title><link href="https://example.org/b" rel="alternate"/><summary>News</summary></entry></feed>''';
    final result = RssService.parse(xml, source: 'Atom');
    expect(result.single.title, 'Atom article');
    expect(result.single.link.path, '/b');
  });

  test('automatic Christmas edition', () {
    expect(resolvedOccasion(Occasion.auto, DateTime(2026, 12, 24)), Occasion.christmas);
    expect(resolvedOccasion(Occasion.auto, DateTime(2026, 7, 10)), Occasion.everyday);
  });
}
