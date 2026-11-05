# GenUI Touch in a running GenUI app

This Restaurant Finder example adapts Google's A2UI Flutter client. Its copied
source and assets retain their upstream notices and [license](UPSTREAM_LICENSE).
It replays recorded agent responses by default, so no server or API key is
needed.

From this directory, run `flutter pub get` and then `flutter run -d windows`,
`flutter run -d chrome`, or `flutter run -d <android-device-id>`. Search once,
open **Customize results**, change a text or image style, and save. Search again
to see the saved appearance on different generated content.

The executable entry point is [lib/main.dart](lib/main.dart). The following
excerpts come from the tested [RestaurantSession](lib/src/session.dart); the
complete editor UI is in [RestaurantScreen](lib/src/screen.dart).

## Attach editing to the rendering catalog

The host defines `editableRegistry` to allow only the visual properties it
actually renders. The example permits `Text.variant` and `Image.variant` while
protecting their content and bindings. It attaches one editor and decorates the
catalog items used by `SurfaceController`:

```dart
editor = GenUiCustomizer.attach(
  initial: const GenUiEditSnapshot(revision: 1, messages: []),
  registry: editableRegistry,
  storage: CallbackEditableGenUiStorage(
    onLoad: () async => _baseline,
    onSave: _saveAppearance,
  ),
  onSnapshotChanged: _renderEditedSnapshot,
  onEditorRequested: onEditorRequested,
);
final basic = BasicCatalogItems.asCatalog().copyWith(
  catalogId: _agentCatalogId,
);
final List<Catalog> catalogs = [
  basic.copyWith(
    newItems: [
      for (final item in basic.items)
        decorateEditableCatalogItem(item, editor),
    ],
  ),
];
_surfaceController = SurfaceController(catalogs: catalogs);
```

## Preserve appearance across AI regeneration

The example saves a `GenUiAppearanceProfile` using stable, host-defined roles.
Before replacing the current surface, it applies that profile to each newly
generated `updateComponents` message, then gives the resulting snapshot to the
editor:

```dart
final profiled =
    _profile?.applyToMessage(
      message: raw,
      registry: editableRegistry,
      roleFor: componentRole,
    ) ??
    raw;
_baseline = GenUiEditSnapshot(revision: 1, messages: [profiled]);
editor.setSurfaceSnapshot(_baseline!);
```

See the [integration guide](INSTALL_GUIDE.md) for the editable contracts,
selection gestures, local edits, persistence callbacks, and the complete A2UI
message flow. For agent-assisted integration into another existing GenUI app,
use the [Dart Package Skill](../skills/genui-customizer-integration/SKILL.md).
