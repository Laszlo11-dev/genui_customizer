import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'models.dart';

class RssService {
  RssService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static const maxFeedBytes = 2 * 1024 * 1024;
  static const _requestTimeout = Duration(seconds: 15);

  Future<List<NewsItem>> load(String input, {String? source}) async {
    final url = Uri.tryParse(input.trim());
    if (url == null ||
        (url.scheme != 'http' && url.scheme != 'https') ||
        url.host.isEmpty) {
      throw const FormatException('Use a valid HTTP(S) RSS or Atom URL.');
    }
    const accept =
        'application/rss+xml, application/atom+xml, application/xml, text/xml, */*';
    if (kIsWeb) {
      // Keep the browser's original GET path. BrowserClient buffers responses,
      // so the size check happens after the browser finishes the fetch.
      final response = await _client
          .get(url, headers: {'Accept': accept})
          .timeout(_requestTimeout);
      if (response.bodyBytes.length > maxFeedBytes) {
        throw const FormatException('Feed is too large (2 MB limit).');
      }
      if (response.statusCode != 200) {
        throw Exception('Feed returned HTTP ${response.statusCode}');
      }
      return compute(_parseFeed, (response.body, source ?? url.host, url));
    }
    final request = http.Request('GET', url)..headers['Accept'] = accept;
    final clock = Stopwatch()..start();
    final streamed = await _client.send(request).timeout(_requestTimeout);
    final response = await _readLimited(streamed, clock);
    if (response.statusCode != 200) {
      throw Exception('Feed returned HTTP ${response.statusCode}');
    }
    return compute(_parseFeed, (response.body, source ?? url.host, url));
  }

  static Future<http.Response> _readLimited(
    http.StreamedResponse response,
    Stopwatch clock,
  ) async {
    final bytes = BytesBuilder(copy: false);
    final chunks = StreamIterator<List<int>>(response.stream);
    try {
      while (true) {
        final remaining = _requestTimeout - clock.elapsed;
        if (remaining <= Duration.zero) {
          throw TimeoutException('Feed timed out');
        }
        if (!await chunks.moveNext().timeout(remaining)) break;
        final chunk = chunks.current;
        if (bytes.length + chunk.length > maxFeedBytes) {
          throw const FormatException('Feed is too large (2 MB limit).');
        }
        bytes.add(chunk);
      }
    } finally {
      await chunks.cancel();
    }
    return http.Response.bytes(
      bytes.takeBytes(),
      response.statusCode,
      headers: response.headers,
    );
  }

  static List<NewsItem> parse(
    String xml, {
    required String source,
    Uri? baseUri,
  }) {
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
      XmlElement? linkElement;
      final links = node.children.whereType<XmlElement>().where(
        (e) => e.name.local == 'link',
      );
      if (link.isEmpty) {
        final alternate = links.where(
          (e) => e.getAttribute('rel') == 'alternate',
        );
        linkElement = alternate.isNotEmpty
            ? alternate.first
            : links.where((e) => e.getAttribute('rel') == null).firstOrNull;
        link = linkElement?.getAttribute('href') ?? '';
      } else {
        linkElement = links
            .where((e) => e.innerText.trim() == link)
            .firstOrNull;
      }
      final parsed = Uri.tryParse(link);
      final effectiveBase = _baseFor(linkElement ?? node, baseUri);
      final uri = parsed == null
          ? null
          : (effectiveBase?.resolveUri(parsed) ?? parsed);
      if (title.isEmpty ||
          uri == null ||
          (uri.scheme != 'https' && uri.scheme != 'http') ||
          uri.host.isEmpty) {
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
      if (items.length == 30) break;
    }
    return items;
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

  static Uri? _baseFor(XmlElement element, Uri? feedUrl) {
    var base = feedUrl;
    for (final ancestor in [
      ...element.ancestors.whereType<XmlElement>().toList().reversed,
      element,
    ]) {
      final declared = ancestor.getAttribute('xml:base');
      if (declared != null) {
        final relative = Uri.tryParse(declared);
        if (relative != null) base = base?.resolveUri(relative) ?? relative;
      }
    }
    return base;
  }

  void dispose() => _client.close();
}

List<NewsItem> _parseFeed((String, String, Uri) input) =>
    RssService.parse(input.$1, source: input.$2, baseUri: input.$3);
