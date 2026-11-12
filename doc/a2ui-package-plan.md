# A2UI package redesign plan

Status: design target, not an implemented API. The current 0.1.x source still
uses `genui` 0.10.4 and `a2ui_core` 0.1.1. The old Restaurant Finder and Simple
Chat applications were removed before starting the redesign.

## Concept assessment (2026-11-12)

The product remains viable as an in-app, user-facing appearance editor. The
new SDK processes messages, validates catalogs, resolves bindings, renders
widgets, and dispatches actions; its published API does not supply the Touch
journey of selecting a live component, editing a permitted visual property,
undoing/saving that choice, or applying it to later generated surfaces.

The package should get smaller. Do not duplicate `MessageProcessor`,
`SurfaceComponentsModel`, `NodeResolver`, `PayloadValidator`, schema resolution,
or the renderer's binding/action handling. Keep the component-tree *UI*, but
derive its graph and live properties from core models. Build ordinary Flutter
controls for the property editor; a private A2UI catalog for those controls
adds another processor and schema surface without providing user value.

Catalog schemas validate whether an A2UI property is legal. They do not say
whether a particular user may change it or whether changing it is a visual
customization. Keep an explicit host allowlist, using the schema for type and
enum constraints where practical. The standard basic catalog has few visual
knobs (for example, Text's `variant` and Image's `fit`/`variant`). Rich styling
requires host-owned custom component properties or Flutter theme tokens. A
read-only catalog gallery overlaps the upstream explorer; retain Gallery only
if it edits and persists host-owned defaults.

Distinguish three kinds of state: A2UI data bindings are live content/form
state; component literals are agent-produced presentation choices; saved Touch
preferences are host/user presentation policy. Editing a `{"@path": ...}` or
`{"@call": ...}` expression as though it were a literal would sever the
binding or change behavior. Touch edits approved literals or host-owned style
tokens, never the data model or action/function wiring. The core already
provides two-way form-field binding, so a general form-data editor is outside
Touch's scope.

In v1.0, `createSurface` may contain components and data, a surface may mix
catalogs via component `@catalogId`, and the old protocol `theme` field is
removed. Key editing contracts and preferences by catalog ID plus component
type; use the Flutter theme or explicit host style tokens for shared defaults.
For a decoration that changes only a Flutter builder, use `Catalog.copyWith`
to preserve the catalog ID and schema. Use `derive` with a new ID only when
the public catalog contract itself changes, and advertise that ID to the
agent. A2UI Composer and upstream explorers can assist design and debugging,
but they do not replace in-app, authorized, persistent personalization.

The main integration risk is arbitration between incoming agent updates and
local edits. The host must define whether a local override wins, expires, or
is rebased when the agent replaces the same component. This is a Touch policy,
not a feature supplied by the message processor. Another risk is template
identity: `ComponentNode.instanceId` identifies a rendered occurrence but is
positional across list reorder; persist roles or stable domain keys, not
instance IDs. Preview surfaces also need bounded dimensions because the new
renderer does not support intrinsic-size measurement.

## Target and source example

- Target `a2ui_core` 0.7.x and `a2ui_flutter` 0.3.x, with A2UI protocol v1.0.
  Pin a tested pair in the replacement example's lockfile. Do not retain
  `genui`, `genui_a2a`, old message classes, or a v0.9 compatibility path.
