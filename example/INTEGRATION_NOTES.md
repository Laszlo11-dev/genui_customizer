# Reader integration notes

These notes describe the current integration. See [README.md](README.md) for usage and the repository [release guide](../doc/RELEASING.md) for validation and publication. This internal document is excluded from the package archive.

## Ownership and lifecycle

- `main.dart` starts the app; `reader_app.dart` owns the processor, controller, feed lifecycle, configurations, AI layout service, and outbound article actions.
- One processor remains attached to Touch for the lifetime of the reader. Refreshes replace the A2UI surface, and every builder message passes through `processAgentMessages`.
- The JSON inspector shows builder output before remote/local appearance defaults are applied.
- The reader uses Gallery-only editing for NewsPage, NewsSection, NewsStory, and NewsGrid. Defaults apply by catalog type and rebuild the current surface immediately. Old reader type defaults are retained; old item-role overrides are ignored.

## Appearance and storage

- Remote occasion appearance is applied first, followed by local user preferences. Default stores use `SharedPreferencesAsync`; package configuration keys migrate from legacy shared preferences. The reader's older single-profile key is a separate compatibility path.
- Remote records include complete occasion data. Profile-only saves and full occasion saves have different purposes; the README describes the controls.
- Demo roles do not provide authentication, authorization, or synchronization. Emily has a custom 12-color pink palette; other roles use the default 16-color chooser. Existing valid colors outside the offered palette remain visible.
- Text and numeric edits apply valid input while typing. Resetting an override reveals generated values; discarding changes restores the saved profile.
- Touch observes short primary-pointer taps without consuming button taps. Nested decorated components must count each pointer event once, for the innermost component. Reader and chat tests cover nested triple-click selection and button actions.

## External dependencies and limits

- The bundled Demo feed is deterministic. Live feeds, images, and original article links depend on their publishers; browser feed access depends on CORS.
- Native downloads enforce the size limit while streaming; the browser checks it after buffering. Parsing is outside the network timeout.
- Ask AI is optional and uses the reader's own HTTP client. A saved AI layout can be opened without a generation key. A public AI-enabled deployment needs a server-side proxy, which this sample does not supply.
- Narration in the guided tour is on-screen text, not audio. Tour edits are temporary and previous reader context is restored on close.
- Unsaved-profile detection uses object identity. Returning a value manually to its saved value can still leave the Save control enabled.
