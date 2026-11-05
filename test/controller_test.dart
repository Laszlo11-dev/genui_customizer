import 'package:genui_customizer/genui_customizer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'adaptive trigger opens the same component on triple mouse click',
    (tester) async {
      var opens = 0;
      final controller = _controller(onOpen: () => opens++);
      addTearDown(controller.dispose);
      const selection = GenUiComponentSelection(
        surfaceId: 'surface',
        componentId: 'panel',
        componentType: 'Panel',
        definitionRevision: 1,
      );

      for (var index = 0; index < 3; index++) {
        controller.handlePointerDown(
          PointerDownEvent(
            pointer: 1,
            position: const Offset(20, 20),
            timeStamp: Duration(milliseconds: index * 100),
            kind: PointerDeviceKind.mouse,
            buttons: kPrimaryMouseButton,
          ),
          selection,
        );
        await tester.pump();
        controller.handlePointerUp(
          const PointerUpEvent(
            pointer: 1,
            position: Offset(20, 20),
            kind: PointerDeviceKind.mouse,
          ),
          selection,
        );
      }

      expect(opens, 1);
      expect(controller.selection?.componentId, 'panel');
    },
  );

  testWidgets('adaptive trigger opens on touch long press', (tester) async {
    var opens = 0;
    final controller = _controller(onOpen: () => opens++);
    addTearDown(controller.dispose);
    const selection = GenUiComponentSelection(
      surfaceId: 'surface',
      componentId: 'panel',
      componentType: 'Panel',
      definitionRevision: 1,
    );

    controller.handlePointerDown(
      const PointerDownEvent(
        pointer: 2,
        position: Offset(20, 20),
        kind: PointerDeviceKind.touch,
      ),
      selection,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(opens, 1);
    expect(controller.selection?.componentId, 'panel');
  });
}

EditableGenUiController _controller({required VoidCallback onOpen}) =>
    EditableGenUiController(
      initial: const GenUiEditSnapshot(
        revision: 1,
        messages: [
          {
            'updateComponents': {
              'components': [
                {'id': 'panel', 'component': 'Panel', 'variant': 'compact'},
              ],
            },
          },
        ],
      ),
      registry: EditableCatalogRegistry(
        catalogId: 'catalog',
        catalogVersion: 1,
        components: [
          EditableComponentContract(
            type: 'Panel',
            properties: const [
              EditablePropertyContract(
                name: 'variant',
                label: 'Variant',
                type: EditablePropertyType.enumeration,
                enumValues: ['compact', 'detailed'],
              ),
            ],
          ),
        ],
      ),
      onEditorRequested: onOpen,
    );
