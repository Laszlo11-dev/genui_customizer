## Unreleased

### Breaking API changes

- Replace `const TouchProfile()` with `const TouchProfile.empty()` for constant empty profiles; profiles with rules now use the non-const `TouchProfile(...)` constructor.
- Declare Flutter 3.47 as the minimum matching the Dart 3.13 SDK constraint. Repository development and CI use Flutter 3.47.9.

### A2UI Tech Reader

- Replace the main `example/` host with an RSS/Atom reader. Flutter owns the shell and source controls; A2UI renders news pages, sections, stories, grids, and loading, empty, and error states.
- Add Everyday, Christmas, Winter Games, and Easter editions, plus optional prompt-driven Ask AI presentation. AI changes appearance and UI headings while article content and original links remain feed-owned.
- Add remote occasion configurations and local user preferences. Save complete occasion data and apply local appearance after remote appearance; all demo records are stored on the current installation.
- Add Tenant editor, Joe, Fred, and Emily demo roles, Gallery-only type editing, whole-page colors, reset controls, and Emily's custom pink palette.
- Add a bundled Demo feed and a five-scene, one-minute guided tour with narration text, animated selection cues, temporary edits, and restoration on close.
- Add feed download limits, relative-link resolution, category-based political filtering, and preservation of the last loaded articles after a refresh error.
- Add Gemini 503 retry and timeout fallback handling, with saved Ask AI layouts available without a generation key.

### Touch and chat fixes

- Keep button actions working when their labels are decorated for Touch selection. Preserve triple-click selection of the innermost decorated component and long-press editing.
- Ignore blank chat prompts and sends after session disposal; cover actions, repeated prompts, stream failures, cancellation, and retry with regression tests.
- Document clean regeneration of Windows build files after an example directory is moved or copied.

### Persistence and Studio reliability

- Add `TouchConfiguration`, separate remote/local store interfaces, default local stores, and `useConfigurations` with a callback for saving the selected layer.
- Keep asynchronous profile loads from replacing newer edits or configuration selections.
- Clear local undo history when its surface is deleted, and retain undo/redo entries if replay fails.
- Copy configuration data into immutable JSON values at construction.
- Refresh an open Studio when its surface or controller changes, and keep widget builds free of state writes.
- Use `SharedPreferencesAsync` for configuration storage and migrate existing package keys from the legacy store.
- Keep profile rules immutable, including nested JSON values, so callers cannot change saved state through shared maps.
- Keep asynchronous saves tied to the profile and configuration selected when saving began.

### Publication preparation

- Align reader, package, chat, and integration documentation with the current app structure and storage boundaries.
- Include both the main RSS reader in `example/` and the chat sample in `examples/a2ui_flutter_chat/` in the published package. Exclude internal handover/design notes from the archive.
- Remove the earlier 0.1.x screenshots from package metadata and the current README; they do not represent the A2UI reader.
- Check the package and both samples in CI, and validate the reader before building the Pages deployment.

## 0.2.1

- Release the A2UI v1.0 rewrite as a stable package. This is a breaking change from the 0.1.x `genui` API.
- Enable Flutter lint rules for the package and fix the issues reported by pub.dev static analysis.
- Keep the existing PolyForm Perimeter license.

## 0.2.0-dev.1

- Rebuild GenUI Touch for A2UI v1.0 with `a2ui_core` 0.7.x and `a2ui_flutter` 0.3.x.
- Add runtime component selection, approved literal property editing, undo and redo, and a floating Surface and Gallery Studio.
- Add host-managed appearance profiles and an adapted A2UI chat example with an offline demo.
- Remove the previous `genui` API; this prerelease is not source compatible with 0.1.x.

## 0.1.1

- Persist the Studio window position and size by default, with configurable storage.
- Restore widget selection when reopening the Studio.
- Update integration guidance and add regression coverage for Studio persistence.
- Exclude local product demo working files from the published package.

## 0.1.0

- Embed a runtime property editor in Flutter GenUI catalogs.
- Edit approved properties locally or through an optional AI composer.
- Save, restore, and apply appearance preferences to newly generated content.
- Include a Restaurant Finder example based on the official A2UI sample.
