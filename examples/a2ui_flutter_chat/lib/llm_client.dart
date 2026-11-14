// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;
import 'package:googleai_dart/googleai_dart.dart' as google_ai;

/// One turn of a conversation with a model.
typedef ChatTurn = ({bool fromUser, String text});

/// A language model that streams its replies.
abstract interface class LlmClient {
  /// Yields the model's reply to [turns], which end with a user turn, under
  /// [systemPrompt], as the model streams it.
  Stream<String> generate(String systemPrompt, List<ChatTurn> turns);
}

/// A Gemini model, reached through `package:dartantic_ai`.
class GeminiClient implements LlmClient {
  GeminiClient({
    required String apiKey,
    String modelName = 'gemini-3.6-flash',
    String fallbackModelName = 'gemini-3.5-flash-lite',
  }) : _primary = dartantic.Agent.forProvider(
         dartantic.GoogleProvider(apiKey: apiKey),
         chatModelName: modelName,
       ),
       _fallback = dartantic.Agent.forProvider(
         dartantic.GoogleProvider(apiKey: apiKey),
         chatModelName: fallbackModelName,
       );

  final dartantic.Agent _primary;
  final dartantic.Agent _fallback;

  /// Retries a temporary 503 once, then tries a stable, cheaper Flash-Lite
  /// model. Never switches models after any output has been streamed.
  @override
  Stream<String> generate(String systemPrompt, List<ChatTurn> turns) async* {
    final List<dartantic.ChatMessage> history = [
      dartantic.ChatMessage.system(systemPrompt),
      for (final ChatTurn turn in turns.take(turns.length - 1))
        turn.fromUser
            ? dartantic.ChatMessage.user(turn.text)
            : dartantic.ChatMessage.model(turn.text),
    ];
    for (final agent in [_primary, _fallback]) {
      for (var attempt = 1; attempt <= 2; attempt++) {
        var yielded = false;
        try {
          await for (final dartantic.ChatResult<String> result
              in agent.sendStream(turns.last.text, history: history)) {
            if (result.output.isEmpty) continue;
            yielded = true;
            yield result.output;
          }
          return;
        } on google_ai.ApiException catch (error) {
          if (error.statusCode != 503 ||
              yielded ||
              (identical(agent, _fallback) && attempt == 2)) {
            rethrow;
          }
          if (attempt == 1) {
            await Future<void>.delayed(const Duration(seconds: 2));
          }
        }
      }
    }
  }
}
