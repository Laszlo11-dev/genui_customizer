# GenUI Touch

**Make generated UI your own.**

GenUI generates interfaces dynamically. GenUI Touch lets developers and users adjust the appearance of A2UI Flutter surfaces **in the running application**, without changing source code or editing A2UI JSON.

Open GenUI Touch over the live UI. **Triple-click** a widget on desktop or **long-press** it on touch devices to select it, then edit the properties the host application has made available. Changes appear immediately, with undo and redo for local edits. Gallery defaults can be discarded or saved when the host supplies storage. Manual editing does not require an AI service.

The screenshots below show the earlier 0.1.x Restaurant Finder host. They illustrate the editing workflow; the current A2UI host is the [chat example](example/).

<img src="https://laszlo11-dev.github.io/genui_customizer/doc/images/studio-overview.png" alt="Earlier 0.1.x GenUI Touch editing a live surface" width="400">

Select a widget in the running app or component tree, then adjust its properties alongside a preview.

## Where it can help

- **Developer:** inspect and tune generated widgets in their real application context, without rebuilding or making another AI call for every visual change.
- **Designer:** refine typography, spacing, images, and other available visual properties directly on a working interface.
- **Multi-tenant app administrator:** adjust catalog widget defaults for a company or team, with the scope and permissions managed by the host app.
- **End user:** personalize selected parts of their own interface, manually or with optional AI assistance.

Unlike a theme setting, GenUI Touch can edit **individual rendered widgets** as well as **defaults for catalog widget types**. It does not replace an application's theme or design system.

## Two editing modes

| Surface | Gallery |
| --- | --- |
| Customize a specific widget in the current generated UI. | Customize default property values for a widget type. |
| Select it by triple-click, long-press, or from the component tree. | Select a catalog widget and edit its preview. |

The A2UI implementation uses `a2ui_core` 0.7.x, `a2ui_flutter` 0.3.x, and A2UI v1.0. Its Studio is a floating, movable, resizable dialog in the running app. With host-provided storage and stable presentation roles, saved appearance settings can be reapplied to later generated content.

<img src="https://laszlo11-dev.github.io/genui_customizer/doc/images/surface-editing.png" alt="Earlier 0.1.x compact editing window" width="400">

The compact GenUI Touch window keeps the property editor and preview visible. Select another widget in the app without closing GenUI Touch; edits to a shared template appear on every instance.

## New example

The [example](example/) adapts the official A2UI Flutter chat app and adds Touch. It can use Gemini, as the upstream app does, or a fixed offline demo reply without a key. The [package and example plan](doc/a2ui-package-plan.md) records the migration decisions.

Optional AI integration can provide scoped property editing or propose new generated surfaces. Human edits and AI generation can be combined, subject to the host application's integration.

<img src="https://laszlo11-dev.github.io/genui_customizer/doc/images/complex-layout-ai-regeneration.png" alt="Earlier 0.1.x complex layout editing" width="400">

Work with complex layouts, adjust individual widgets, or describe a new presentation and generate an AI proposal using the host application's AI integration.

## Integration

1. Register visual properties with `TouchContract` and `TouchProperty`.
2. Wrap the A2UI catalog with `GenUiTouchController.decorateCatalog`, then attach the host's `MessageProcessor`.
3. Send incoming v1.0 messages through `processAgentMessages` and display the host's `A2uiSurface`.
4. Open `showGenUiTouchStudio` from `onStudioRequested`. Provide `TouchStorage` to persist reusable Gallery and role defaults.

Only host-approved properties are editable. Data bindings, actions, and component relationships remain protected. The host controls authorization, storage, and the scope of saved preferences. A local widget edit is not automatically persisted; the host must assign a stable role and save a role preference to apply the value to later generated content.

Version 0.2.0-dev.1 replaces the 0.1.x `genui` API and is not source compatible with it. See the [A2UI integration details](#integration), [example instructions](example/README.md), and [integration skill](skills/genui-customizer-integration/SKILL.md).

For local development, the repository pins Flutter **3.47.9** in `.fvmrc` (`fvm use`).

## License

GenUI Touch is licensed under the [PolyForm Perimeter License 1.0.1](LICENSE).

## Project status

**Experimental.** APIs and behavior may change without backward compatibility. This project is developed with **heavy use of AI**, including AI-assisted coding; its implementation should be reviewed and tested accordingly.

GenUI Touch focuses on runtime visual customization. It is **not a design-time UI builder** or a replacement for Flutter development tools. Feedback and contributions are welcome.
