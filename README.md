# GenUI Touch

**Make generated UI your own.** GenUI Touch adds runtime appearance editing to A2UI Flutter surfaces. A user can select a rendered component, change properties approved by the host app, and see the result immediately. Manual editing does not require an AI service.

> **Breaking change in 0.2.0-dev.1:** GenUI Touch has been rewritten for **A2UI v1.0**, `a2ui_core` 0.7.x, and `a2ui_flutter` 0.3.x. The 0.1.x `genui` API has been removed. Existing 0.1.x integrations must be updated; this release is not source compatible, and it does not automatically migrate saved 0.1.x snapshots or appearance profiles.

**[Try the A2UI chat example in your browser](https://laszlo11-dev.github.io/genui_customizer/).** It uses a fixed offline reply, so no account or API key is needed.

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

The [integration skill](skills/genui-customizer-integration/SKILL.md) gives further host guidance. The [example](example/) adapts the official A2UI Flutter chat app. It runs with a fixed offline demo reply by default and can use Gemini when configured; see its [run instructions](example/README.md). The example does not provide durable appearance storage.

## Migrating from 0.1.x

- Replace the old `genui` based integration with `a2ui_core` 0.7.x and `a2ui_flutter` 0.3.x. Use A2UI v1.0 messages.
- Replace the old editable catalog registry and controller with `TouchContract`, `TouchProperty`, and `GenUiTouchController`. Decorate the catalog used by the host processor and attach that processor to Touch.
- Route incoming messages through `processAgentMessages` instead of maintaining the old editable snapshot flow.
- Rework persistence around the host-owned `TouchProfile` and `TouchStorage`. Migrate old saved data explicitly if your app needs it; automatic migration is not provided.

The [migration plan](doc/a2ui-package-plan.md) records the redesign decisions. For the previous package behavior, use the 0.1.x release and its documentation in Git history.

## Earlier screenshots

These images show the 0.1.x Restaurant Finder host. They illustrate the editing concept, not the current A2UI chat example.

<img src="https://laszlo11-dev.github.io/genui_customizer/doc/images/studio-overview.png" alt="Earlier 0.1.x GenUI Touch Studio over Restaurant Finder" width="400">

<img src="https://laszlo11-dev.github.io/genui_customizer/doc/images/surface-editing.png" alt="Earlier 0.1.x compact editing window" width="400">

<img src="https://laszlo11-dev.github.io/genui_customizer/doc/images/complex-layout-ai-regeneration.png" alt="Earlier 0.1.x complex layout editing" width="400">

## License and status

GenUI Touch is licensed under the [PolyForm Perimeter License 1.0.1](LICENSE). The package is experimental; APIs and behavior may change. It is developed with heavy use of AI, including AI-assisted coding, so integrations should be reviewed and tested in their host apps.
