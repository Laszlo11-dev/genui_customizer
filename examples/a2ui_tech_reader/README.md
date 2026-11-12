# A2UI Tech Reader

A small **Touch-free** Flutter example: configurable RSS / Atom news sources,
real A2UI article components, and seasonal A2UI layouts.

## What it demonstrates

- **RSS** supplies news content.
- **A2UI 1.0** supplies the article component tree (`createSurface`, `updateComponents`).
- **a2ui_flutter** converts it into Material widgets.
- **Occasions** choose different A2UI structures and application themes.
- No Touch, LLM, chat, login, database or backend is needed.

A2UI is generated deterministically by `lib/a2ui_builder.dart`; no model is involved.
This is a useful protocol/renderer example, **not** a claim that A2UI requires AI.

## Run

Requires Flutter with Dart >=3.10.

```bash
flutter create --platforms=windows,web,android,ios .
flutter pub get
flutter run -d windows
# Or: flutter run -d chrome
flutter test
flutter analyze
```

The `flutter create` command generates the platform boilerplate omitted from this
source archive. It does not replace `lib/main.dart` if that file already exists;
check the diff if Flutter asks about existing files.

## Use

1. Choose an RSS preset (Ars Technica, The Verge, NASA, Hacker News), or paste
   an HTTPS feed URL.
2. Press **Load** to retrieve articles.
3. Choose Everyday, Christmas, Winter Games or Easter to change the A2UI tree
   and app color scheme without reloading the feed.
4. Select **Automatikus** to use Christmas in December and Easter around Easter;
   Winter Games remains manual, to avoid implying there's an Olympics every winter.
5. Open articles using the article buttons.

## Web / CORS

Many public RSS feeds do **not** grant arbitrary browser origins access. This is
a browser security constraint, not an A2UI issue. Direct feed requests generally
work better on desktop/mobile than on web.

For a *reliable public web demo*, publish a static RSS snapshot JSON with the app,
or run a small same-origin feed gateway under your control. Do **not** rely on an
untrusted public CORS proxy. The included app intentionally reports CORS failures
rather than pretending it could fetch the blocked feed.

## Structure

- `lib/rss_service.dart` — RSS/Atom HTTP download + XML parser.
- `lib/models.dart` — article model, season profiles and theme colors.
- `lib/a2ui_builder.dart` — **actual A2UI 1.0 messages** for each occasion.
- `lib/main.dart` — simple Flutter shell, feed controls, A2UI renderer.
- `test/` — RSS parser and A2UI message smoke tests.

## Known limitations

- Flutter is not installed in the environment where this archive was created,
  so `flutter pub get`, compile, analyze, and widget tests **have not been run**.
- Seasonal layout differs in component structure and featured sections. Material
  theme colors are host-side Flutter theme configuration; visual theming is not
  asserted to be part of the A2UI protocol.
- No images inside the A2UI news cards yet; the prototype emphasizes compatible
  basic components over undocumented image component properties.
- No guarantee that a general tech feed has zero political stories. Feed curation
  is preferred to fragile keyword-only censorship.
- Articles open on the publisher's own sites and are not republished.
