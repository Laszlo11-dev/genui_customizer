# Release preparation

This guide covers the pub.dev library and the separate GitHub Pages reader demo. Preparing or validating either artifact does not publish it.

## Source of truth

| Item | Maintained source |
| --- | --- |
| Package version, SDK constraints, metadata | [`pubspec.yaml`](../pubspec.yaml) |
| Release history and pending changes | [`CHANGELOG.md`](../CHANGELOG.md) |
| Public integration and compatibility | [`README.md`](../README.md) |
| RSS reader behavior and run instructions | [`example/README.md`](../example/README.md) |
| Additional chat sample | [`examples/a2ui_flutter_chat/README.md`](../examples/a2ui_flutter_chat/README.md) |
| SDK selected for development | [`.fvmrc`](../.fvmrc) |
| Package archive exclusions | [`.pubignore`](../.pubignore) |
| CI checks and Pages deployment | [`.github/workflows`](../.github/workflows/) |

The package and both samples require Flutter >=3.47.0 and Dart >=3.13.0. Development and CI use Flutter 3.47.9. If changing that pin, update `.fvmrc` and both workflow files together.

## Version and changelog before publishing

The working tree still declares **0.2.1**. Changes since that heading are collected under **Unreleased**; no new release number or publication date has been assigned by this preparation pass.

The pending changes include a source-breaking constructor change: `const TouchProfile()` becomes `const TouchProfile.empty()`, while profiles with rules use the non-const `TouchProfile(...)` constructor. The minimum Flutter version also rises to 3.47. Choose an unused version suitable for these compatibility changes before publishing; **0.3.0** is the intended next minor line if releasing them after 0.2.x. Confirm the version against the publication target when cutting the release.

Move the Unreleased entries under the selected version, update `pubspec.yaml`, and replace the README's temporary Unreleased compatibility note with the selected release number. Preserve the older changelog sections as history. The reader's `0.1.0+1` is its own sample application version, not the library version; both sample manifests have `publish_to: none`.

## Local checks

Run from a fresh repository checkout using the selected Flutter SDK. With FVM, prefix `flutter` and `dart` with `fvm`. These commands do not publish anything.

At the repository root:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
dart run skills_lint
```

For the reader:

```bash
cd example
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
flutter build web --release --no-pub --base-href /genui_customizer/
flutter build windows --release --no-pub
cd ..
```

For the chat sample:

```bash
cd examples/a2ui_flutter_chat
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
flutter build web --release --no-pub
cd ../..
```

The Windows build requires Windows with Flutter's desktop build tools. The web commands above use the JavaScript target; a successful build does not establish WebAssembly support. Other declared library platforms still require their own platform checks when included in a release's validation claims.

If a copied or moved app reports a CMake cache/source path mismatch, run `flutter clean` and `flutter pub get` in that app, then rebuild. Do not copy `build/` or generated `windows/flutter/ephemeral/` between samples.

## Archive review

At the root, run:

```bash
dart pub publish --dry-run
```

Review the listed files and all validation output. The archive must contain the library, public README/changelog/license, integration skill, tests, the main runnable `example/` reader, and the chat sample in `examples/a2ui_flutter_chat/`, including its upstream Apache 2.0 notices. Historical images, internal handover/design/release notes, repository tools, build output, caches, local IDE files, and credentials are excluded. The package's PolyForm Perimeter license is unchanged.

Pub warns about the plural `examples/` directory because its convention recognizes `example/` as the primary sample. Keep both samples in the archive at their current paths; this layout warning does not justify excluding the chat sample.

The old 0.1.x screenshots were removed from package metadata and the current README because they show the discontinued host. Add screenshots only after capturing and checking the current reader; keep the descriptions, files, and `screenshots` metadata in sync.

A dirty-tree warning is expected while preparing changes. Review and commit the intended release, verify the archive again from that clean revision, and resolve version warnings before publishing. A dry run with warnings is not a clean publication gate. Actual publishing, pushing a tag, and creating a hosted release are separate actions.

## Reader deployment and manual check

The Pages workflow builds `example/` with `/genui_customizer/` as the base path and no Gemini key. It runs reader formatting, analysis, and tests before building. A push affecting its configured paths on `main`, or manual workflow dispatch, can deploy the demo; committing locally does not deploy it. The package and both samples are also checked by the separate CI matrix.

Before announcing a deployed demo, verify its actual deployed revision and exercise Settings → Demo feed, the one-minute tour, original article links, Remote/Local selection, a Touch edit/save/reload, and the narrow layout. The bundled feed is a fixed snapshot; publisher images and links need network access. Live feed access is subject to CORS in browsers. Do not describe local demo roles as authenticated or synchronized accounts.

Ask AI is optional. The reader has its own HTTP client and the chat uses a separate streaming client. Mocked tests establish retry/failure behavior, not live model availability. Verify live generation separately if advertising it. A compiled API key is visible to the app's recipient; the sample supplies no public server-side AI proxy.

## Validation record: 2026-11-16

- Reader: all 57 tests passed, including nested triple-click selection, configuration storage, feed parsing, AI response handling, rendering, and the guided tour.
- Reader web release build with the Pages base path succeeded. The build reported a dependency WebAssembly dry-run incompatibility in `video_player_web` and a missing CupertinoIcons font warning. These did not block the JavaScript build; WebAssembly and all icon glyphs have not been certified.
- Reader Windows release build succeeded.
- Package tests: all 14 passed. Chat tests: all 8 passed.
- Package and reader analysis passed. Formatting passed for all 41 Dart files across the package and both samples; the integration skill validator passed and local Markdown links resolved.
- The chat JavaScript web release build also succeeded, with the same dependency WebAssembly and CupertinoIcons warnings as the reader.
- Archive review must retain both samples. The dry run reports the plural `examples/` layout warning, a dirty-working-tree warning, and a version-sequence hint. Keep the chat sample included; commit the reviewed changes, select the release version, and rerun before publishing.

No package publication or Pages deployment was performed during this preparation. Live RSS availability, live Gemini generation, and the currently deployed site's revision were not validated by these local builds and mocked tests.
