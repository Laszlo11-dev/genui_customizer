import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';

import 'llm_client.dart';

/// Credential-free replay for trying the official chat flow locally.
/// It is selected only when GEMINI_API_KEY is absent.
final class DemoClient implements LlmClient {
  int _turn = 0;

  @override
  Stream<String> generate(String systemPrompt, List<ChatTurn> turns) async* {
    final turn = ++_turn;
    if (turns.last.text.contains('"a2ui"')) {
      yield 'The demo action was received. Add a Gemini key for model replies.';
      return;
    }
    final surfaceId = 'demo-$turn';
    yield 'Offline A2UI example. Add a Gemini API key for live generation.\n';
    yield '<a2ui-json>${jsonEncode([
      {
        'version': '1.0',
        'createSurface': {'surfaceId': surfaceId, 'catalogId': BasicCatalog.v1_0Id},
      },
      {
        'version': '1.0',
        'updateComponents': {
          'surfaceId': surfaceId,
          'components': [
            {
              'id': 'root',
              'component': 'Column',
              'children': ['heading', 'description', 'button'],
            },
            {'id': 'heading', 'component': 'Text', 'text': 'A2UI chat surface $turn'},
            {'id': 'description', 'component': 'Text', 'text': 'This surface uses the official Flutter basic catalog.'},
            {
              'id': 'button',
              'component': 'Button',
              'child': 'buttonLabel',
              'action': {
                'event': {'name': 'demoAction'},
              },
            },
            {'id': 'buttonLabel', 'component': 'Text', 'text': 'Try action'},
          ],
        },
      },
    ])}</a2ui-json>';
  }
}
