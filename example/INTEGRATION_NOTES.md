# Touch integration notes

## Documentation corrections

- The reader README and `pubspec.yaml` still described the app as Touch-free, although this task adds Touch. They have been updated.
- `HANDOVER.md` was a historical snapshot whose Touch and Ask AI claims were outdated. It has been rewritten for the current integration; use `README.md` for usage details.
- The README formerly called the JSON inspector the exact processor input. It shows the builder's messages; Touch layers saved appearance before the processor receives them. The README now states this explicitly.
- The Touch skill's minimal sequence does not explain a host that recreates its processor per refresh. This reader now keeps one processor and deletes/recreates only its surface. That lifecycle is necessary for the controller to remain attached.

## Other findings and limits

- The sandbox could not read the existing Pub cache, so `flutter pub get --offline` failed even though packages existed. A targeted unsandboxed `flutter pub get` succeeded. This is an execution environment issue, not a project dependency error.
- The web build succeeded but emitted a CupertinoIcons font warning. The app does not declare `cupertino_icons`; this warning did not block compilation.
- The reader originally used free-text color fields. It now uses Touch's `color` contract and a built-in 16-color palette. The field shows the current swatch, including a valid saved color outside the palette, while new selections are limited to the 16 named colors.
- The widget tests, analyzer, and web/Windows builds passed. No interactive run against a live RSS feed was performed; browser CORS and live source behavior remain dependent on the selected feed.

## Follow-up UI fix

- The Studio's text and number fields previously sent changes only on Enter. They now apply valid input as it is typed and keep focus during the resulting rebuild.
- The earlier Surface bookmark flow has been superseded in this reader by type-level defaults.

## Type-level reader editor

- The reader now opens the Studio in Gallery-only mode. It edits NewsSection, NewsStory, and NewsGrid as catalog types, not individual instances. Selecting a default rebuilds the current A2UI surface so every instance of that type updates immediately.
- The reader decorates components to retain triple-click and long-press gestures. A gesture opens the editor on that component's type, without an individual selection outline or item-level editor. Previously saved type defaults are retained; role overrides are ignored when loading old profiles.
- Save profile is enabled only when the profile changed. Discard unsaved defaults restores the saved profile and rebuilds the current feed.
