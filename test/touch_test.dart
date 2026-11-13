import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/basic_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_customizer/genui_customizer.dart';

void main() {
  final textContract = TouchContract(
    catalogId: BasicCatalog.v1_0Id,
    componentType: 'Text',
    properties: [
      const TouchProperty(
        name: 'variant',
        label: 'Text style',
        kind: TouchValueKind.choice,
        choices: ['body', 'caption'],
      ),
    ],
  );

  testWidgets('runtime edit and Gallery default use the A2UI v1 processor', (
    tester,
  ) async {
    final touch = GenUiTouchController(
      contracts: [textContract],
      roleFor: (_, _) => 'sample-text',
    );
    final catalog = touch.decorateCatalog(basicCatalog());
    final processor = MessageProcessor<ComponentImplementation>(
      catalogs: [catalog],
    );
    touch.attachProcessor(processor);
    addTearDown(touch.dispose);
    addTearDown(processor.dispose);

    touch.setGalleryDefault(textContract, 'variant', 'caption');
    touch.processAgentMessages([
      {
        'version': '1.0',
        'createSurface': {'surfaceId': 'one', 'catalogId': catalog.id},
      },
      {
        'version': '1.0',
        'updateComponents': {
          'surfaceId': 'one',
          'components': [
            {'id': 'root', 'component': 'Text', 'text': 'Hello'},
          ],
        },
      },
    ]);
    final selected = TouchSelection(
      surfaceId: 'one',
      componentId: 'root',
      catalogId: catalog.id,
      componentType: 'Text',
      instanceId: 'root',
      dataPath: '',
    );
    expect(touch.component(selected)?['variant'], 'caption');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: A2uiSurface(surface: processor.model.getSurface('one')!),
        ),
      ),
    );
    expect(find.text('Hello'), findsOneWidget);
    touch.select(selected);
    touch.edit('variant', 'body');
    expect(touch.component(selected)?['variant'], 'body');
    touch.undo();
    expect(touch.component(selected)?['variant'], 'caption');
    touch.redo();
    expect(touch.component(selected)?['variant'], 'body');
    touch.setRoleDefaultForSelection('variant');
    touch.processAgentMessages({
      'version': '1.0',
      'updateComponents': {
        'surfaceId': 'one',
        'components': [
          {'id': 'another', 'component': 'Text', 'text': 'Again'},
        ],
      },
    });
    expect(
      touch.component(
        const TouchSelection(
          surfaceId: 'one',
          componentId: 'another',
          catalogId: BasicCatalog.v1_0Id,
          componentType: 'Text',
          instanceId: 'another',
          dataPath: '',
        ),
      )?['variant'],
      'body',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GenUiTouchStudio(controller: touch, surfaceId: 'one'),
      ),
    );
    expect(find.text('GenUI Touch'), findsOneWidget);
    final undoFinder = find.ancestor(
      of: find.byTooltip('Undo'),
      matching: find.byType(IconButton),
    );
    final undoButton = tester.widget<IconButton>(undoFinder);
    final colors = Theme.of(tester.element(undoFinder)).colorScheme;
    expect(
      undoButton.style?.foregroundColor?.resolve({WidgetState.disabled}),
      colors.onInverseSurface.withValues(alpha: 0.38),
    );
    await tester.tap(find.byKey(const Key('genui-studio-menu')));
    await tester.pumpAndSettle();
    expect(find.text('About'), findsOneWidget);
    expect(find.text('GenUI debug'), findsOneWidget);
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.text('Make generated UI your own.'), findsOneWidget);
    expect(find.text('pub.dev package'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('genui-studio-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GenUI debug'));
    await tester.pumpAndSettle();
    expect(find.textContaining('"surfaceId": "one"'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gallery'));
    await tester.pump();
    expect(find.textContaining('Default appearance'), findsOneWidget);
  });

  test('bound values cannot be edited and profile format is validated', () {
    const color = TouchProperty(
      name: 'backgroundColor',
      label: 'Background color',
      kind: TouchValueKind.color,
    );
    expect(color.accepts('#4F46E5'), isTrue);
    expect(color.accepts('#804F46E5'), isTrue);
    expect(color.accepts('not a color'), isFalse);
    expect(
      () => TouchProfile.fromJson({'formatVersion': 1}),
      throwsFormatException,
    );
    expect(
      TouchProfile.fromJson(const TouchProfile().toJson())
          .toJson()['formatVersion'],
      2,
    );
  });
}
