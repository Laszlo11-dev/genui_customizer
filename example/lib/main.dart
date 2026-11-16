import 'package:flutter/widgets.dart';

import 'reader_app.dart';
import 'runtime_key_stub.dart'
    if (dart.library.io) 'runtime_key_io.dart'
    as runtime_key;

export 'reader_app.dart' show TechReaderApp, ReaderPage;

const _definedApiKey = String.fromEnvironment('GEMINI_API_KEY');

void main() {
  final key = _definedApiKey.isNotEmpty
      ? _definedApiKey
      : (runtime_key.geminiKeyFromProcess() ?? '');
  runApp(TechReaderApp(apiKey: key.trim()));
}
