import 'package:genui_customizer/src/core/core.dart';
import 'package:test/test.dart';

void main() {
  test('shared editor definition survives serialization', () {
    const definition = EditablePropertyEditorDefinition(
      id: 'assessment-v2',
      components: [
        {
          'id': 'root',
          'component': 'EditorColumn',
          'children': ['variant'],
        },
        {
          'id': 'variant',
          'component': 'PropertyChoice',
          'property': 'variant',
          'label': 'Detail level',
          'options': ['summary', 'detailed'],
        },
      ],
    );
    final restored = EditablePropertyEditorDefinition.fromJson(
      definition.toJson(),
    );
    expect(restored.id, definition.id);
    expect(restored.components, definition.components);
  });

  test('rejects malformed shared editor data', () {
    expect(
      () => EditablePropertyEditorDefinition.fromJson({
        'id': 'broken',
        'components': [
          {'id': 'root'},
        ],
      }),
      throwsFormatException,
    );
  });
}
