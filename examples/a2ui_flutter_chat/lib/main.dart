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

// ignore: deprecated_member_use, see https://github.com/a2ui-project/a2ui/issues/3235
import 'package:flutter/material.dart';

import 'chat_app.dart';
import 'chat_session.dart';
import 'demo_client.dart';
import 'llm_client.dart';
import 'runtime_key_stub.dart'
    if (dart.library.io) 'runtime_key_io.dart'
    as runtime_key;

const String _definedApiKey = String.fromEnvironment('GEMINI_API_KEY');

void main() {
  final runtimeKey = runtime_key.geminiKeyFromProcess();
  final apiKey = _definedApiKey.isNotEmpty
      ? _definedApiKey
      : (runtimeKey ?? '');
  runApp(
    ChatApp(
      session: ChatSession(
        client: apiKey.isEmpty ? DemoClient() : GeminiClient(apiKey: apiKey),
      ),
    ),
  );
}
