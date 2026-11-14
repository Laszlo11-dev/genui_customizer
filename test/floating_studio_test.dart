import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/basic_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_customizer/genui_customizer.dart';

class _MemoryStorage implements TouchStorage {
  TouchProfile? saved;

  @override
  Future<TouchProfile?> load() async => saved;

  @override
  Future<void> save(TouchProfile profile) async => saved = profile;
}

void main() {
  testWidgets('open Studio follows a new surface without a selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final contract = TouchContract(
      catalogId: BasicCatalog.v1_0Id,
      componentType: 'Text',
      properties: const [
        TouchProperty(
          name: 'variant',
          label: 'Style',
          kind: TouchValueKind.choice,
          choices: ['body', 'caption'],
        ),
      ],
    );
    final controller = GenUiTouchController(contracts: [contract]);
    final processor = MessageProcessor<ComponentImplementation>(
      catalogs: [controller.decorateCatalog(basicCatalog())],
    );
    controller.attachProcessor(processor);
    addTearDown(controller.dispose);
    addTearDown(processor.dispose);
    for (final (surfaceId, componentId) in [
      ('one', 'first'),
      ('two', 'second'),
    ]) {
      controller.processAgentMessages([
        {
          'version': '1.0',
          'createSurface': {
            'surfaceId': surfaceId,
            'catalogId': BasicCatalog.v1_0Id,
          },
        },
        {
          'version': '1.0',
          'updateComponents': {
            'surfaceId': surfaceId,
            'components': [
              {'id': componentId, 'component': 'Text', 'text': componentId},
            ],
          },
        },
      ]);
    }
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );
    showGenUiTouchStudio(
      context: hostContext,
      controller: controller,
      surfaceId: 'one',
      boundsPersistence: null,
    );
    await tester.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);

    showGenUiTouchStudio(
      context: hostContext,
      controller: controller,
      surfaceId: 'two',
      boundsPersistence: null,
    );
    await tester.pumpAndSettle();
    expect(find.text('second'), findsOneWidget);
    expect(find.text('first'), findsNothing);
    await tester.tap(find.byTooltip('Close editor'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'reuses the window and confirms unsaved changes before switching',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final contract = TouchContract(
        catalogId: BasicCatalog.v1_0Id,
        componentType: 'Text',
        properties: const [
          TouchProperty(
            name: 'variant',
            label: 'Text style',
            kind: TouchValueKind.choice,
            choices: ['body', 'caption'],
          ),
        ],
      );
      final storage = _MemoryStorage();
      final controller = GenUiTouchController(
        contracts: [contract],
        storage: storage,
      );
      final processor = MessageProcessor<ComponentImplementation>(
        catalogs: [controller.decorateCatalog(basicCatalog())],
      );
      controller.attachProcessor(processor);
      addTearDown(controller.dispose);
      addTearDown(processor.dispose);
      controller.processAgentMessages([
        {
          'version': '1.0',
          'createSurface': {
            'surfaceId': 'one',
            'catalogId': BasicCatalog.v1_0Id,
          },
        },
        {
          'version': '1.0',
          'updateComponents': {
            'surfaceId': 'one',
            'components': [
              {'id': 'first', 'component': 'Text', 'text': 'First'},
              {'id': 'second', 'component': 'Text', 'text': 'Second'},
            ],
          },
        },
      ]);
      TouchSelection selection(String id) => TouchSelection(
        surfaceId: 'one',
        componentId: id,
        catalogId: BasicCatalog.v1_0Id,
        componentType: 'Text',
        instanceId: id,
        dataPath: '',
      );

      late BuildContext hostContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              hostContext = context;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      );
      controller.select(selection('first'));
      showGenUiTouchStudio(
        context: hostContext,
        controller: controller,
        surfaceId: 'one',
        galleryOnly: true,
        boundsPersistence: null,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('genui-touch-studio-dialog')),
        findsOneWidget,
      );

      controller.setGalleryDefault(contract, 'variant', 'caption');
      controller.select(selection('second'));
      showGenUiTouchStudio(
        context: hostContext,
        controller: controller,
        surfaceId: 'one',
        galleryOnly: true,
      );
      await tester.pumpAndSettle();
      expect(find.text('Unsaved appearance changes'), findsOneWidget);
      expect(
        find.byKey(const Key('genui-touch-studio-dialog')),
        findsOneWidget,
      );
      expect(controller.selection?.componentId, 'first');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.selection?.componentId, 'first');
      expect(controller.hasUnsavedProfileChanges, isTrue);

      controller.select(selection('second'));
      showGenUiTouchStudio(
        context: hostContext,
        controller: controller,
        surfaceId: 'one',
        galleryOnly: true,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(controller.selection?.componentId, 'second');
      expect(controller.hasUnsavedProfileChanges, isFalse);
      expect(
        find.byKey(const Key('genui-touch-studio-dialog')),
        findsOneWidget,
      );

      controller.select(selection('first'));
      showGenUiTouchStudio(
        context: hostContext,
        controller: controller,
        surfaceId: 'one',
        galleryOnly: true,
      );
      await tester.pumpAndSettle();
      expect(find.text('Unsaved appearance changes'), findsNothing);
      expect(
        find.byKey(const Key('genui-touch-studio-dialog')),
        findsOneWidget,
      );

      controller.setGalleryDefault(contract, 'variant', 'caption');
      controller.select(selection('second'));
      showGenUiTouchStudio(
        context: hostContext,
        controller: controller,
        surfaceId: 'one',
        galleryOnly: true,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(controller.selection?.componentId, 'second');
      expect(controller.hasUnsavedProfileChanges, isFalse);
      expect(storage.saved?.defaults.values.single['variant'], 'caption');
      expect(
        find.byKey(const Key('genui-touch-studio-dialog')),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Close editor'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('genui-touch-studio-dialog')), findsNothing);
    },
  );
}
