import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:genui_customizer/src/core/core.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import 'controller.dart';

const _editorCatalogId = 'https://openai.com/genui/editable/editor/v1';

/// Opens the compact editor for the controller's current selection.
Future<void> showEditableGenUiEditorDialog({
  required BuildContext context,
  required EditableGenUiController controller,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierColor: Colors.black12,
  builder: (context) => Align(
    alignment: MediaQuery.sizeOf(context).width >= 900
        ? Alignment.centerRight
        : Alignment.center,
    child: _EditableGenUiEditorDialog(controller: controller),
  ),
);

final class _EditableGenUiEditorDialog extends StatefulWidget {
  const _EditableGenUiEditorDialog({required this.controller});

  final EditableGenUiController controller;

  @override
  State<_EditableGenUiEditorDialog> createState() =>
      _EditableGenUiEditorDialogState();
}

final class _EditableGenUiEditorDialogState
    extends State<_EditableGenUiEditorDialog> {
  final _prompt = TextEditingController();

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final selection = widget.controller.selection;
      if (selection == null) return const SizedBox.shrink();
      return AlertDialog(
        title: Text('Edit ${selection.componentType}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EditableGenUiPropertyEditor(controller: widget.controller),
                if (widget.controller.permissions.canUseAi &&
                    widget.controller.composer != null) ...[
                  const SizedBox(height: 20),
                  TextField(
                    key: const Key('editable-genui-ai-prompt'),
                    controller: _prompt,
                    maxLength: 600,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Ask AI to change this component',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: widget.controller.busy
                          ? null
                          : () => widget.controller.prompt(_prompt.text),
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('Apply AI edit'),
                    ),
                  ),
                ],
                if (widget.controller.error case final error?) ...[
                  const SizedBox(height: 12),
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ] else if (!widget.controller.isDirty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Change a property or apply an AI edit to enable Save.',
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  const Text('Unsaved changes are shown in the live preview.'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: widget.controller.canUndo && !widget.controller.busy
                ? widget.controller.undo
                : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: widget.controller.canRedo && !widget.controller.busy
                ? widget.controller.redo
                : null,
            icon: const Icon(Icons.redo),
          ),
          TextButton(
            onPressed: widget.controller.busy
                ? null
                : () {
                    widget.controller.cancel();
                    widget.controller.close();
                    Navigator.of(context).pop();
                  },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed:
                widget.controller.permissions.canSave &&
                    widget.controller.isDirty &&
                    !widget.controller.busy
                ? () async {
                    try {
                      await widget.controller.save();
                    } on Object {
                      // The controller exposes the failure in the dialog.
                      return;
                    }
                    if (!context.mounted) return;
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    widget.controller.close();
                    Navigator.of(context).pop();
                    messenger?.showSnackBar(
                      const SnackBar(content: Text('Presentation saved.')),
                    );
                  }
                : null,
            child: widget.controller.busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      );
    },
  );
}

/// Renders the selected component's configured property controls.
final class EditableGenUiPropertyEditor extends StatefulWidget {
  const EditableGenUiPropertyEditor({required this.controller, super.key});

  final EditableGenUiController controller;

  @override
  State<EditableGenUiPropertyEditor> createState() =>
      _GenUiPropertyEditorState();
}

final class _GenUiPropertyEditorState
    extends State<EditableGenUiPropertyEditor> {
  SurfaceController? _surface;
  String? _definitionKey;

  @override
  void dispose() {
    _surface?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.controller.selection!;
    final contract = widget.controller.registry.contractFor(
      selection.componentType,
    )!;
    final custom = widget.controller.editorFor(selection.componentType);
    final definition = custom ?? _defaultEditor(contract);
    final key = '${selection.componentType}:${definition.id}';
    if (_surface == null || _definitionKey != key) {
      _surface?.dispose();
      _definitionKey = key;
      _surface = _buildSurface(widget.controller, definition);
    }
    return Surface(
      key: ValueKey('$key:${widget.controller.snapshot.revision}'),
      surfaceContext: _surface!.contextFor('editable-property-editor'),
      defaultBuilder: (_) => const Text('Property editor unavailable.'),
    );
  }
}

SurfaceController _buildSurface(
  EditableGenUiController controller,
  EditablePropertyEditorDefinition definition,
) {
  final surface = SurfaceController(catalogs: [_editorCatalog(controller)]);
  surface.handleMessage(
    core.UpdateComponentsMessage(
      surfaceId: 'editable-property-editor',
      components: definition.components,
    ),
  );
  surface.handleMessage(
    core.CreateSurfaceMessage(
      surfaceId: 'editable-property-editor',
      catalogId: _editorCatalogId,
      sendDataModel: false,
    ),
  );
  return surface;
}

Catalog _editorCatalog(EditableGenUiController controller) => Catalog([
  CatalogItem(
    name: 'EditorColumn',
    dataSchema: S.object(
      properties: {'children': S.list(items: S.string())},
      required: ['children'],
    ),
    widgetBuilder: (context) {
      final data = _map(context.data);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final id in _strings(data['children'])) ...[
            context.buildChild(id),
            const SizedBox(height: 8),
          ],
        ],
      );
    },
  ),
  CatalogItem(
    name: 'EditorHeading',
    dataSchema: S.object(properties: {'text': S.string()}, required: ['text']),
    widgetBuilder: (context) => Text(
      _map(context.data)['text'] as String? ?? '',
      style: Theme.of(context.buildContext).textTheme.titleSmall,
    ),
  ),
  CatalogItem(
    name: 'PropertyChoice',
    dataSchema: S.object(
      properties: {
        'property': S.string(),
        'label': S.string(),
        'options': S.list(items: S.string()),
      },
      required: ['property', 'label', 'options'],
    ),
    widgetBuilder: (context) {
      final data = _map(context.data);
      final property = data['property'] as String;
      final options = _strings(data['options']);
      final selection = controller.selection!;
      final value = controller.component(selection.componentId)?[property];
      return DropdownButtonFormField<String>(
        key: ValueKey('editable-property-$property'),
        initialValue: value is String && options.contains(value) ? value : null,
        decoration: InputDecoration(
          labelText: data['label'] as String? ?? property,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final option in options)
            DropdownMenuItem(value: option, child: Text(option)),
        ],
        onChanged: controller.busy
            ? null
            : (value) {
                if (value != null) controller.apply({property: value});
              },
      );
    },
  ),
], catalogId: _editorCatalogId);

EditablePropertyEditorDefinition _defaultEditor(
  EditableComponentContract contract,
) {
  final controls = <Map<String, Object?>>[];
  for (final property in contract.properties.values) {
    if (property.type != EditablePropertyType.enumeration) continue;
    controls.add({
      'id': 'property-${property.name}',
      'component': 'PropertyChoice',
      'property': property.name,
      'label': property.label,
      'options': property.enumValues,
    });
  }
  return EditablePropertyEditorDefinition(
    id: 'schema-${contract.type}',
    components: [
      {
        'id': 'heading',
        'component': 'EditorHeading',
        'text': '${contract.type} properties',
      },
      ...controls,
      {
        'id': 'root',
        'component': 'EditorColumn',
        'children': ['heading', for (final value in controls) value['id']!],
      },
    ],
  );
}

Map<String, Object?> _map(Object? value) =>
    value is Map ? value.cast<String, Object?>() : <String, Object?>{};

List<String> _strings(Object? value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : const [];
