---
name: genui-customizer-integration
description: Integrate genui_customizer 0.2.x into an A2UI v1.0 Flutter host for runtime visual edits and reusable appearance preferences. Use with a2ui_core 0.7.x and a2ui_flutter 0.3.x, not the discontinued genui API.
---

# Integrate GenUI Touch with A2UI Flutter

Read the host's catalog, `MessageProcessor`, message path, authorization, and storage boundary first. The host owns those systems and decides which users may edit and persist appearance.

1. Declare `TouchContract` entries for each editable catalog ID and component type. List only presentation literals with `TouchProperty`; the choices must be valid for the host's catalog schema. Do not allow data bindings, actions, component links, or identifiers.
   Use `TouchValueKind.color` for hex color literals when the host wants the Studio's 16-color chooser instead of text entry. Existing valid colors outside the palette still display as swatches.
2. Create one `GenUiTouchController` for the host processor. Pass the contracts, optional stable `roleFor`, and host-owned `TouchStorage`. Decorate the catalog with `controller.decorateCatalog(baseCatalog)`, construct the `MessageProcessor<ComponentImplementation>` with that catalog, then call `controller.attachProcessor(processor)`.
3. Route every incoming A2UI v1.0 agent message through `controller.processAgentMessages(...)`. Render the host processor's surface with `A2uiSurface`. The controller applies saved defaults to later component messages before the processor sees them.
4. Connect `controller.onStudioRequested` to `showGenUiTouchStudio(context: ..., controller: ..., surfaceId: ...)` and provide a visible Studio control. Decorated components support triple-click on desktop and long press on touch devices. The host disposes both controller and processor.

For a host that edits only catalog-wide defaults, open `showGenUiTouchStudio` with `galleryOnly: true`; provide `onGalleryChanged` to rebuild the current surface after a default changes or is discarded. Keep catalog decoration if triple-click and long-press should open the editor on the touched component type. Use `showSelectionOutline: false` on the controller to avoid an item-level selection border. Continue routing incoming messages through the controller so later components receive those defaults.

The [package README](../../README.md#integration) has a minimal setup snippet. The [chat example](../../example/) shows a runnable host integration; its offline mode needs no model key.

## Edits and persistence

`controller.select(...)` and `controller.edit(property, value)` change an approved literal on the current surface. `undo()` and `redo()` affect local edits. Bound or computed values are rejected. Incoming agent updates that replace an edited component take precedence over its local undo history.

`setGalleryDefault(...)` stores a default for future components of a catalog type. To reuse a selected value across regenerated components, supply a stable `roleFor` and call `setRoleDefaultForSelection(property)`. `save()` persists the resulting `TouchProfile` through the host's `TouchStorage`; `load()` restores it. A local `edit()` alone does not create a reusable preference. Scope storage to the correct user or tenant and load it before processing new generated surfaces.

`showGenUiTouchStudio` stores window bounds in local shared preferences by default. This is separate from appearance storage. The optional `TouchPropertyComposer` lets a host AI service propose values; the same contract checks apply before an edit.

## Verify the host

Run analyzer, tests, and a build for the host's target platform. Exercise selection, an approved edit, undo and redo, Gallery defaults on later content, role defaults after new component IDs, and rejection of a bound value. The package's [widget test](../../test/touch_test.dart) and the [example integration test](../../example/test/touch_integration_test.dart) cover the basic paths.
