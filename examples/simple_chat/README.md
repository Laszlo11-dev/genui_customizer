# Simple Chat with GenUI Touch

A local adaptation of Flutter's [Simple Chat example](https://github.com/flutter/genui/tree/584d10327d95f4baaf2553ca167b92bd56816b39/examples/simple_chat).
Upstream source and climbing assets retain their Flutter copyright notices and
the BSD license in [LICENSE](LICENSE). Climbing images are AI-generated upstream.

## Run the recorded demo

From this directory, with the repository's Flutter 3.47.9 SDK selected:

```sh
flutter pub get
flutter run -d chrome
```

Use `windows` instead of `chrome` for desktop. The default is an explicitly
labeled recorded demo: it needs no API key and makes no AI request.

1. Send the prefilled climbing request in **Custom catalog** mode.
2. Open **GenUI Touch** below the generated reply, or triple-click / long-press
   one of its widgets.
3. Select a Text, Row, Column, or Climbing location node. Change text style,
   alignment, card density, or image visibility. Changes appear in the live reply.
4. Try undo/redo, discard, and save. **Save lasts for the current conversation**;
   restarting or switching modes starts fresh.
5. Send another request. Its components may have the same IDs, but editing one
   reply does not change another.

**Basic catalog** demonstrates standard widgets and button actions. **Text only**
keeps the original text chat and has no generated surfaces to customize.

## Run the original live Gemini chat

The upstream Gemini/Dartantic transport is retained. Enable it explicitly:

```sh
flutter run -d windows --dart-define=GENUI_CHAT_LIVE=true
```

For Windows, supply `GEMINI_API_KEY` in the shell environment before starting.
For Chrome, supply it as `--dart-define=GEMINI_API_KEY=...` in your local launch
configuration. Do not commit a real key or publish a web build containing one.
The upstream default model is `gemini-3-flash-preview`; its current availability
and live model responses have not been verified in this migration.

Touch edits are manual here. The chat AI is not wired to Touch's separate
constrained property-edit composer or full-surface proposal callbacks.

## Integration map

- `lib/touch_integration.dart`: visual property allowlist, per-surface controllers,
  incremental component merging, catalog decoration, and conversation checkpoints.
- `lib/chat_session.dart`: routes the original A2UI stream through the adapter;
  the existing transport, data updates, and submit actions remain in use.
- `lib/main.dart`: opens the floating editor for a specific chat reply, provides
  its live data model for previews, and selects recorded or live operation.
- `lib/primitives/climbing/a2ui_components/climbing.dart`: adds two visual
  properties to the original composite custom card.
- `lib/agent/recorded_ai_client.dart`: predictable, key-free output through the
  same transport/parser used by live responses.

See [MIGRATION_LOG.md](MIGRATION_LOG.md) for problems found, decisions, verification
results, and limitations, including incoming updates rebasing editor history.

## Verify

```sh
dart analyze lib test
flutter test
flutter build web --release
```

This adaptation includes web and Windows runners. Other upstream platforms were
not copied or tested. The root library's pub archive excludes this second demo.