- Use the maintained [A2UI Flutter package example](https://github.com/a2ui-project/a2ui/tree/main/dart/a2ui_flutter/example),
  especially its `chat_session.dart`, as the starting host application. Record
  the upstream commit when importing it; keep upstream license notices and
  document local changes. The example should use a deterministic recorded
  v1.0 response by default and offer live model access only as an optional host
  feature. The package must not own model credentials or transport.
- Keep the repository's Flutter 3.47.9 development SDK. The new renderer
  declares Flutter >=3.38.0, so the redesigned package must declare at least
  that minimum and verify its own supported range before publication.

## Responsibility boundary

The host owns `MessageProcessor<ComponentImplementation>`, agent transport,
catalog choice, authorization, and outbound actions. The package owns an edit
session for one surface, selection gestures, visual property validation,
undo/redo, Studio UI, and optional storage callbacks. It receives normalized
surface state from the host and returns validated v1.0 component updates. The
host applies those updates through its processor. The package does not send
user actions to the agent or change data bindings, functions, or structure.

The public integration should have four parts:

1. `EditableCatalog`: takes a host `CatalogImplementation`, a catalog ID and
   version, and explicit editable component/property contracts. It returns a
   copy of that catalog, preserving its ID and schemas, whose builders wrap
   eligible components for selection.
   Builders read `ComponentNode` identity (`componentId`, `type`, `dataPath`,
   `instanceId`) and delegate to the original builder with its existing
   `ComponentProps` and `buildChild` function. Do not manufacture another
   resolved props map or intercept actions.
2. `EditableSurfaceSession`: keyed by surface ID and definition revision,
   accepts v1.0 `createSurface` and subsequent `updateComponents` batches,
   and exposes an immutable effective component graph. A selection contains
   surface ID, component ID, instance ID, data path, and revision. Repeated
   template instances can share a definition component; edits target that
   definition unless the host explicitly offers an instance-level data edit.
3. `AppearanceProfile`: stores host-approved presentation properties against
   stable host roles, catalog ID and catalog version. Application to a new
   generated surface is explicit and validated before emission. No automatic
   import of 0.1.x saved snapshots or profiles is promised.
4. `GenUiTouchStudio`: receives the session, editable catalog, and host
   callbacks. Its property controls are ordinary Flutter widgets. When an
   isolated gallery or selected-widget preview is needed, it uses a separate
   `MessageProcessor` and `A2uiSurface`, then disposes that processor when the
   preview closes or its catalog changes. Preview actions are inert.

The host-facing API should make message ownership explicit: `onEdit` receives
the proposed `updateComponents` envelope and expected revision, and the host
returns acceptance or rejection. Only an accepted edit enters undo history.
Storage receives a detached, versioned snapshot; it must not hold or mutate
live `SurfaceModel` or `ComponentModel` objects.

## Message and validation rules

- A `createSurface` can carry initial `components` and `dataModel`; later
  `updateComponents` messages can add or replace component definitions. Build
  the edit graph from both, in arrival order. Scope every lookup by surface ID.
- Keep protocol envelopes and component payloads as JSON-safe values at the
  persistence boundary. Do not serialize SDK model instances. Preserve the
  surface's `catalogId` and each component's `@catalogId` so v1.0 mixed
  catalogs survive.
- Validate a proposed edit against the host's allowlist and the new catalog
  schema. Reject changes to IDs, component type, child references, actions,
  function calls, paths, catalog IDs, metadata, and unlisted properties. A
  nullable visual property is editable only when its contract allows null.
- Rebase an incoming incremental update over the current graph. Preserve
  unrelated local edits and invalidate a selection or pending AI proposal if
  its target changes. Do not reset history solely because another component
  arrived. Reject a stale revision rather than silently overwriting the host.
- Keep model data separate from visual definition edits. `ComponentProps`
  resolves bindings for rendering; the editor changes approved component
  literals only. The host remains responsible for data-model updates and
  outbound actions via `processor.model.onAction` or `unifiedOutbound`.

## Replacement example journey

Place the new application in `example/` only after it can depend on the new
package. Start from the upstream v1.0 chat session, add the derived editable
catalog and a recorded response with a basic Text plus at least one custom
component. The default run needs no account, key, server, or paid service.

Demonstrate: render response; select a component by gesture and tree; change
one approved visual property; undo, redo, discard, and save; render a later
response with different component IDs and reapply a role-based profile; reload
saved state; reject an action or binding edit. Keep optional live generation
outside the package. Replace the old Pages workflow only after the new example
passes its web build and recorded journey.

## Implementation sequence and gates

1. Replace dependencies and remove old `genui` imports from the library.
   Introduce the v1.0 edit graph and its unit tests first.
2. Implement catalog decoration and one minimal host widget test that proves
   selection still renders the original component and dispatches its action.
3. Rebuild the Studio and gallery previews on isolated processors. Test
   selection, visual edits, disposal, and layout at desktop and narrow widths.
4. Import the current upstream chat example, add recorded v1.0 fixtures, and
   wire storage and appearance replay. Keep its upstream provenance visible.
5. Update README, integration skill, public API documentation, and changelog
   to match only the working new API. Migrate downstream consumers, including
   `proving_genui`, as a separate coordinated change.
6. Run format, analyze, package tests, example widget tests, and web build
   using `tool/fvmw.ps1`. Review the new example manually before restoring a
   deployment workflow. Do not publish the redesigned package until these
   checks pass.

Primary API references: [renderer README](https://pub.dev/packages/a2ui_flutter),
[core README](https://pub.dev/packages/a2ui_core), and
[renderer changelog](https://pub.dev/packages/a2ui_flutter/changelog).
