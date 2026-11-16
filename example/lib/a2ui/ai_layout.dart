import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Only A2UI presentation values can come from Gemini.
class AiLayout {
  const AiLayout({
    required this.bannerColor,
    required this.accentColor,
    required this.cardColor,
    required this.borderColor,
    required this.columns,
    required this.gap,
    required this.cornerRadius,
    required this.imagePosition,
    this.pageColor = '#F6F3FC',
    this.surfaceColor = '#FFFFFF',
    this.headline = 'Ask AI layout',
    this.kicker = 'TECH / ASK AI EDITION',
    this.bannerTitle = 'THE TECH FEED',
    this.bannerEyebrow = 'AI designed A2UI',
    this.layoutStyle = 'grid',
    this.cardTitleSize = 22,
    this.imageHeight = 150,
    this.buttonStyle = 'outline',
  });

  final String bannerColor;
  final String accentColor;
  final String cardColor;
  final String borderColor;
  final int columns;
  final int gap;
  final int cornerRadius;
  final String imagePosition;
  final String pageColor;
  final String surfaceColor;
  final String headline;
  final String kicker;
  final String bannerTitle;
  final String bannerEyebrow;
  final String layoutStyle;
  final int cardTitleSize;
  final int imageHeight;
  final String buttonStyle;

  Map<String, Object?> toJson() => {
    'bannerColor': bannerColor,
    'accentColor': accentColor,
    'cardColor': cardColor,
    'borderColor': borderColor,
    'columns': columns,
    'gap': gap,
    'cornerRadius': cornerRadius,
    'imagePosition': imagePosition,
    'pageColor': pageColor,
    'surfaceColor': surfaceColor,
    'headline': headline,
    'kicker': kicker,
    'bannerTitle': bannerTitle,
    'bannerEyebrow': bannerEyebrow,
    'layoutStyle': layoutStyle,
    'cardTitleSize': cardTitleSize,
    'imageHeight': imageHeight,
    'buttonStyle': buttonStyle,
  };

  factory AiLayout.fromJson(Map<String, Object?> json) =>
      parse(jsonEncode(json));

  static AiLayout parse(String text) {
    final data = jsonDecode(text);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Gemini returned an invalid A2UI layout.');
    }
    var validValues = 0;
    String color(String key, String fallback) {
      final value = data[key];
      if (value is! String || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
        return fallback;
      }
      validValues++;
      return value;
    }

    int measure(String key, int min, int max, int fallback) {
      final value = data[key];
      if (value is! num || !value.isFinite) return fallback;
      validValues++;
      return value.round().clamp(min, max);
    }

    String label(String key, String fallback, int maxLength) {
      final value = data[key];
      if (value is! String || value.trim().isEmpty) return fallback;
      validValues++;
      final clean = value.trim().replaceAll(RegExp(r'\s+'), ' ');
      return clean.length <= maxLength ? clean : clean.substring(0, maxLength);
    }

    String option(String key, List<String> allowed, String fallback) {
      final value = data[key];
      final normalized = value is String ? value.trim().toLowerCase() : '';
      if (!allowed.contains(normalized)) return fallback;
      validValues++;
      return normalized;
    }

    final rawPosition = data['imagePosition'];
    final position = rawPosition is String
        ? rawPosition.trim().toLowerCase()
        : '';
    if (position == 'top' || position == 'left' || position == 'none') {
      validValues++;
    }
    final layout = AiLayout(
      bannerColor: color('bannerColor', '#282145'),
      accentColor: color('accentColor', '#6B4BC3'),
      cardColor: color('cardColor', '#FFFFFF'),
      borderColor: color('borderColor', '#DCD3F3'),
      columns: measure('columns', 1, 4, 2),
      gap: measure('gap', 0, 40, 18),
      cornerRadius: measure('cornerRadius', 0, 40, 20),
      imagePosition: switch (position) {
        'left' => 'left',
        'none' => 'none',
        _ => 'top',
      },
      pageColor: color('pageColor', '#F6F3FC'),
      surfaceColor: color('surfaceColor', '#FFFFFF'),
      headline: label('headline', 'Ask AI layout', 60),
      kicker: label('kicker', 'TECH / ASK AI EDITION', 60),
      bannerTitle: label('bannerTitle', 'THE TECH FEED', 80),
      bannerEyebrow: label('bannerEyebrow', 'AI designed A2UI', 60),
      layoutStyle: option('layoutStyle', ['grid', 'feature', 'wire'], 'grid'),
      cardTitleSize: measure('cardTitleSize', 18, 32, 22),
      imageHeight: measure('imageHeight', 90, 280, 150),
      buttonStyle: option('buttonStyle', [
        'outline',
        'filled',
        'text',
      ], 'outline'),
    );
    if (validValues == 0) {
      throw const FormatException('Gemini returned no usable A2UI values.');
    }
    return layout;
  }
}

