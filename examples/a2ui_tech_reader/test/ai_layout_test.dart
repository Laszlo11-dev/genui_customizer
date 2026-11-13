import 'dart:async';
import 'dart:convert';

import 'package:a2ui_tech_reader/a2ui_builder.dart';
import 'package:a2ui_tech_reader/ai_layout.dart';
import 'package:a2ui_tech_reader/models.dart';
import 'package:a2ui_tech_reader/main.dart';
import 'package:a2ui_tech_reader/news_gallery.dart';
import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/basic_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const layoutJson =
    '{"bannerColor":"#282145","accentColor":"#6B4BC3",'
    '"cardColor":"#FFFFFF","borderColor":"#DCD3F3",'
    '"columns":3,"gap":12,"cornerRadius":20,"imagePosition":"top"}';

void main() {
  testWidgets('Ask AI opens an editor with Holidays at Sea', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TechReaderApp(apiKey: 'test-key'));
    await tester.tap(find.byType(DropdownButtonFormField<Occasion>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask AI').last);
    await tester.pumpAndSettle();
    expect(find.text('Ask AI · A2UI layout'), findsOneWidget);
    final editor = tester.widget<TextField>(find.byType(TextField).last);
    expect(editor.controller!.text, 'Holidays at Sea');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('AI A2UI layout renders in the official surface', (tester) async {
    final processor = MessageProcessor<ComponentImplementation>(
      catalogs: [basicCatalog(), newsGalleryCatalog],
    );
    SurfaceModel<ComponentImplementation>? surface;
    processor.model.onSurfaceCreated.subscribe((value) => surface = value);
    final errors = processor.processMessagesWithErrors(
      NewsA2uiBuilder.build(
        [
          NewsItem(
            title: 'Original story',
            source: 'Example',
            link: Uri.parse('https://example.com'),
          ),
        ],
        Occasion.askAi,
        aiLayout: AiLayout.parse(layoutJson),
      ),
    );
    expect(errors, isEmpty);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: A2uiSurface(surface: surface!)),
        ),
      ),
    );
    expect(find.text('Original story'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    processor.dispose();
  });

  test(
    'AI changes A2UI presentation without changing feed content or order',
    () {
      final layout = AiLayout.parse(layoutJson);
      final articles = List.generate(
        3,
        (i) => NewsItem(
          title: 'Story $i',
          source: 'Example',
          link: Uri.parse('https://example.com/$i'),
        ),
      );
      final update =
          NewsA2uiBuilder.build(
                articles,
                Occasion.askAi,
                aiLayout: layout,
              ).last['updateComponents']
              as Map<String, Object?>;
      final nodes = update['components'] as List<Map<String, Object?>>;
      final grid = nodes.firstWhere((node) => node['id'] == 'ai_grid');
      expect(grid['columns'], 3);
      expect(grid['gap'], 12);
      expect(grid['children'], ['story_0', 'story_1', 'story_2']);
      for (var i = 0; i < articles.length; i++) {
        final story = nodes.firstWhere((node) => node['id'] == 'story_$i');
        expect(story['title'], articles[i].title);
        expect(story['open'], {
          'event': {'name': 'open_$i'},
        });
        expect(story['accentColor'], layout.accentColor);
      }
    },
  );

  test('AI theme covers the shell and feature layout', () {
    final values = jsonDecode(layoutJson) as Map<String, dynamic>;
    values.addAll({
      'pageColor': '#FFF7E4',
      'surfaceColor': '#FFFFFF',
      'headline': 'Summer tech escape',
      'kicker': 'SUMMER / TECH EDITION',
      'bannerTitle': 'SUNNY DAYS',
      'bannerEyebrow': 'Summer holidays',
      'layoutStyle': 'feature',
      'cardTitleSize': 27,
      'imageHeight': 210,
      'buttonStyle': 'filled',
    });
    final layout = AiLayout.parse(jsonEncode(values));
    final style = styleForAi(layout);
    expect(style.background, const Color(0xFFFFF7E4));
    expect(style.headline, 'Summer tech escape');
    final articles = List.generate(
      3,
      (i) => NewsItem(
        title: 'Story $i',
        source: 'Example',
        link: Uri.parse('https://example.com/$i'),
      ),
    );
    final update =
        NewsA2uiBuilder.build(
              articles,
              Occasion.askAi,
              aiLayout: layout,
            ).last['updateComponents']
            as Map<String, Object?>;
    final nodes = update['components'] as List<Map<String, Object?>>;
    expect(nodes.any((node) => node['title'] == 'SUNNY DAYS'), isTrue);
    final root = nodes.firstWhere((node) => node['id'] == 'root');
    expect(root['component'], 'NewsPage');
    expect(root['backgroundColor'], '#FFF7E4');
    expect(root['children'], contains('feed_column'));
    final feed = nodes.firstWhere((node) => node['id'] == 'feed_column');
    expect(feed['children'], contains('story_0'));
    expect(
      nodes.firstWhere((node) => node['id'] == 'story_1')['buttonStyle'],
      'filled',
    );
  });

  test('AI layout repairs unsupported presentation values', () {
    final layout = AiLayout.parse(
      layoutJson
          .replaceFirst('"columns":3', '"columns":9')
          .replaceFirst('"imagePosition":"top"', '"imagePosition":"center"'),
    );
    expect(layout.columns, 4);
    expect(layout.imagePosition, 'top');
    expect(
      AiLayout.parse(layoutJson.replaceFirst('"top"', '"LEFT"')).imagePosition,
      'left',
    );
  });

  test('Gemini request only asks for A2UI presentation', () async {
    final service = GeminiLayoutService(
      'test-key',
      client: MockClient((request) async {
        expect(request.headers['x-goog-api-key'], 'test-key');
        final prompt =
            jsonDecode(request.body)['contents'][0]['parts'][0]['text']
                as String;
        expect(prompt, contains('Return only presentation values'));
        final schema =
            jsonDecode(
                  request.body,
                )['generationConfig']['responseJsonSchema']['properties']
                as Map<String, dynamic>;
        expect(schema['imagePosition']['enum'], ['top', 'left', 'none']);
        expect(schema.containsKey('pageColor'), isTrue);
        expect(schema['layoutStyle']['enum'], ['grid', 'feature', 'wire']);
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': layoutJson},
                  ],
                },
              },
            ],
          }),
          200,
        );
      }),
    );
    expect((await service.create('Holidays at Sea')).columns, 3);
    service.dispose();
  });

  test('503 retries before switching to the chat fallback model', () async {
    final requests = <String>[];
    final service = GeminiLayoutService(
      'test-key',
      retryDelay: Duration.zero,
      client: MockClient((request) async {
        requests.add(request.url.pathSegments.last);
        final prompt =
            jsonDecode(request.body)['contents'][0]['parts'][0]['text']
                as String;
        expect(prompt, contains('Holidays at Sea'));
        if (requests.length < 3) return http.Response('', 503);
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': layoutJson},
                  ],
                },
              },
            ],
          }),
          200,
        );
      }),
    );
    expect((await service.create('Holidays at Sea')).columns, 3);
    expect(requests, [
      'gemini-3.6-flash:generateContent',
      'gemini-3.6-flash:generateContent',
      'gemini-3.5-flash-lite:generateContent',
    ]);
    service.dispose();
  });

  test('timeout switches to Flash-Lite and keeps the user prompt', () async {
    final requests = <String>[];
    final service = GeminiLayoutService(
      'test-key',
      primaryTimeout: const Duration(milliseconds: 10),
      client: MockClient((request) async {
        requests.add(request.url.pathSegments.last);
        final prompt =
            jsonDecode(request.body)['contents'][0]['parts'][0]['text']
                as String;
        expect(prompt, contains('Holidays at Sea'));
        if (requests.length == 1) return Completer<http.Response>().future;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': layoutJson},
                  ],
                },
              },
            ],
          }),
          200,
        );
      }),
    );
    expect((await service.create('Holidays at Sea')).columns, 3);
    expect(requests, [
      'gemini-3.6-flash:generateContent',
      'gemini-3.5-flash-lite:generateContent',
    ]);
    service.dispose();
  });

  test('two timeouts produce a readable error', () async {
    final service = GeminiLayoutService(
      'test-key',
      primaryTimeout: const Duration(milliseconds: 10),
      fallbackTimeout: const Duration(milliseconds: 10),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    await expectLater(
      service.create('Holidays at Sea'),
      throwsA(
        isA<GeminiUnavailableException>().having(
          (error) => error.toString(),
          'message',
          contains('did not respond'),
        ),
      ),
    );
    service.dispose();
  });

  test('AI error leaves original stories in the A2UI feed', () {
    final update =
        NewsA2uiBuilder.build(
              [
                NewsItem(
                  title: 'Original story',
                  source: 'Example',
                  link: Uri.parse('https://example.com'),
                ),
              ],
              Occasion.askAi,
              aiError: 'Gemini did not respond.',
            ).last['updateComponents']
            as Map<String, Object?>;
    final nodes = update['components'] as List<Map<String, Object?>>;
    expect(nodes.any((node) => node['title'] == 'Original story'), isTrue);
    expect(nodes.any((node) => node['component'] == 'NewsGrid'), isTrue);
    expect(
      nodes.any(
        (node) =>
            node['title'] == 'Gemini did not respond.' &&
            node['component'] == 'NewsSection',
      ),
      isTrue,
    );
  });
}
