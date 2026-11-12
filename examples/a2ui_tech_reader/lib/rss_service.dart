import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'models.dart';

class RssService {
  RssService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<List<NewsItem>> load(String input) async {
    final url = Uri.tryParse(input.trim());
    if (url == null || (url.scheme != 'http' && url.scheme != 'https') || url.host.isEmpty) {
      throw const FormatException('Use a valid HTTP(S) RSS or Atom URL.');
    }
    final response = await _client
        .get(
          url,
          headers: {
            'Accept': 'application/rss+xml, application/atom+xml, application/xml, text/xml, */*',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Feed returned HTTP ${response.statusCode}');
    }
    return parse(response.body, source: url.host);
  }

  static List<NewsItem> parse(String xml, {required String source}) {
    final doc = XmlDocument.parse(xml);
    final nodes = doc.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'item' || e.name.local == 'entry',
    );
    final items = <NewsItem>[];
    for (final node in nodes) {
      String childText(String local) {
        for (final e in node.children.whereType<XmlElement>()) {
          if (e.name.local == local) return e.innerText.trim();
        }
        return '';
      }

      final title = childText('title');
      var link = childText('link');
      if (link.isEmpty) {
        for (final e in node.children.whereType<XmlElement>()) {
          if (e.name.local == 'link') {
            link = e.getAttribute('href') ?? '';
            if (e.getAttribute('rel') == 'alternate') break;
          }
        }
      }
      final uri = Uri.tryParse(link);
      if (title.isEmpty || uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
        continue;
      }
      final description = childText('description').isNotEmpty
          ? childText('description')
          : childText('summary');
      // Strip markup; don't render remote RSS HTML in an embedded WebView.
      final plain = description
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'&nbsp;|&#160;'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      String? image;
      for (final e in node.children.whereType<XmlElement>()) {
        if (e.name.local == 'thumbnail' ||
            e.name.local == 'content' ||
            e.name.local == 'enclosure') {
          final candidate = e.getAttribute('url');
          if (candidate != null && Uri.tryParse(candidate)?.scheme == 'https') {
            image = candidate;
            break;
          }
        }
      }
      final published =
          DateTime.tryParse(childText('published')) ??
          DateTime.tryParse(childText('updated')) ??
          DateTime.tryParse(childText('pubDate'));
      items.add(
        NewsItem(
          title: title,
          link: uri,
          source: source,
          summary: plain.length > 190 ? '${plain.substring(0, 187)}…' : plain,
          published: published,
          imageUrl: image,
        ),
      );
    }
    return items.take(30).toList();
  }

  void dispose() => _client.close();
}
