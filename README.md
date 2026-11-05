# genui\_customizer

**Experimental runtime visual editor for Flutter GenUI.**

This project explores the space between traditional, statically designed user interfaces and fully AI-generated dynamic interfaces.

Static UIs provide predictability and precise control, but limited flexibility. Fully dynamic UIs offer adaptability, but can be difficult to customize, control, and keep consistent.

**GenUI Customizer experiments with a middle ground:** AI-generated interfaces that can also be visually edited, refined, and reused.

The project is at an early experimental stage. Its architecture, APIs, features, and interaction patterns are expected to change significantly. It is intended for exploration and experimentation rather than production use.

## Studio features

The Studio opens over the running Flutter app, so a user can edit a generated
surface while keeping its application context visible.

* **Movable and resizable window.** Drag the title bar to move the Studio and
  use the lower-right corner to resize it. The window stays within the visible
  screen. A host can supply `loadBounds` and `saveBounds` callbacks to restore
  its position and size when it opens again.
* **Adjustable split layout.** On a wide window, drag the divider between the
  structure or gallery on the left and the selected component's editor on the
  right. A host can persist this ratio with `loadSplitFraction` and
  `saveSplitFraction`.
* **Responsive editor.** When the Studio becomes narrow, the left panel moves
  into a Structure drawer. The selected component's editor remains in the main
  area, while actions such as undo, redo, and discard move into the menu.
* **Surface and Gallery views.** Surface shows the current A2UI component tree
  in its parent-child order. Select an instance to edit it and preview it in
  isolation. Gallery shows the available catalog component types with sample
  previews and lets the user edit their default appearance. Switch views from
  the Studio menu.
* **Direct, reversible editing.** Select a component in the rendered app with
  a desktop triple click or touch long press, or select it in the Studio tree.
  Changes to allowed properties update the live preview immediately. Undo,
  redo, discard, and save control the editing session.
* **Reusable appearance.** With host-provided storage and stable presentation
  roles, saved visual choices can be reapplied to later AI-generated content.
  The included Restaurant Finder example also persists Gallery defaults and
  restores the window geometry and split ratio between runs.
* **Optional AI assistance.** A host may connect AI callbacks for a new surface
  proposal or a custom property editor. Manual editing and the recorded example
  work without an AI service.
* **GenUI debug view.** A host can supply `loadDebugData` to expose its latest
  request, response, validation result, and saved definitions from the Studio
  overflow menu. The view also shows the current editable UI snapshot.

## Two usage scenarios

### End-user customization

Users can personalize parts of an AI-generated interface without programming or writing prompts.

* Select components directly in the running application.
* Edit properties permitted by the host application.
* Preview changes immediately.
* Undo, redo, and save customizations.
* Reapply visual preferences to newly generated content.
* Optionally request AI-assisted changes.

Local editing works without an AI service. Users do not need access to raw A2UI JSON.

### Developer scenario: Runtime experimentation

Developers can use the Customizer to inspect, modify, and experiment with GenUI interfaces **inside a running application**.

* Select and edit rendered components in their actual application context.
* Experiment with properties and layouts without modifying source code.
* Apply changes immediately, without repeated AI calls.
* Combine manual adjustments with AI-assisted regeneration.
* Test how customizations survive subsequent AI-generated updates.

The Customizer is **not a design-time UI builder**. It does not aim to replace IDEs, visual development tools, or existing Flutter development workflows.

Its focus is the runtime boundary between application-defined structure, AI-generated interfaces, and human customization.

## How it works

The package includes the Studio UI, selection gestures, property contracts, undo/redo, persistence, and optional AI integration ports.

The host application remains responsible for its GenUI catalog, data, authorization, storage, and AI services.

Only explicitly approved properties are editable. Data bindings, actions, and component relationships remain protected.

Manual edits can be applied immediately without invoking AI. Optional AI integration enables further refinement or regeneration.

## Integration

1. Register an `<span>EditableCatalogRegistry</span>` with the visual properties that may be changed.
2. Attach a `<span>GenUiCustomizer</span>` controller and decorate catalog items using `<span>decorateEditableCatalogItem</span>`. A triple click or long press selects a component; a visible customization action is also recommended.
3. Open `<span>showEditableGenUiStudio</span>` with the controller. Supply `<span>EditableGenUiStorage</span>` for persistence and optionally `<span>EditableGenUiComposer</span>` for scoped AI editing. The host may also provide `<span>onGenerateProposal</span>` for generating an entirely new surface.
4. Capture changes as a `<span>GenUiAppearanceProfile</span>` using an application-defined role resolver. Store the profile for the appropriate user or group and apply it to new `<span>updateComponents</span>` messages before rendering.

A role resolver should identify a stable *presentation role*, such as `<span>restaurant-image</span>`, based on domain bindings or application metadata. Generated component IDs and data values are not reliable preference keys.

Appearance profiles contain only approved property values. They do not replace generated data, actions, or bindings. Profiles are associated with catalog IDs and versions; version mismatches require explicit migration or reset.

Storage and access control remain the responsibility of the host application.

## Example

The [Restaurant Finder example](example/README.md) adapts the official A2UI Flutter client.

For local development, run `fvm use` from the repository root. The project pins
Flutter 3.47.9 in `.fvmrc`. In Android Studio, set the project Flutter SDK path
to this repository's `.fvm/flutter_sdk` directory so the IDE follows the same
version as the command line.

By default, it replays two recorded responses from the official agent, allowing the customization workflow to be explored without AI credentials.

The example uses device-local storage. Production applications must provide their own identity, persistence, and authorization mechanisms.

## Project status

**Experimental — APIs and behavior may change without backward compatibility.**

This project is an exploration of how far runtime customization can extend the capabilities of GenUI, for both end users and developers.

Feedback, experiments, and contributions are welcome.
