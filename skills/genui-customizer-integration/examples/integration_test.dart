import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_customizer/genui_customizer.dart';

void main() {
  final registry = EditableCatalogRegistry(
    catalogId: 'example-catalog',
    catalogVersion: 1,
    components: [
      EditableComponentContract(
        type: 'Text',
        properties: const [
          EditablePropertyContract(
            name: 'variant',
            label: 'Text style',
            type: EditablePropertyType.enumeration,
            enumValues: ['body', 'h1'],
          ),
        ],
        protectedProperties: const {
          'id',
          'component',
          'text',
          'child',
          'children',
          'action',
        },
      ),
    ],
  );

  String? roleFor(Map<String, Object?> component) {
    final text = component['text'];
    if (component['component'] == 'Text' &&
        text is Map &&
        text['path'] == '/title') {
      return 'result-title';
    }
    return null;
  }

  Map<String, Object?> update(String id, String variant) => {
    'version': 'v0.9',
    'updateComponents': {
      'surfaceId': 'result',
      'components': [
        {
          'id': id,
          'component': 'Text',
          'variant': variant,
          'text': {'path': '/title'},
        },
      ],
    },
  };

  test('manual edit, save, and profile replay across regeneration', () async {
    final initial = GenUiEditSnapshot(
      revision: 1,
      messages: [update('old-title', 'body')],
    );
    GenUiEditSnapshot baseline = initial;
    GenUiAppearanceProfile? profile;
    String? savedProfile;
    final rendered = <GenUiEditSnapshot>[];

    final editor = GenUiCustomizer.attach(
      initial: initial,
      registry: registry,
      storage: CallbackEditableGenUiStorage(
        onLoad: () async => baseline,
        onSave: (edited) async {
          profile = GenUiAppearanceProfile.capture(
            before: baseline,
            after: edited,
            registry: registry,
            roleFor: roleFor,
            previous: profile,
          );
          savedProfile = jsonEncode(profile!.toJson());
          baseline = edited;
        },
      ),
      onSnapshotChanged: rendered.add,
    );
    addTearDown(editor.dispose);

    // Use these decorated items when constructing the host SurfaceController.
    final catalog = BasicCatalogItems.asCatalog();
    final decorated = catalog.copyWith(
      newItems: [
        for (final item in catalog.items)
          decorateEditableCatalogItem(item, editor),
      ],
    );
    expect(decorated.items.length, catalog.items.length);

    editor.select(
      const GenUiComponentSelection(
        surfaceId: 'result',
        componentId: 'old-title',
        componentType: 'Text',
        definitionRevision: 1,
      ),
    );
    editor.apply({'variant': 'h1'});
    expect(editor.error, isNull);
    expect(editor.isDirty, isTrue);
    expect(rendered.single.messages.single['updateComponents'], isNotNull);
    expect(editor.component('old-title')?['text'], {'path': '/title'});

    await editor.save();
    expect(editor.isDirty, isFalse);
    final restored = GenUiAppearanceProfile.fromJson(
      Map<String, Object?>.from(jsonDecode(savedProfile!) as Map),
    );

    // Apply saved roles before sending a new generated definition to the editor.
    final incoming = update('new-title', 'body');
    final visible = restored.applyToMessage(
      message: incoming,
      registry: registry,
      roleFor: roleFor,
    );
    editor.setSurfaceSnapshot(
      GenUiEditSnapshot(revision: 1, messages: [visible]),
    );
    expect(editor.component('new-title')?['variant'], 'h1');
    expect(editor.component('new-title')?['text'], {'path': '/title'});
    expect(editor.component('old-title'), isNull);
    expect(editor.isDirty, isFalse);
  });

  testWidgets('host action opens the Studio for the decorated catalog', (
    tester,
  ) async {
    final editor = GenUiCustomizer.attach(
      initial: const GenUiEditSnapshot(revision: 1, messages: []),
      registry: registry,
    );
    addTearDown(editor.dispose);
    final catalog = BasicCatalogItems.asCatalog();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showEditableGenUiStudio(
                context: context,
                controller: editor,
                galleryTypes: const ['Text'],
                galleryCatalog: catalog,
              ),
              child: const Text('Customize'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Customize'));
    await tester.pumpAndSettle();
    expect(find.text('GenUI Touch'), findsWidgets);
  });
}
