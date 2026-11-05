import 'dart:convert';

import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;
import 'package:genui/genui.dart';

import '../primitives/app_mode.dart';
import '../primitives/climbing/climbing_db.dart';
import 'ai_client.dart';

/// Explicitly recorded output for trying Touch without a Gemini key.
final class RecordedChatAiClient implements AiClient {
  RecordedChatAiClient({required this.mode});

  final AppMode mode;
  int _reply = 0;

  @override
  Stream<String> sendStream(
    String prompt, {
    required List<dartantic.ChatMessage> history,
  }) async* {
    if (mode == AppMode.textOnly) {
      yield 'Recorded demo: switch to Basic catalog or Custom catalog '
          'to customize generated widgets with GenUI Touch.';
      return;
    }
    final surfaceId = 'recorded-${++_reply}';
    final custom = mode == AppMode.customCatalog;
    final components = <Map<String, dynamic>>[
      {
        'id': 'root',
        'component': 'Column',
        'children': ['heading', 'description', custom ? 'location' : 'button'],
        'align': 'stretch',
      },
      {
        'id': 'heading',
        'component': 'Text',
        'variant': 'h3',
        'text': custom ? 'Climbing near Las Vegas' : 'Your next adventure',
      },
      {
        'id': 'description',
        'component': 'Text',
        'variant': 'body',
        'text':
            'Recorded reply $_reply. Open GenUI Touch to change this '
            'reply, or triple-click / long-press a widget.',
      },
      if (custom)
        {
          'id': 'location',
          'component': 'ClimbingLocation',
          'identifier':
              climbingLocations[(_reply - 1) % climbingLocations.length]
                  .identifier,
          'density': 'comfortable',
          'imageVisibility': 'show',
        }
      else ...[
        {
          'id': 'button',
          'component': 'Button',
          'child': 'button-label',
          'action': {
            'event': {'name': 'nextAdventure', 'context': {}},
          },
        },
        {
          'id': 'button-label',
          'component': 'Text',
          'text': 'Show another idea',
        },
      ],
    ];
    final response = jsonEncode([
      {
        'version': 'v0.9',
        'createSurface': {'surfaceId': surfaceId, 'catalogId': basicCatalogId},
      },
      {
        'version': 'v0.9',
        'updateComponents': {'surfaceId': surfaceId, 'components': components},
      },
    ]);
    yield 'Recorded demo response — no AI request was made.\n';
    yield '```json\n$response\n```';
  }

  @override
  void dispose() {}
}
