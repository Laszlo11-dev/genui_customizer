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

class _MemoryBounds implements TouchStudioBoundsPersistence {
  _MemoryBounds(this.bounds);

  Rect bounds;
  int saves = 0;

  @override
  Future<Rect?> load() async => bounds;

  @override
  Future<void> save(Rect value) async {
    bounds = value;
    saves++;
  }
}

void main() {
  testWidgets('drag and resize accumulate pointer movement between frames', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = GenUiTouchController(contracts: []);
    final processor = MessageProcessor<ComponentImplementation>(
      catalogs: [controller.decorateCatalog(basicCatalog())],
    );
    controller.attachProcessor(processor);
    addTearDown(controller.dispose);
    addTearDown(processor.dispose);
    final persistence = _MemoryBounds(const Rect.fromLTWH(100, 100, 500, 500));
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
      surfaceId: 'test',
      boundsPersistence: persistence,
    );
    await tester.pumpAndSettle();

    final dialog = find.byKey(const Key('genui-touch-studio-dialog'));
    final window = tester.widget<Dialog>(
      find.ancestor(of: dialog, matching: find.byType(Dialog)).first,
    );
    expect(window.backgroundColor, Colors.white);
    expect(window.surfaceTintColor, Colors.transparent);
    expect(window.elevation, 24);
    expect(
      (window.shape as RoundedRectangleBorder).borderRadius,
      BorderRadius.zero,
    );
    expect((window.shape as RoundedRectangleBorder).side, BorderSide.none);
    final toolbar = tester.widget<AppBar>(
      find.descendant(
        of: find.byType(GenUiTouchStudio),
        matching: find.byType(AppBar),
      ),
    );
    expect(toolbar.backgroundColor, const Color(0xFF151D2B));
    expect(toolbar.foregroundColor, Colors.white);
    final studio = tester.widget<GenUiTouchStudio>(
      find.byType(GenUiTouchStudio),
    );
    final drag = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('genui-studio-drag'))),
    );
    await drag.moveBy(const Offset(20, 10));
    await tester.pump();
    final movedOnce = tester.getRect(dialog);
    await drag.moveBy(const Offset(30, 15));
    await drag.moveBy(const Offset(40, 20));
    await tester.pump();
    final movedAgain = tester.getRect(dialog);
    expect(movedAgain.left - movedOnce.left, 70);
    expect(movedAgain.top - movedOnce.top, 35);
    expect(
      identical(
        tester.widget<GenUiTouchStudio>(find.byType(GenUiTouchStudio)),
        studio,
      ),
      isTrue,
    );
    await drag.up();
    await tester.pump();

    final resize = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('genui-studio-resize'))),
    );
    await resize.moveBy(const Offset(10, 10));
    await tester.pump();
    final resizedOnce = tester.getRect(dialog);
    await resize.moveBy(const Offset(20, 15));
    await resize.moveBy(const Offset(30, 20));
    await tester.pump();
    final resizedAgain = tester.getRect(dialog);
    expect(resizedAgain.width - resizedOnce.width, 50);
    expect(resizedAgain.height - resizedOnce.height, 35);
    await resize.up();
    await tester.pump();
    expect(persistence.saves, 2);
    await tester.tap(find.byTooltip('Close editor'));
    await tester.pumpAndSettle();
  });

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
