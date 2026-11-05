import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';
import 'package:genui_customizer/genui_customizer.dart';

/// Keeps identically named components in different chat replies isolated.
final class ChatTouchIntegration {
  ChatTouchIntegration({required this.catalog, required this.onChanged}) {
    registry = EditableCatalogRegistry(
      catalogId: catalog.catalogId ?? basicCatalogId,
      catalogVersion: 1,
      components: [
        for (final item in catalog.items)
          EditableComponentContract(
            type: item.name,
            properties: switch (item.name) {
              'Text' => const [
                EditablePropertyContract(
                  name: 'variant',
                  label: 'Text style',
                  type: EditablePropertyType.enumeration,
                  enumValues: ['h1', 'h2', 'h3', 'h4', 'h5', 'caption', 'body'],
                ),
              ],
              'Row' || 'Column' => const [
                EditablePropertyContract(
                  name: 'justify',
                  label: 'Main axis alignment',
                  type: EditablePropertyType.enumeration,
                  enumValues: [
                    'start',
                    'center',
                    'end',
                    'spaceBetween',
                    'spaceAround',
                    'spaceEvenly',
                    'stretch',
                  ],
                ),
                EditablePropertyContract(
                  name: 'align',
                  label: 'Cross axis alignment',
                  type: EditablePropertyType.enumeration,
                  enumValues: ['start', 'center', 'end', 'stretch'],
                ),
              ],
              'ClimbingLocation' => const [
                EditablePropertyContract(
                  name: 'density',
                  label: 'Card density',
                  type: EditablePropertyType.enumeration,
                  enumValues: ['comfortable', 'compact'],
                ),
                EditablePropertyContract(
                  name: 'imageVisibility',
                  label: 'Image visibility',
                  type: EditablePropertyType.enumeration,
                  enumValues: ['show', 'hide'],
                ),
              ],
              _ => const [],
            },
            protectedProperties: const {
              'id',
              'component',
              'text',
              'identifier',
              'children',
              'child',
              'action',
              'value',
              'url',
              'tabs',
            },
          ),
      ],
    );
    decoratedCatalog = catalog.copyWith(
      newItems: [
        for (final item in catalog.items)
          CatalogItem(
            name: item.name,
            dataSchema: item.dataSchema,
            exampleData: item.exampleData,
            isImplicitlyFlexible: item.isImplicitlyFlexible,
            widgetBuilder: (context) {
              final editor = editorFor(context.surfaceId);
              if (editor == null) return item.widgetBuilder(context);
              return decorateEditableCatalogItem(
                item,
                editor,
              ).widgetBuilder(context);
            },
          ),
      ],
    );
  }

  final Catalog catalog;
  final VoidCallback onChanged;
  late final EditableCatalogRegistry registry;
  late final Catalog decoratedCatalog;
  final Map<String, _EditableSurface> _surfaces = {};
  // An open floating studio may still be listening when its surface is deleted.
  // Keep retired controllers alive until the owning conversation is disposed.
  final List<_EditableSurface> _retired = [];
  void Function(String surfaceId)? onEditorRequested;
  void Function(String surfaceId)? onSurfaceRemoved;

  EditableGenUiController? editorFor(String surfaceId) =>
      _surfaces[surfaceId]?.editor;

  /// Routes data/create/delete messages unchanged. Component deltas are merged
  /// into one complete snapshot per surface, retaining other components.
  void handleMessage(core.A2uiMessage message, SurfaceController host) {
    if (message is core.DeleteSurfaceMessage) {
      final removed = _surfaces.remove(message.surfaceId);
      if (removed != null) {
        removed.active = false;
        _retired.add(removed);
        onSurfaceRemoved?.call(message.surfaceId);
      }
      host.handleMessage(message);
      onChanged();
      return;
    }
    if (message is! core.UpdateComponentsMessage) {
      host.handleMessage(message);
      return;
    }

    final surface = _surfaces.putIfAbsent(
      message.surfaceId,
      () => _EditableSurface(
        surfaceId: message.surfaceId,
        registry: registry,
        host: host,
        onEditorRequested: () => onEditorRequested?.call(message.surfaceId),
      ),
    );
    surface.merge(message);
    onChanged();
  }

  void dispose() {
    for (final surface in [..._surfaces.values, ..._retired]) {
      surface.editor.dispose();
    }
    _surfaces.clear();
    _retired.clear();
  }
}

final class _EditableSurface {
  _EditableSurface({
    required this.surfaceId,
    required EditableCatalogRegistry registry,
    required SurfaceController host,
    required VoidCallback onEditorRequested,
  }) {
    editor = GenUiCustomizer.attach(
      initial: _checkpoint,
      registry: registry,
      permissions: const EditableGenUiPermissions(canUseAi: false),
      storage: CallbackEditableGenUiStorage(
        onLoad: () async => _checkpoint,
        onSave: (snapshot) async => _checkpoint = snapshot,
      ),
      onEditorRequested: onEditorRequested,
      onSnapshotChanged: (snapshot) {
        if (!active) return;
        for (final json in snapshot.messages) {
          host.handleMessage(core.A2uiMessage.fromJson(json));
        }
      },
    );
  }

  final String surfaceId;
  bool active = true;
  late final EditableGenUiController editor;
  GenUiEditSnapshot _checkpoint = const GenUiEditSnapshot(
    revision: 1,
    messages: [],
  );

  void merge(core.UpdateComponentsMessage message) {
    final components = <String, Map<String, dynamic>>{};
    for (final json in editor.snapshot.messages) {
      final update = json['updateComponents'] as Map;
      for (final component in update['components'] as List) {
        final value = Map<String, dynamic>.from(component as Map);
        components[value['id'] as String] = value;
      }
    }
    for (final component in message.components) {
      components[component['id'] as String] = component;
    }
    _checkpoint = GenUiEditSnapshot(
      revision: editor.snapshot.revision + 1,
      messages: [
        core.UpdateComponentsMessage(
          version: message.version,
          surfaceId: surfaceId,
          components: components.values.toList(),
        ).toJson(),
      ],
    );
    editor.setSurfaceSnapshot(_checkpoint);
  }
}
