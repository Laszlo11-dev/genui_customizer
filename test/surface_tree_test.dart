import 'package:genui_customizer/src/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('projects the current surface component hierarchy', () {
    const snapshot = GenUiEditSnapshot(
      revision: 2,
      messages: [
        {
          'updateComponents': {
            'surfaceId': 'review',
            'components': [
              {'id': 'first', 'component': 'FactCard'},
              {'id': 'second', 'component': 'Assessment'},
              {
                'id': 'group',
                'component': 'Column',
                'children': ['first'],
              },
              {
                'id': 'root',
                'component': 'Row',
                'children': ['group', 'second'],
              },
              {'id': 'unused', 'component': 'Text', 'text': 'Not rendered'},
            ],
          },
        },
      ],
    );

    final tree = buildGenUiSurfaceTree(snapshot)!;
    expect(tree.type, 'Row');
    expect(tree.children.map((node) => node.id), ['group', 'second']);
    expect(tree.children.first.children.single.id, 'first');
  });

  test('ignores cyclic references', () {
    const snapshot = GenUiEditSnapshot(
      revision: 1,
      messages: [
        {
          'updateComponents': {
            'components': [
              {
                'id': 'root',
                'component': 'Column',
                'children': ['a'],
              },
              {
                'id': 'a',
                'component': 'Column',
                'children': ['root'],
              },
            ],
          },
        },
      ],
    );
    expect(buildGenUiSurfaceTree(snapshot)!.children.single.children, isEmpty);
  });

  test('includes widgets inside a data-bound list template', () {
    const snapshot = GenUiEditSnapshot(
      revision: 1,
      messages: [
        {
          'updateComponents': {
            'components': [
              {
                'id': 'root',
                'component': 'List',
                'children': {'componentId': 'template', 'path': '/items'},
              },
              {'id': 'template', 'component': 'Card', 'child': 'image'},
              {
                'id': 'image',
                'component': 'Image',
                'url': {'path': 'imageUrl'},
              },
            ],
          },
        },
      ],
    );

    final tree = buildGenUiSurfaceTree(snapshot)!;
    expect(tree.children.single.id, 'template');
    expect(tree.children.single.children.single.id, 'image');
  });
}
