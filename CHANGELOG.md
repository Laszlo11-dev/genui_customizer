## Unreleased

- Keep asynchronous profile loads from replacing newer edits or configuration selections.
- Clear local undo history when its surface is deleted, and retain undo/redo entries if replay fails.
- Copy configuration data into immutable JSON values at construction.
- Refresh an open Studio when its surface or controller changes, and keep widget builds free of state writes.
- Use `SharedPreferencesAsync` for configuration storage and migrate existing package keys from the legacy store.
- Declare Flutter 3.47 as the minimum matching the Dart 3.13 SDK constraint.
- Keep profile rules immutable, including nested JSON values, so callers cannot change saved state through shared maps.
- Keep asynchronous saves tied to the profile and configuration selected when saving began.
- Replace `const TouchProfile()` with `const TouchProfile.empty()` for constant empty profiles; profiles with rules now use the non-const `TouchProfile(...)` constructor.

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
