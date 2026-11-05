import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_customizer/genui_customizer.dart';

void main() {
  final registry = EditableCatalogRegistry(
    catalogId: 'test',
    catalogVersion: 1,
    components: [
      EditableComponentContract(
        type: 'Text',
        properties: const [
          EditablePropertyContract(
            name: 'variant',
            label: 'Variant',
            type: EditablePropertyType.enumeration,
            enumValues: ['body', 'h1'],
          ),
        ],
      ),
    ],
  );

  EditableGenUiController controller() => EditableGenUiController(
    initial: const GenUiEditSnapshot(
      revision: 1,
      messages: [
        {
          'updateComponents': {
            'components': [
              {'id': 'title', 'component': 'Text', 'variant': 'body'},
            ],
          },
        },
      ],
    ),
    registry: registry,
  );

  EditablePropertyEditorDefinition definition(String label) =>
      EditablePropertyEditorDefinition(
        id: 'text-editor',
        components: [
          {
            'id': 'variant',
            'component': 'PropertyChoice',
            'property': 'variant',
            'label': label,
            'options': ['body', 'h1'],
          },
          {
            'id': 'root',
            'component': 'EditorColumn',
            'children': ['variant'],
          },
        ],
      );

  testWidgets('editor refreshes when a definition keeps its ID', (
    tester,
  ) async {
    final editor = controller();
    addTearDown(editor.dispose);
    editor.select(
      const GenUiComponentSelection(
        surfaceId: 'surface',
        componentId: 'title',
        componentType: 'Text',
        definitionRevision: 1,
      ),
    );
    editor.setSharedEditors({'Text': definition('Old label')});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: editor,
            builder: (context, _) =>
                EditableGenUiPropertyEditor(controller: editor),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Old label'), findsOneWidget);

    editor.setSharedEditors({'Text': definition('New label')});
    await tester.pumpAndSettle();
    expect(find.text('New label'), findsOneWidget);
    expect(find.text('Old label'), findsNothing);
  });

  testWidgets('Studio omits gallery types without a contract', (tester) async {
    final editor = controller();
    addTearDown(editor.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showEditableGenUiStudio(
              context: context,
              controller: editor,
              galleryTypes: const ['Unregistered', 'Text'],
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('GenUI Touch'), findsWidgets);
  });
}
