# GenUI Touch for A2UI Flutter

This directory is the development snapshot used for the 0.2.0-dev.1 migration.
The publishable package and current example now live at the repository root.

`genui_customizer` 0.2.0-dev.1 is a new package implementation for A2UI v1.0. It requires `a2ui_core` 0.7.x, `a2ui_flutter` 0.3.x, and Flutter 3.38 or later. It does not expose the previous `genui` API.

The host still owns the A2UI `MessageProcessor`, catalogs, actions, data bindings, authorization, and storage. Touch decorates approved component builders for runtime selection, edits approved literal presentation properties through A2UI updates, and layers saved defaults onto later agent messages. `GenUiTouchStudio` offers a Surface editor and a runtime Gallery with editable component defaults. A host can supply a live Gallery preview widget.

Run the [official A2UI chat example adapted with Touch](example/) using `flutter run` in `next/example`. Without an API key it uses a fixed demo reply; with `GEMINI_API_KEY` it uses the upstream Gemini client. Long press a Text component or open Studio from the chat toolbar. The Studio floats above the chat, can be moved and resized, and has Surface and Gallery tabs.

## Integration

```dart
final base = basicCatalog(); // package:a2ui_flutter/basic_catalog.dart
final touch = GenUiTouchController(contracts: [
  TouchContract(
    catalogId: base.id,
    componentType: 'Text',
    properties: const [
      TouchProperty(
        name: 'variant', label: 'Text style',
        kind: TouchValueKind.choice, choices: ['body', 'caption'],
      ),
    ],
  ),
]);
final processor = MessageProcessor<ComponentImplementation>(
  catalogs: [touch.decorateCatalog(base)],
);
touch.attachProcessor(processor);
touch.processAgentMessages(agentMessages);
// Render A2uiSurface(surface: processor.model.getSurface(surfaceId)!).
// Open showGenUiTouchStudio(context: context, controller: touch, surfaceId: surfaceId).
```

Every agent message destined for the attached processor must pass through `processAgentMessages` to receive saved appearance rules. The message must declare A2UI version `1.0`. The host provides `TouchStorage` to save and load a `TouchProfile`; scope it to the correct user or tenant. To reuse a local edit across regenerated content, provide a `TouchRoleResolver`, then call `setRoleDefaultForSelection` on the desired property. Gallery defaults apply to future component updates; they do not rewrite already rendered surfaces. Local component edits support undo and redo until an agent update replaces that component.

Touch edits only properties the host lists in a contract. Choose presentation literals that the catalog schema permits. The editor refuses dynamic `@path` and `@call` values. A2UI remains responsible for validating schemas and rendering components, and Touch preserves the catalog ID and functions when it wraps builders. The optional `TouchPropertyComposer` lets the host propose a value with AI; Touch checks the proposal against the same contract before applying it.

The Studio uses a floating, movable, resizable dialog with a two-pane editor. Its bounds are stored locally by default. Gallery previews are supplied by the host through `galleryPreview`; the example supplies a simple preview. Appearance persistence requires a host `TouchStorage` implementation.
