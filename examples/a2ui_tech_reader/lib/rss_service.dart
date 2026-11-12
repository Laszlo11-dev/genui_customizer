import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'models.dart';

class RssService {
  RssService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<List<NewsItem>> load(String input) async {
    final url = Uri.tryParse(input.trim());
    if (url == null ||
        (url.scheme != 'http' && url.scheme != 'https') ||
        url.host.isEmpty) {
      throw const FormatException('Use a valid HTTP(S) RSS or Atom URL.');
    }
    final response = await _client
        .get(
          url,
          headers: {
            'Accept':
                'application/rss+xml, application/atom+xml, application/xml, text/xml, */*',
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
      if (title.isEmpty ||
          uri == null ||
          (uri.scheme != 'https' && uri.scheme != 'http')) {
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
          final mediaType = e.getAttribute('type');
          if (candidate != null &&
              Uri.tryParse(candidate)?.scheme == 'https' &&
              (e.name.local != 'enclosure' ||
                  mediaType == null ||
                  mediaType.startsWith('image/'))) {
            image = candidate;
            break;
          }
        }
      }
      final published =
          _parseDate(childText('published')) ??
          _parseDate(childText('updated')) ??
          _parseDate(childText('pubDate'));
      final categories = <String>{};
      for (final element in node.children.whereType<XmlElement>()) {
        if (element.name.local != 'category') continue;
        // RSS uses element text; Atom uses the term (or label) attribute.
        final category =
            (element.getAttribute('term') ??
                    element.getAttribute('label') ??
                    element.innerText)
                .trim();
        if (category.isNotEmpty) categories.add(category);
      }
      items.add(
        NewsItem(
          title: title,
          link: uri,
          source: source,
          summary: plain.length > 190 ? '${plain.substring(0, 187)}…' : plain,
          published: published,
          imageUrl: image,
          categories: categories.toList(),
        ),
      );
    }
    return items.take(30).toList();
  }

  static DateTime? _parseDate(String value) {
    final iso = DateTime.tryParse(value);
    if (iso != null) return iso;
    // RSS 2.0 normally uses RFC 822 dates, unlike Atom's ISO 8601 dates.
    final match = RegExp(
      r'^(?:[A-Za-z]{3},?\s+)?(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2})(?::(\d{2}))?\s+(GMT|UT|UTC|[+-]\d{4})$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return null;
    const months = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];
    final month = months.indexOf(match[2]!.toLowerCase()) + 1;
    if (month == 0) return null;
    final zone = match[7]!.toUpperCase();
    final offsetMinutes = zone.startsWith('+') || zone.startsWith('-')
        ? (zone.startsWith('-') ? -1 : 1) *
              (int.parse(zone.substring(1, 3)) * 60 +
                  int.parse(zone.substring(3, 5)))
        : 0;
    return DateTime.utc(
      int.parse(match[3]!),
      month,
      int.parse(match[1]!),
      int.parse(match[4]!),
      int.parse(match[5]!),
      int.parse(match[6] ?? '0'),
    ).subtract(Duration(minutes: offsetMinutes));
  }

  void dispose() => _client.close();
}
