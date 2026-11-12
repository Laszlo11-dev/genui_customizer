# Official A2UI Flutter chat example with GenUI Touch

This app is adapted from the [official `a2ui_flutter` chat example](https://github.com/a2ui-project/a2ui/tree/main/dart/a2ui_flutter/example) in version 0.3.0. The upstream `chat_app.dart`, `chat_session.dart`, `llm_client.dart`, and `main.dart` are retained with their Apache 2.0 headers. Changes add GenUI Touch integration, a floating Studio, and a credential-free demo client. The upstream license is in `UPSTREAM_LICENSE`.

Run on Windows or the web:

```bash
flutter pub get
flutter run -d windows
# or flutter run -d chrome
```

Without `GEMINI_API_KEY`, the app uses a fixed A2UI response so the chat, action path, and Touch dialog can be tried locally. Enter a prompt and press Send. For live model generation, the existing Windows run configuration can pass `GEMINI_API_KEY` as a process environment variable. Web builds must use `--dart-define=GEMINI_API_KEY=<key>`, as in the upstream example. A key passed with `--dart-define` is compiled into the app, so keep such builds private.

The Gemini client starts with `gemini-3.6-flash`. If the service returns HTTP 503 before streaming a reply, it retries once and then tries `gemini-3.5-flash-lite`. If both models are unavailable, the chat shows a short error and a Retry prompt button. A 503 comes from temporary service overload; it does not indicate an invalid API key.

Use the tune button in the chat app, or long press a Text component, to open GenUI Touch. The floating dialog can be moved by its title bar and resized at its lower right corner. Surface and Gallery are separate tabs, each with a component list and property editor. The Gallery edits approved default values for future A2UI components. This sample does not provide a durable appearance store; a host app can supply `TouchStorage`.
