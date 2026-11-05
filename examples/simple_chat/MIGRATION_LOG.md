# Simple Chat → GenUI Touch migration log

Source: https://github.com/flutter/genui/tree/584d10327d95f4baaf2553ca167b92bd56816b39/examples/simple_chat

Upstream revision: `584d10327d95f4baaf2553ca167b92bd56816b39`.
Migration date: 2026-11-05. This is a local adaptation, not an upstream change.

## Findings and decisions

| Area | Problem / ambiguity | Decision and status |
| --- | --- | --- |
| Version compatibility | Upstream main imports `package:genui/a2ui_core.dart`; published GenUI 0.10.4 exposes those types through the separate `a2ui_core` package. | Adapt imports and declare the direct dependency. Compile against published packages rather than a Git dependency. Dependency resolution and analysis pass. |
| Workspace | Upstream uses `resolution: workspace` and depends on its monorepo configuration. | Remove workspace resolution, add the local Touch dependency at `../..`, and require Dart 3.13, matching Touch. |
| Multiple surfaces | Different chat replies can each contain a component named `root`. Touch currently finds components by component ID inside its snapshot. A combined snapshot could edit the wrong reply. | Give every surface its own Touch controller and route catalog selection using `surfaceId`. No change to Touch's public API. |
| Incremental updates | A2UI component updates can contain only some components. Replacing the complete editable snapshot loses the rest of the surface. | Merge updates by component ID within each surface. Agent updates replace the components they name; untouched components retain local edits. Each incoming component update rebases the editor and clears its undo/discard history. |
| Surface deletion | A reply can be removed while its editor is open. Replaying edits into a deleted surface would create stale buffered updates. | Remove its editor from the active lookup, close its floating studio, and ignore later snapshot publications from that retired controller. Dispose retired controllers with the conversation so open listeners can detach safely. |
| Custom catalog | The upstream README says there is no custom catalog, but current source has Basic, Custom, and Text-only modes, with a composite `ClimbingLocation` card. Internal Flutter children are not separate A2UI components. | Preserve all modes. Expose card density and image visibility as explicit visual properties; keep identifiers, content, bindings, actions, and structure protected. |
| Property editor types | Touch's contract accepts booleans, strings, and numbers, but its default generated property editor currently only renders enumeration controls. A boolean image toggle would validate but have no visible control. | Use `imageVisibility: show/hide` and `density: comfortable/compact` enumerations in this host. No unsupported boolean control is advertised. A general boolean editor would be a separate Touch library change. |
| Widget test selectors | The tree humanizes `ClimbingLocation` as “Climbing location”; Save is a text button at desktop widths and an icon in compact layouts. | Regression tests use stable tree/property keys and the desktop Save button rather than assuming internal type names or a universal Save tooltip. |
| Web build warnings | GenUI brings in `video_player_web`, whose DOMException runtime check triggers a Wasm dry-run warning. A Cupertino icon font reference is also reported without a bundled Cupertino font. | Standard JavaScript release build succeeds. Wasm output is not claimed or validated. These transitive/upstream warnings are recorded rather than suppressed. |
| Saving | Chat surface/component IDs are not stable presentation roles across independent conversations. Reusing raw saved surfaces could restore old content. | Save/discard checkpoints are in memory for the current conversation. No persistence across restart, new mode, or unrelated replies. Cross-conversation appearance profiles need a host-defined role contract and remain outside this migration. |
| AI editing | The upstream AI client generates chat replies; it does not implement Touch's constrained property-edit composer. | Preserve chat generation. Do not advertise Touch AI editing or proposal generation without a separate adapter. Manual Touch editing works independently. |
| Credentials | The upstream live client requires a Gemini key, including at application startup. | Retain upstream key loading for live mode; add an explicitly labeled recorded demo client for key-free local verification. Never bundle a real key. |
| Platforms | The source example has runners for six platforms. | Include the upstream web and Windows runners for this adaptation; other runners can be generated with Flutter if needed. Android/iOS/Linux/macOS are not validated here. |
| Distribution | A second demo should not inflate the library's pub archive. | Keep `examples/` in Git and exclude it from pub with the root `.pubignore`. The existing `example/` remains the default pub example. |
| Test dependencies | Upstream includes platform integration-test dependencies, but this adaptation uses its unit/widget tests and adds migration widget tests. | Omit unused `integration_test` and `network_image_mock` dependencies. Keep an application lockfile for this standalone demo. |
| Attribution | Copied source and AI-generated climbing images originate in Flutter's GenUI repo. | Retain copyright headers, upstream BSD license, and the image provenance README. |

## Verification

Verified on Windows with Flutter 3.47.9 / Dart 3.13.7:

| Check | Result |
| --- | --- |
| `flutter pub get` | Pass. Published GenUI 0.10.4 and a2ui_core 0.1.1 resolve with the local Touch package. |
| `dart format lib test` | Pass; source formatted. |
| `dart analyze lib test` | Pass, no issues. |
| `flutter test --no-pub` | Pass, 12 tests: 3 upstream tests and 9 migration tests. |
| `flutter build web --release --no-pub` | Pass. Output: `build/web`. Transitive Wasm dry-run and missing Cupertino font warnings noted above. |
| Root `dart pub publish --dry-run` | Package validation has one warning for the uncommitted README. Verified that `examples/simple_chat` is absent from the archive listing. No package was published. |
| Secret/local-path signature scan of the added example source | No matching key signatures or personal filesystem paths found. |

Migration regression coverage includes duplicate IDs across replies, component
delta merging, authoritative agent replacement, save/discard checkpoints,
protected bindings and structure, data updates and deletion, recorded streaming
through the real parser, original button submissions, gesture routing to the
second reply, and opening/editing/saving/reopening the custom-card editor.

Tests use recorded output or fake clients. No real Gemini request was made.
The web release build was compiled but not manually inspected in a browser.
The Windows runner was copied but not compiled.

## Remaining limitations

Tracked follow-up issues:

- [#1: Render boolean, string, and number controls in the default property editor](https://github.com/Laszlo11-dev/genui_customizer/issues/1) — suggested priority: high.
- [#2: Scope component lookup and edits by surfaceId and componentId](https://github.com/Laszlo11-dev/genui_customizer/issues/2) — suggested priority: high.
- [#3: Support incremental A2UI component updates without resetting unrelated edit history](https://github.com/Laszlo11-dev/genui_customizer/issues/3) — suggested priority: medium.

- Live model behavior and a real Gemini request require a user-provided key and are not proven by recorded tests.
- Save checkpoints last only for the current conversation. Switching modes starts a new conversation.
- Streaming component updates rebase that surface's editing history; the agent is authoritative for components it updates.
- Only properties explicitly listed in the editable registry are editable.
