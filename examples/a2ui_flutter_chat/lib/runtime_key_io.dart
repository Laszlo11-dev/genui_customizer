import 'dart:io';

/// Desktop run configurations can supply the key as an environment variable.
String? geminiKeyFromProcess() => Platform.environment['GEMINI_API_KEY'];
