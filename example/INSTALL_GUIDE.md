# Install and integrate `genui_customizer`

This guide uses the Restaurant Finder example as a complete integration of the
standalone package. It adapts the [official A2UI Flutter Restaurant Finder
client](https://github.com/a2ui-project/a2ui/tree/43696ef4309eaa08d5cf25106718703daeaf6d88/samples/client/flutter/restaurant_finder)
at commit `43696ef4309eaa08d5cf25106718703daeaf6d88`. Copied code and
assets retain their upstream notices and `UPSTREAM_LICENSE`. The file map
below explains the example's source and the changes to make in another host.
All numbered changes are already implemented in this example. Apply them only
when adding the published package to a different, existing GenUI client. The
code in steps 3–6 assumes a `RestaurantSession extends ChangeNotifier` with
an A2UI connector and `SurfaceController`, as in this example; keep your
existing transport and replace the Restaurant Finder roles with your own.

## Run the example

From the example directory, run:

```sh
flutter pub get
flutter run -d chrome
```

Use `windows` instead of `chrome` for Windows desktop. In Android Studio,
choose a **Flutter** run configuration with entrypoint `lib/main.dart`. A Dart
command-line run configuration cannot run Flutter widgets. The example replays bundled A2UI
responses and needs no server, account, API key, or Firebase configuration.

Search once, select **Customize results**, edit an image or text style, and
save. Search again to see that style on different restaurant data. Restart
the app to check persistence. **Reset saved appearance** removes the saved
role rules and gallery defaults; search again to see the agent's original
styles. A desktop triple click or touch long press also opens the selected
widget in GenUI Touch.

## 1. Add the dependency

After the standalone package is published on pub.dev, add it to the host
application's `pubspec.yaml` alongside its existing `genui` dependency:

```yaml
dependencies:
  genui: ^0.10.3
  genui_customizer: ^0.1.0
  shared_preferences: ^2.5.3
```

Use the published version compatible with your app when it is available.
The example also depends on `a2ui_core` and `genui_a2a` for its existing A2UI
transport, and `logging` for the copied client. Those are not additional customizer
requirements. The customizer requires Dart 3.13 or newer and Flutter 3.35 or
newer. Keep the host application's lockfile reproducible.

## 2. Define the editable catalog contract

`lib/src/session.dart` defines `RestaurantSession.editableRegistry`. Its
`catalogId` matches the catalog advertised by the agent; `catalogVersion` is
owned by the host. Each `EditableComponentContract` names a GenUI component.
The example allows only `Image.variant` and `Text.variant`, with enum values
matching the Basic Catalog. `Image.url`, children, and `Text.text` are
protected. Other Basic Catalog components have empty property lists so they
can appear in GenUI Touch tree without offering edits.

Replace these contracts with the actual components and visual properties in
your catalog. Keep content, data bindings, actions, IDs, and child links out
of editable properties. Manual and AI patches are validated against this
registry. Increment `catalogVersion` when the meaning or set of editable
properties changes; old profiles are rejected until explicitly migrated.

## 3. Attach the controller and decorate the rendering catalog

`RestaurantSession` calls `GenUiCustomizer.attach` before it creates the
`SurfaceController`:

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
final decorated = basic.copyWith(
  newItems: [
    for (final item in basic.items)
      decorateEditableCatalogItem(item, editor),
  ],
);
_surfaceController = SurfaceController(catalogs: [decorated]);
```

Decorate the catalog passed to the surface renderer. The decorator preserves
each item's schema and widget builder and adds selection gestures to
components admitted by the registry. The example overrides the Basic Catalog
ID because its GenUI dependency otherwise supplies a different default ID
from the upstream agent. A host whose IDs already match needs no override.
Dispose the controller with its owning session.

The callback storage exposes the current baseline to GenUI Touch reload and turns
a GenUI Touch save into a reusable appearance profile. It does not persist raw
agent messages as a long-term preference. Another application may provide a
different `EditableGenUiStorage` adapter.

## 4. Feed generated updates to the editor — required

**Edit the class that owns your agent stream and `SurfaceController`.** The
example's file is `lib/src/session.dart`. Ensure it imports
`import 'package:a2ui_core/a2ui_core.dart' hide Catalog;`,
`import 'package:genui/genui.dart';`, and
`import 'package:genui_customizer/genui_customizer.dart';`. Add the following field and
methods to `RestaurantSession`. In its existing stream setup, replace the UI listener
with `_connector.stream.listen(_handleUiFromAgent)`. These methods use the
profile fields and role resolver added in step 5.

```dart
GenUiEditSnapshot? _baseline;

void _handleUiFromAgent(A2uiMessage message) {
  if (message is! UpdateComponentsMessage) {
    _surfaceController.handleMessage(message);
    return;
  }

  final raw = Map<String, Object?>.from(message.toJson());
  final visible = _profile?.applyToMessage(
        message: raw,
        registry: editableRegistry,
        roleFor: componentRole,
      ) ??
      raw;
  _baseline = GenUiEditSnapshot(revision: 1, messages: [visible]);
  editor.setSurfaceSnapshot(_baseline!);
}

void _renderEditedSnapshot(GenUiEditSnapshot snapshot) {
  for (final json in snapshot.messages) {
    if (json['updateComponents'] != null) {
      _surfaceController.handleMessage(A2uiMessage.fromJson(json));
    }
  }
  notifyListeners();
}

void _clearPreviousResult() {
  for (final id in [..._surfaceController.activeSurfaceIds]) {
    _surfaceController.handleMessage(DeleteSurfaceMessage(surfaceId: id));
  }
  _baseline = null;
  editor.setSurfaceSnapshot(
    const GenUiEditSnapshot(revision: 1, messages: []),
  );
}
```

In `RestaurantSession._sendMessageToAgent`, call `_clearPreviousResult()`
immediately before the recorded replay or `_connector.connectAndSend(...)`.
Do the equivalent before any other request that replaces the result. The
controller construction in step 3
must pass `onSnapshotChanged: _renderEditedSnapshot`. Do **not** also send the
original `UpdateComponentsMessage` to `_surfaceController`: the controller
callback already renders the profiled message. The example's actual handler
also calls `_applyGalleryDefaults(raw)` before applying the profile; add that
only if implementing the optional gallery defaults in step 6.

This code matches the recorded example's one component update per search. If
your agent sends several updates for one surface, first merge them into the
current editable definition; otherwise each `setSurfaceSnapshot` replaces the
previous editable snapshot.

## 5. Persist reusable appearance — required for saved styles

**Edit the same session class.** Add `import 'dart:convert';` and
`import 'package:shared_preferences/shared_preferences.dart';`. Add these
fields and methods inside `RestaurantSession`. The role resolver is specific to the Restaurant
Finder's A2UI bindings; replace its mapping with your own stable presentation
roles when integrating a different catalog.

```dart
static const _profileKey = 'restaurant_finder_appearance_v1';
GenUiAppearanceProfile? _profile;
late final Future<void> _profileReady;

Future<void> get appearanceReady => _profileReady;

static String? componentRole(Map<String, Object?> component) {
  if (component['component'] == 'Text' && component['text'] == 'Book Now') {
    return 'restaurant-book-label';
  }
  final binding = switch (component['component']) {
    'Image' => component['url'],
    'Text' => component['text'],
    _ => null,
  };
  if (binding is! Map || binding['path'] is! String) return null;
  final path = binding['path'] as String;
  if (component['component'] == 'Image' && path.endsWith('imageUrl')) {
    return 'restaurant-image';
  }
  if (component['component'] == 'Text') {
    for (final field in const ['title', 'name', 'rating', 'detail', 'infoLink']) {
      if (path.split('/').last == field) return 'restaurant-$field';
    }
  }
  return null;
}

Future<void> _loadAppearance() async {
  final saved = await SharedPreferencesAsync().getString(_profileKey);
  if (saved == null) return;
  try {
    final profile = GenUiAppearanceProfile.fromJson(
      Map<String, Object?>.from(jsonDecode(saved) as Map),
    );
    if (profile.catalogId == editableRegistry.catalogId &&
        profile.catalogVersion == editableRegistry.catalogVersion) {
      _profile = profile;
    }
  } on FormatException {
    // Ignore an obsolete or invalid local profile.
  }
}

Future<void> _saveAppearance(GenUiEditSnapshot edited) async {
  final before = _baseline;
  if (before == null) return;
  final profile = GenUiAppearanceProfile.capture(
    before: before,
    after: edited,
    registry: editableRegistry,
    roleFor: componentRole,
    previous: _profile,
  );
  if (jsonEncode(profile.toJson()) == jsonEncode(_profile?.toJson())) {
    throw const FormatException('This widget has no reusable appearance role.');
  }
  await SharedPreferencesAsync().setString(
    _profileKey,
    jsonEncode(profile.toJson()),
  );
  _profile = profile;
  _baseline = edited;
}

Future<void> resetAppearance() async {
  await SharedPreferencesAsync().remove(_profileKey);
  _profile = null;
  notifyListeners();
}
```

Initialize `_profileReady = _loadAppearance();` at the end of the
`RestaurantSession` constructor. In `_sendMessageToAgent`, insert
`await _profileReady;` before the replay or `_connector.connectAndSend(...)`.
This
ensures step 4 applies the stored profile on the first result. The controller
construction in step 3 already connects its `storage` adapter to
`_saveAppearance` and `_baseline`.

`GenUiAppearanceProfile.capture` rejects structural and protected changes.
Returning `null` from `componentRole` means that component's edits cannot be
saved for future results. The JSON is local example storage. A multi-user
host must replace `SharedPreferencesAsync` with identity-aware storage and
enforce authorization there. Keep the catalog ID/version check and migrate or
discard old profiles when the catalog changes.

## 6. Add a visible GenUI Touch action — required

**Edit the screen that renders your GenUI surfaces.** The example's file is
`lib/src/screen.dart`. Import `package:genui/genui.dart` and
`package:genui_customizer/genui_customizer.dart`. In its `State`, use this
session setup and GenUI Touch method. Use the same session and controller that
render the surface.

```dart
late final RestaurantSession _session;
bool _studioOpen = false;

@override
void initState() {
  super.initState();
  const agentUrl = String.fromEnvironment('GENUI_CUSTOMIZER_AGENT_URL');
  _session = RestaurantSession(
    serverUrl: agentUrl.isEmpty ? defaultServerUrl : agentUrl,
    useRecordedResponses: agentUrl.isEmpty,
    onEditorRequested: _openStudio,
  );
}

Future<void> _openStudio() async {
  if (_studioOpen) return;
  _studioOpen = true;
  try {
    await _session.appearanceReady;
    if (!mounted) return;
    final catalog = BasicCatalogItems.asCatalog();
    await showEditableGenUiStudio(
      context: context,
      controller: _session.editor,
      galleryTypes: catalog.items.map((item) => item.name),
      galleryCatalog: catalog,
    );
  } finally {
    _studioOpen = false;
  }
}
```

In the widget tree next to the rendered results, add this row:

```dart
Row(
  children: [
    TextButton.icon(
      onPressed: _openStudio,
      icon: const Icon(Icons.tune),
      label: const Text('Customize results'),
    ),
    TextButton(
      onPressed: _session.resetAppearance,
      child: const Text('Reset saved appearance'),
    ),
  ],
),
```

`showEditableGenUiStudio` requires `galleryTypes`; use the names from your
own rendering catalog instead of `BasicCatalogItems` if your host has a
custom catalog. The `onEditorRequested` callback connects triple click and
long press selection to this same dialog. The visible action remains useful
when users do not know those gestures. Dispose `_session` in the screen's
`dispose()` method, as the example does.

The following additions are **optional**:

- **Type-wide gallery defaults:** Supply `loadDefaults` and `saveDefaults`
  to `showEditableGenUiStudio` only if users may save a style for *every* new
  component of a type. The example validates and stores these values under
  `restaurant_finder_gallery_defaults_v1`. Apply them before role-specific
  rules in step 4; a role rule then takes precedence.
- **Window placement:** GenUI Touch remembers its movable, resizable window
  by default using app-local shared preferences. Pass
  `boundsPersistence: null` to disable this, or supply `loadBounds` and
  `saveBounds` together to use your own storage.
- **AI editing:** Supply an `EditableGenUiComposer` to
  `GenUiCustomizer.attach` if you provide a trusted backend for privileged
  credentials and authorization. GenUI Touch's `onGenerateProposal` is a
  separate host-provided agent operation. Neither is needed for manual edits.

## File-by-file source inventory

| File | What it contributes and why |
| --- | --- |
| `pubspec.yaml` | Declares the customizer and device storage dependencies, sets the effective Dart/Flutter minimums, and bundles the recorded responses and images. A consuming app uses the published package version. |
| `lib/main.dart` | Keeps the Flutter entrypoint as a small handoff to `src/main.dart` for a conventional run configuration. |
| `lib/src/main.dart` | Keeps the Restaurant Finder app, Material theme, and theme toggle. Customizer initialization is scoped to the session, not the application root. |
| `lib/src/session.dart` | Holds the contracts, decorated catalog, controller, A2UI interception, role mapping, profile and gallery persistence, transport choice, reset, and disposal. This is the main integration file. |
| `lib/src/screen.dart` | Renders generated surfaces and adds GenUI Touch/reset actions; supplies GenUI Touch's gallery and bounds adapters. |
| `lib/src/studio_bounds_store.dart` | Demonstrates a custom window placement adapter; the package also persists bounds by default. |
| `lib/src/primitives.dart` | Keeps ordinary Restaurant Finder UI helpers: theme button, error banner, and loading text. No customizer API is needed here. |
| `assets/first_search.json`, `assets/next_search.json` | Record two agent responses so saved appearance can be exercised against different data and component IDs without a live agent. |
| `assets/images/` | Holds restaurant images referenced by recorded results. |
| `web/`, `windows/` | Provide Flutter platform runners. There is no platform-specific customizer hook. |
| `test/restaurant_customization_test.dart` | Verifies role-based style transfer to the second response while its restaurant data remains new. |
| `test/restaurant_persistence_test.dart` | Exercises a GenUI Touch edit, save, new search, and widget restart. |
| `test/restaurant_gallery_persistence_test.dart` | Checks gallery defaults after restart and on newly generated text. |
| `test/restaurant_screen_test.dart` | Checks recorded search, GenUI Touch opening, bounds persistence, and the next response. |

`UPSTREAM_LICENSE` records the copied sample's license. Other example files
are package metadata or generated platform assets, not customizer integration
points. For a host, the required source edits are the dependency, registry,
controller/catalog decoration, message interception, role/profile storage,
and GenUI Touch entry action. Recorded responses, device storage, Gallery view,
and window bounds are example choices.

## Verify the integration

From the example directory, run:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web
```

For another host, also verify immediate preview, style transfer to new
content, unchanged data and actions, persistence after restart, and the
intended migration or rejection when the catalog version changes.
