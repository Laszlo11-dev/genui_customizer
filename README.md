# GenUI Touch

**Make generated UI your own.** GenUI Touch adds runtime appearance editing to A2UI Flutter surfaces. A user can select a rendered component, change properties approved by the host app, and see the result immediately. Manual editing does not require an AI service.

> **Breaking change in 0.2.1:** GenUI Touch has been rewritten for **A2UI v1.0**, `a2ui_core` 0.7.x, and `a2ui_flutter` 0.3.x. The 0.1.x `genui` API has been removed. Existing 0.1.x integrations must be updated; 0.2.1 is not source compatible and does not automatically migrate saved 0.1.x snapshots or appearance profiles.

Requires **Flutter >=3.47.0 and Dart >=3.13.0**. Repository development and CI use Flutter **3.47.9**, selected in `.fvmrc`.

**Breaking change in 0.3.0:** Constant empty profiles use `const TouchProfile.empty()`; profiles with rules use `TouchProfile(...)`, which copies and freezes its JSON values. Code using the earlier `const TouchProfile()` constructor must be updated. See the [changelog](CHANGELOG.md) for the complete release notes.

**[Try the A2UI Tech Reader in your browser](https://laszlo11-dev.github.io/genui_customizer/).** The main example reads technology RSS feeds and lets you edit and save the A2UI news appearance. Its Ask AI feature is optional.

In the reader, choose **Demo feed** in Settings for a bundled RSS snapshot, or use **1-min demo** to see editions, user preferences, and a Touch edit. Feed parsing, A2UI rendering, and manual appearance editing work without an AI key. Reader configurations are saved locally; the Remote and Local labels demonstrate appearance layers rather than synchronized accounts.

## See A2UI and Touch in action

<a href="https://laszlo11-dev.github.io/genui_customizer/media/"><img src="https://laszlo11-dev.github.io/genui_customizer/media/demo-poster.png" width="320" alt="Watch the new narrated, 60-second GenUI Touch demo"></a>

**[Watch the new 60-second narrated demo](https://laszlo11-dev.github.io/genui_customizer/media/)** · [Download the MP4](https://laszlo11-dev.github.io/genui_customizer/media/genui-touch-demo.mp4)

The video records the running reader: A2UI renders the interface, shared and local appearances change the same feed, and a Touch Studio edit updates matching buttons immediately. The reader is an example host for these capabilities.

Click a screenshot to view it at full size.

| Touch Studio | Shared tenant appearance |
| --- | --- |
| <a href="https://laszlo11-dev.github.io/genui_customizer/media/reader-studio.png"><img src="https://laszlo11-dev.github.io/genui_customizer/media/reader-studio.png" width="280" alt="Touch Studio editing NewsStory appearance in the Christmas edition"></a> | <a href="https://laszlo11-dev.github.io/genui_customizer/media/reader-tenant.png"><img src="https://laszlo11-dev.github.io/genui_customizer/media/reader-tenant.png" width="280" alt="A2UI reader with the tenant appearance and the Remote and Local Touch controls"></a> |

| Emily's local preferences | Joe's local preferences |
| --- | --- |
| <a href="https://laszlo11-dev.github.io/genui_customizer/media/reader-emily.png"><img src="https://laszlo11-dev.github.io/genui_customizer/media/reader-emily.png" width="280" alt="Emily's pink appearance applied to the same A2UI content"></a> | <a href="https://laszlo11-dev.github.io/genui_customizer/media/reader-joe.png"><img src="https://laszlo11-dev.github.io/genui_customizer/media/reader-joe.png" width="280" alt="Joe's larger text, stronger contrast, and single-column layout"></a> |

## What it does

GenUI Touch works inside a running host app. **Triple-click** a component on desktop, **long-press** it on touch devices, or select it from the Studio's component tree. The host decides which catalog properties are editable. Touch changes approved presentation literals through the host's A2UI `MessageProcessor`; it does not edit data bindings, actions, component relationships, or identifiers.

The floating Studio has two modes:

| Surface | Gallery |
| --- | --- |
| Edit a component on the current surface. Local edits support undo and redo. | Edit defaults for a catalog component type. Defaults apply to later component updates. |

The Studio can be moved and resized. Its window bounds are stored locally by default. A host can provide a Gallery preview widget and `TouchStorage` for appearance preferences. A local Surface edit is not automatically saved as a reusable preference: the host must assign a stable presentation role, then save a role default for that property.

## Integrate with an A2UI host

The host continues to own the catalogs, `MessageProcessor`, agent transport, action handling, authorization, and storage. Register only visual properties that the catalog schema permits:

```dart
final base = basicCatalog(); // package:a2ui_flutter/basic_catalog.dart
final touch = GenUiTouchController(
  contracts: [
    TouchContract(
      catalogId: base.id,
      componentType: 'Text',
      properties: const [
        TouchProperty(
          name: 'variant',
          label: 'Text style',
          kind: TouchValueKind.choice,
          choices: ['body', 'caption'],
        ),
      ],
    ),
  ],
);

final processor = MessageProcessor<ComponentImplementation>(
  catalogs: [touch.decorateCatalog(base)],
);
touch.attachProcessor(processor);

// Route every incoming A2UI v1.0 message through Touch before rendering.
touch.processAgentMessages(agentMessages);

// Render A2uiSurface(surface: processor.model.getSurface(surfaceId)!).
// Open showGenUiTouchStudio(context: context, controller: touch, surfaceId: surfaceId).
```

Every incoming message for the attached processor must pass through `processAgentMessages`; messages must declare A2UI version `1.0`. Touch applies saved appearance rules to later agent messages before the processor handles them. Incoming agent updates that replace an edited component supersede that component's local undo history.

To persist preferences, implement `TouchStorage`, load its `TouchProfile` before new generated surfaces arrive, and scope storage to the right user or tenant. `setGalleryDefault` saves a default for future components of one catalog type. To carry a selected value across regenerated content with new component IDs, supply a stable `TouchRoleResolver` and call `setRoleDefaultForSelection` for that property, then `save()`. The optional `TouchPropertyComposer` lets a host AI service propose a value; Touch checks it against the same contract before applying it.

For multiple configurations, use `TouchConfiguration` with separate `TouchConfigurationStore` and `TouchLocalConfigurationStore` implementations. Both have shared-preferences defaults and independent `list`, `load`, `save`, and `delete` operations; a host can implement either interface for its own backend. A configuration stores a `TouchProfile` and JSON-compatible host data, such as a complete occasion definition. The host interprets that data and provides the active remote and user profiles to `useConfigurations`. Touch merges remote appearance before local appearance. The Studio edits and saves only the selected profile through `saveEditedProfile`, so the host should save it back into the matching configuration record alongside its occasion data. The existing `TouchStorage` path remains available for single-profile integrations.

The [integration skill](skills/genui-customizer-integration/SKILL.md) gives further host guidance. The main [Tech Reader example](example/README.md) demonstrates an RSS-driven A2UI surface with saved appearance profiles. The [A2UI Flutter chat example](examples/a2ui_flutter_chat/README.md) is also included in the published package under `examples/a2ui_flutter_chat/`. It uses a fixed offline reply by default and can use Gemini when configured.

For catalog color literals, use `TouchValueKind.color`. The Studio shows a current-color swatch and a built-in palette of 16 colors; existing valid `#RRGGBB` and `#AARRGGBB` values remain visible even when they are outside that palette.

Hosts that edit only catalog-wide defaults can open `showGenUiTouchStudio` with `galleryOnly: true`. Pass `onGalleryChanged` to regenerate the current surface after a default changes or is discarded; future agent messages automatically receive the defaults through `processAgentMessages`. Decorated components can still open this mode by triple-click or long-press, with the touched component type selected. Set `showSelectionOutline: false` to avoid an individual-item border.

## Migrating from 0.1.x

- Replace the old `genui` based integration with `a2ui_core` 0.7.x and `a2ui_flutter` 0.3.x. Use A2UI v1.0 messages.
- Replace the old editable catalog registry and controller with `TouchContract`, `TouchProperty`, and `GenUiTouchController`. Decorate the catalog used by the host processor and attach that processor to Touch.
- Route incoming messages through `processAgentMessages` instead of maintaining the old editable snapshot flow.
- Rework persistence around the host-owned `TouchProfile` and `TouchStorage`. Migrate old saved data explicitly if your app needs it; automatic migration is not provided.

The [historical migration plan](https://github.com/Laszlo11-dev/genui_customizer/blob/main/doc/a2ui-package-plan.md) records the redesign decisions. For the previous package behavior, use the 0.1.x release and its documentation in Git history. Maintainers preparing a package or demo release should use the repository's [release guide](https://github.com/Laszlo11-dev/genui_customizer/blob/main/doc/RELEASING.md).

## License and status

GenUI Touch is licensed under the [PolyForm Perimeter License 1.0.1](LICENSE). The package is experimental; APIs and behavior may change. It is developed with heavy use of AI, including AI-assisted coding, so integrations should be reviewed and tested in their host apps.
