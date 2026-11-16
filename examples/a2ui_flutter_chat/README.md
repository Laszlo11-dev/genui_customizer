# A2UI Flutter chat sample with GenUI Touch

This app is adapted from the [official `a2ui_flutter` chat example](https://github.com/a2ui-project/a2ui/tree/main/dart/a2ui_flutter/example) in version 0.3.0. The upstream `chat_app.dart`, `chat_session.dart`, `llm_client.dart`, and `main.dart` are retained with their Apache 2.0 headers. Changes add GenUI Touch integration, a floating Studio, and a credential-free demo client. The upstream license is in `UPSTREAM_LICENSE`.

This adapted sample is included in the pub.dev archive under `examples/a2ui_flutter_chat/`, alongside the RSS Tech Reader in `example/`. Requires Flutter >=3.47.0 and Dart >=3.13.0, with Flutter 3.47.9 selected in the repository's `.fvmrc`.

From the repository root, run on Windows or the web:

```bash
cd examples/a2ui_flutter_chat
flutter pub get
flutter run -d windows
# or flutter run -d chrome
```

If the app directory was moved or copied and CMake reports a different cache
or source directory, run `flutter clean`, then `flutter pub get` and
`flutter run -d windows` from this app directory. Build output and
`windows/flutter/ephemeral` are generated files and must not be copied from
another example. The `flutter pub outdated` notice is informational and does
not cause this CMake failure.

Without `GEMINI_API_KEY`, the app uses a fixed A2UI response so the chat, action path, and Touch dialog can be tried locally. Enter a prompt and press Send. For live model generation on Windows, set `GEMINI_API_KEY` as a process environment variable in your terminal or local IDE run configuration. Web builds must use `--dart-define=GEMINI_API_KEY=<key>`, as in the upstream example. A key passed with `--dart-define` is compiled into the app, so keep such builds private.

The Gemini client starts with `gemini-3.6-flash`. If the service returns HTTP 503 before streaming a reply, it retries once and then tries `gemini-3.5-flash-lite`, also with one 503 retry. It does not retry or switch models after streaming output. An exhausted 503 failure shows a short error and a Retry prompt button; other errors show their failure message. These are code defaults, and model availability depends on the service and account.

After sending a prompt, use the tune button, triple-click a Text component, or long-press it to open GenUI Touch. The floating dialog can be moved by its title bar and resized at its lower right corner. Surface and Gallery are separate tabs, each with a component list and property editor. The Gallery edits approved default values for future A2UI components. This sample does not provide a durable appearance store; a host app can supply `TouchStorage`. Studio window bounds are saved separately by the package's default local bounds persistence.

From this sample directory, run `flutter analyze` and `flutter test` to check chat actions, repeated prompts, Touch gestures, dialog movement/resizing, cancellation, and 503 recovery. The sample's mocked tests do not establish live Gemini availability.
