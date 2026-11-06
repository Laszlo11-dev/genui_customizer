---
name: genui-customizer-integration
description: Integrate genui_customizer into an existing Flutter GenUI app for runtime component selection, manual property editing, storage, and reusable appearance across generated surfaces. Use when adapting an existing GenUI catalog and A2UI message flow; not for building a new GenUI transport.
---

# Integrate GenUI Touch

Read the host's existing catalog, `SurfaceController`, A2UI message handler, and persistence boundary before editing. Use the package's public import, `package:genui_customizer/genui_customizer.dart`. Keep the host's transport, identity model, and authorization decisions.

## Connect the catalog and editor

1. Build an `EditableCatalogRegistry` with the host's catalog ID and a host-managed version. Declare only visual properties that the real rendering catalog accepts. The built-in editor renders enumeration controls; other property types need a custom editor. Keep `id`, `component`, child links, actions, content, and bindings out of the editable allowlist. `protectedProperties` is an additional guard, not a substitute for a narrow allowlist.
2. Attach one `EditableGenUiController` per independently edited surface. Component IDs must be unique within a snapshot. Supply `onSnapshotChanged` to send edited `updateComponents` messages to the existing `SurfaceController`, and dispose the controller with its owner.
3. Decorate the catalog items *used by the renderer* with `decorateEditableCatalogItem`. The decorator supplies desktop triple-click and touch long-press selection to open the Studio; while it is open, one click or tap on another rendered widget changes the selection. Connect `onEditorRequested` to `showEditableGenUiStudio`; also provide a visible way to open it. Pass nonempty `galleryTypes` whose types have registry contracts, using names from the host catalog. `galleryCatalog` is optional.
4. Feed incoming `UpdateComponentsMessage` definitions into `editor.setSurfaceSnapshot`. That call replaces the complete editable snapshot. Merge incremental component updates for a surface before calling it. Route create, data, and delete messages through the host as before. Do not render an incoming component update twice when `onSnapshotChanged` already renders the replacement snapshot.

For a complete, executable manual-edit and regeneration example, read [examples/integration_test.dart](examples/integration_test.dart). Adapt its synthetic `Text.variant` values and role resolver to the host catalog.

## Manual edits and storage

`controller.select(GenUiComponentSelection(...))` or the decorated widget's gesture sets the selection. `controller.apply({'variant': 'h1'})` edits the selected component locally and calls `onSnapshotChanged`; no composer is needed. The controller also exposes `undo()`, `redo()`, `cancel()`, `save()`, `reload()`, `isDirty`, and `error`. Check `error` after `apply`, which reports a rejected edit there rather than throwing it.

`showEditableGenUiStudio` persists its movable window position and size by default through the package's app-local shared preferences. Do not add a bounds store to the host solely for this. Pass `boundsPersistence: null` to disable persistence, or supply both `loadBounds` and `saveBounds` when the host needs custom storage. These bounds are separate from edited component snapshots and appearance profiles.

Provide `CallbackEditableGenUiStorage(onLoad: ..., onSave: ...)` or implement `EditableGenUiStorage`. Raw snapshots are suitable for conversation-local checkpoints. For preferences that survive new AI output with different component IDs, persist a `GenUiAppearanceProfile` instead:

- Keep the unedited, visible snapshot as the baseline. On save, call `GenUiAppearanceProfile.capture(before: baseline, after: edited, registry: registry, roleFor: roleFor, previous: profile)`, then serialize `profile.toJson()` in host-owned storage. Update the baseline only after persistence succeeds. A component needs a stable, host-defined role to yield a reusable rule.
- On startup, decode with `GenUiAppearanceProfile.fromJson`; accept only the matching `catalogId` and `catalogVersion`, or migrate explicitly. Load the profile before processing the first generated result.
- Before rendering each new `updateComponents` message, call `profile.applyToMessage(message: raw, registry: registry, roleFor: roleFor)`. This reapplies approved properties while retaining the new component IDs and bindings. Then make the resulting definition the controller's new baseline. The host must merge incremental updates first and keep separate controllers for surfaces that reuse component IDs.

Do not assume that `save()` alone preserves manual edits through regeneration: `setSurfaceSnapshot` replaces the current definition. Define storage scope and access control in the host. Optional AI property proposals use `EditableGenUiComposer`; manual editing and profile replay do not require it.

## Verify in the target app

Run the host's analyzer and tests. Exercise selection by gesture and by component tree, including a single click or tap on another widget while the Studio is open. Check that moving and resizing the Studio survives closing and reopening it unless persistence was disabled. Verify a local property change, undo/cancel/save, reload, and a regenerated surface with new component IDs and new data bindings. Confirm that a noneditable field remains unchanged. Use the example test as a small reference, not as a replacement for an end-to-end host test.