class GeminiLayoutService {
  GeminiLayoutService(
    this.apiKey, {
    http.Client? client,
    this.primaryModel = 'gemini-3.6-flash',
    this.fallbackModel = 'gemini-3.5-flash-lite',
    this.retryDelay = const Duration(seconds: 2),
    this.primaryTimeout = const Duration(seconds: 12),
    this.fallbackTimeout = const Duration(seconds: 18),
  }) : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;
  final String primaryModel;
  final String fallbackModel;
  final Duration retryDelay;
  final Duration primaryTimeout;
  final Duration fallbackTimeout;

  Future<AiLayout> create(String userPrompt) async {
    final prompt = userPrompt.trim();
    if (prompt.isEmpty) {
      throw const FormatException('Enter a prompt for the A2UI layout.');
    }
    for (final model in [primaryModel, fallbackModel]) {
      for (var attempt = 1; attempt <= 2; attempt++) {
        late final http.Response response;
        try {
          response = await _request(
            model,
            prompt,
          ).timeout(model == primaryModel ? primaryTimeout : fallbackTimeout);
        } on TimeoutException {
          if (model == fallbackModel) {
            throw const GeminiUnavailableException(
              'Gemini did not respond. Check the connection and try again.',
            );
          }
          break;
        }
        if (response.statusCode == 503) {
          if (attempt == 1) await Future<void>.delayed(retryDelay);
          continue;
        }
        if (response.statusCode != 200) {
          throw Exception('Gemini returned HTTP ${response.statusCode}.');
        }
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = body['candidates'] as List?;
        final parts = candidates?.firstOrNull?['content']?['parts'] as List?;
        final text = parts
            ?.whereType<Map<String, dynamic>>()
            .map((part) => part['text'])
            .whereType<String>()
            .join();
        if (text == null || text.isEmpty) {
          throw const FormatException('Gemini returned no A2UI layout.');
        }
        return AiLayout.parse(text);
      }
    }
    throw const GeminiUnavailableException();
  }

  Future<http.Response> _request(String model, String prompt) async {
    final response = await _client.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
      ),
      headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text':
                    'Design a cohesive technology reader appearance inspired by the user direction. '
                    'Style the entire visible reader: page background, shell, headline, A2UI sections, grid, and story cards. '
                    'Return only presentation values and short thematic UI headings. '
                    'Do not choose, reorder, group, summarize, or rewrite articles. '
                    'Use a coherent palette for pageColor, surfaceColor, bannerColor, accentColor, cardColor, '
                    'and borderColor (six-digit #RRGGBB colors). '
                    'Choose headline, kicker, bannerTitle, and bannerEyebrow as short thematic UI labels. '
                    'Choose layoutStyle (grid, feature, wire), columns (1-4), gap (0-40), '
                    'cornerRadius (0-40), cardTitleSize (18-32), imageHeight (90-280), '
                    'imagePosition (top, left, none), and buttonStyle (outline, filled, text). '
                    'Keep text readable on all backgrounds. '
                    'Visual direction from the user: $prompt',
              },
            ],
          },
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'responseJsonSchema': {
            'type': 'object',
            'properties': {
              for (final name in [
                'bannerColor',
                'accentColor',
                'cardColor',
                'borderColor',
                'pageColor',
                'surfaceColor',
              ])
                name: {
                  'type': 'string',
                  'description': 'Six-digit #RRGGBB color',
                },
              for (final name in [
                'headline',
                'kicker',
                'bannerTitle',
                'bannerEyebrow',
              ])
                name: {'type': 'string'},
              'columns': {'type': 'integer', 'minimum': 1, 'maximum': 4},
              'gap': {'type': 'integer', 'minimum': 0, 'maximum': 40},
              'cornerRadius': {'type': 'integer', 'minimum': 0, 'maximum': 40},
              'cardTitleSize': {
                'type': 'integer',
                'minimum': 18,
                'maximum': 32,
              },
              'imageHeight': {'type': 'integer', 'minimum': 90, 'maximum': 280},
              'imagePosition': {
                'type': 'string',
                'enum': ['top', 'left', 'none'],
              },
              'layoutStyle': {
                'type': 'string',
                'enum': ['grid', 'feature', 'wire'],
              },
              'buttonStyle': {
                'type': 'string',
                'enum': ['outline', 'filled', 'text'],
              },
            },
            'required': [
              'bannerColor',
              'accentColor',
              'cardColor',
              'borderColor',
              'pageColor',
              'surfaceColor',
              'headline',
              'kicker',
              'bannerTitle',
              'bannerEyebrow',
              'columns',
              'gap',
              'cornerRadius',
              'cardTitleSize',
              'imageHeight',
              'imagePosition',
              'layoutStyle',
              'buttonStyle',
            ],
          },
        },
      }),
    );
    return response;
  }

  void dispose() => _client.close();
}

class GeminiUnavailableException implements Exception {
  const GeminiUnavailableException([
    this.message = 'Gemini is temporarily overloaded. Please try again.',
  ]);

  final String message;

  @override
  String toString() => message;
}
