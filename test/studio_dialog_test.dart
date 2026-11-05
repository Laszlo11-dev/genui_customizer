import 'package:genui/genui.dart';
import 'package:genui_customizer/genui_customizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('publishes a generated editor from the Gallery', (tester) async {
    final controller = EditableGenUiController(
      initial: const GenUiEditSnapshot(
        revision: 1,
        messages: [
          {
            'updateComponents': {
              'components': [
                {'id': 'root', 'component': 'Text', 'variant': 'body'},
              ],
            },
          },
        ],
      ),
      registry: EditableCatalogRegistry(
        catalogId: 'test',
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
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    const generated = EditablePropertyEditorDefinition(
      id: 'text-v2',
      components: [
        {
          'id': 'variant',
          'component': 'PropertyChoice',
          'property': 'variant',
          'label': 'Text style',
          'options': ['body', 'h1'],
        },
        {
          'id': 'root',
          'component': 'EditorColumn',
          'children': ['variant'],
        },
      ],
    );
    String? publishedType;
    final defaults = <String, Map<String, Object?>>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showEditableGenUiStudio(
              context: context,
              controller: controller,
              galleryTypes: const ['Text'],
              loadDefaults: () => defaults,
              saveDefaults: (type, values) => defaults[type] = values,
              canPublishEditors: true,
              onGenerateEditor: (_, _) async => generated,
              onPublishEditor: (type, _) async => publishedType = type,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('genui-studio-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<String>, 'Gallery view'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editable-property-variant')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('h1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('genui-save-defaults')));
    await tester.pumpAndSettle();
    expect(defaults['Text']?['variant'], 'h1');
    await tester.tap(find.text('Ask GenUI to make an editor'));
    await tester.pumpAndSettle();
    expect(find.text('Generated editor preview: text-v2'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Publish editor for BCO users'),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('genui-gallery-editor')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publish editor for BCO users'));
    await tester.pumpAndSettle();
    expect(publishedType, 'Text');
    expect(controller.editorFor('Text')?.id, 'text-v2');
    await tester.tap(find.byTooltip('Close editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('genui-studio-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<String>, 'Gallery view'),
    );
    await tester.pumpAndSettle();
    final restored = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('editable-property-variant')),
    );
    expect(restored.initialValue, 'h1');
  });

  testWidgets('gallery and surface select into the right editor panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = EditableGenUiController(
      initial: const GenUiEditSnapshot(
        revision: 1,
        messages: [
          {
            'updateComponents': {
              'surfaceId': 'review',
              'components': [
                {
                  'id': 'title',
                  'component': 'Text',
                  'variant': 'body',
                  'text': 'Example heading',
                },
                {
                  'id': 'root',
                  'component': 'Column',
                  'children': ['title'],
                },
              ],
            },
            'createSurface': {'surfaceId': 'review'},
          },
        ],
      ),
      registry: EditableCatalogRegistry(
        catalogId: 'test',
        catalogVersion: 1,
        components: [
          EditableComponentContract(type: 'Column', properties: const []),
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
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showEditableGenUiStudio(
              context: context,
              controller: controller,
              galleryTypes: const ['Column', 'Text'],
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final dialog = tester.getRect(
      find.byKey(const Key('editable-genui-studio-dialog')),
    );
    final screen =
        Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(dialog.left, greaterThan(screen.left));
    expect(dialog.top, greaterThan(screen.top));
    expect(dialog.right, lessThan(screen.right));
    expect(dialog.bottom, lessThan(screen.bottom));
    expect(find.text('Open'), findsOneWidget);
    expect(find.byKey(const Key('genui-surface-tree')), findsOneWidget);
    await tester.tap(find.byKey(const Key('genui-studio-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<String>, 'Gallery view'),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('genui-gallery')), findsOneWidget);
    await tester.tap(find.byKey(const Key('genui-studio-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<String>, 'Gallery view'),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Example heading'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('genui-tree-node-root'))).height,
      28,
    );
    await tester.tap(find.byKey(const Key('genui-tree-toggle-root')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Example heading'), findsNothing);
    await tester.tap(find.byKey(const Key('genui-tree-toggle-root')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Example heading'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Text'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('editable-property-variant')),
      findsOneWidget,
    );
  });

  testWidgets(
    'opens the selected Text in a compact editor with a structure drawer',
    (tester) async {
      tester.view.physicalSize = const Size(590, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = EditableGenUiController(
        initial: GenUiEditSnapshot(
          revision: 1,
          messages: [
            {
              'updateComponents': {
                'surfaceId': 'review',
                'components': [
                  for (var index = 0; index < 25; index++)
                    {
                      'id': 'preceding-$index',
                      'component': 'Text',
                      'text': 'Other $index',
                    },
                  {
                    'id': 'title',
                    'component': 'Text',
                    'text': {'path': '/data/item/title'},
                  },
                  {
                    'id': 'root',
                    'component': 'Column',
                    'children': [
                      for (var index = 0; index < 25; index++)
                        'preceding-$index',
                      'title',
                    ],
                  },
                ],
              },
              'createSurface': {'surfaceId': 'review'},
            },
          ],
        ),
        registry: EditableCatalogRegistry(
          catalogId: 'test',
          catalogVersion: 1,
          components: [
            EditableComponentContract(type: 'Text', properties: const []),
          ],
        ),
      );
      addTearDown(controller.dispose);
      controller.select(
        const GenUiComponentSelection(
          surfaceId: 'review',
          componentId: 'title',
          componentType: 'Text',
          definitionRevision: 1,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showEditableGenUiStudio(
                context: context,
                controller: controller,
                galleryTypes: const ['Text'],
                galleryViewModel: const {
                  'item': {'title': 'An identifiable headline'},
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Text'), findsOneWidget);
      final aiPrompt = find.byKey(const Key('editable-genui-ai-prompt'));
      expect(aiPrompt, findsNothing);
      expect(find.byKey(const Key('genui-surface-tree')), findsNothing);
      await tester.tap(find.byKey(const Key('genui-studio-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open structure'));
      await tester.pumpAndSettle();
      expect(find.textContaining('An identifiable headline'), findsOneWidget);
      final selectedFinder = find.byKey(const Key('genui-tree-node-title'));
      expect(selectedFinder, findsOneWidget);
      final selectedRect = tester.getRect(selectedFinder);
      final drawerRect = tester.getRect(find.byType(Drawer));
      expect(selectedRect.height, lessThan(60));
      expect(selectedRect.top, greaterThan(drawerRect.top));
      expect(selectedRect.bottom, lessThan(drawerRect.bottom));
      await tester.tap(find.byTooltip('Close structure'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('editable-genui-studio-dialog')),
        findsNothing,
      );
    },
  );

  testWidgets('compact Studio title fits beside its actions on Android', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = EditableGenUiController(
      initial: const GenUiEditSnapshot(revision: 1, messages: []),
      registry: EditableCatalogRegistry(
        catalogId: 'test',
        catalogVersion: 1,
        components: [],
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showEditableGenUiStudio(
              context: context,
              controller: controller,
              galleryTypes: const [],
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final saveButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.save_outlined),
    );
    final colors = Theme.of(tester.element(find.byType(AppBar))).colorScheme;
    expect(
      saveButton.style?.foregroundColor?.resolve({WidgetState.disabled}),
      colors.onInverseSurface.withValues(alpha: 0.38),
    );
    expect(
      tester.getRect(find.text('GenUI Studio')).right,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const Key('genui-studio-menu'))).left,
      ),
    );
    await tester.tap(find.byKey(const Key('genui-studio-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutDialog), findsOneWidget);
    expect(find.text('View licenses'), findsOneWidget);
    await tester.tap(find.text('View licenses'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('back asks about unsaved edits and can save or discard them', (
    tester,
  ) async {
    GenUiEditSnapshot? saved;
    final controller = EditableGenUiController(
      initial: const GenUiEditSnapshot(
        revision: 1,
        messages: [
          {
            'updateComponents': {
              'surfaceId': 'review',
              'components': [
                {'id': 'title', 'component': 'Text', 'variant': 'body'},
              ],
            },
            'createSurface': {'surfaceId': 'review'},
          },
        ],
      ),
      registry: EditableCatalogRegistry(
        catalogId: 'test',
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
          ),
        ],
      ),
      storage: CallbackEditableGenUiStorage(
        onLoad: () async => null,
        onSave: (snapshot) async {
          saved = snapshot;
        },
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showEditableGenUiStudio(
              context: context,
              controller: controller,
              galleryTypes: const ['Text'],
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    controller.select(
      const GenUiComponentSelection(
        surfaceId: 'review',
        componentId: 'title',
        componentType: 'Text',
        definitionRevision: 1,
      ),
    );
    controller.apply(const {'variant': 'h1'});
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Save changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('editable-genui-studio-dialog')),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and close'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(controller.isDirty, isFalse);
    expect(find.byKey(const Key('editable-genui-studio-dialog')), findsNothing);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    controller.select(
      GenUiComponentSelection(
        surfaceId: 'review',
        componentId: 'title',
        componentType: 'Text',
        definitionRevision: controller.snapshot.revision,
      ),
    );
    controller.apply(const {'variant': 'body'});
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(controller.component('title')?['variant'], 'h1');
    expect(find.byKey(const Key('editable-genui-studio-dialog')), findsNothing);
  });

  testWidgets(
    'keeps the tree at 600 and changes selection through the floating window',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = EditableGenUiController(
        initial: const GenUiEditSnapshot(
          revision: 1,
          messages: [
            {
              'updateComponents': {
                'surfaceId': 'review',
                'components': [
                  {
                    'id': 'root',
                    'component': 'Column',
                    'children': ['list'],
                  },
                  {
                    'id': 'list',
                    'component': 'List',
                    'children': {'componentId': 'title', 'path': '/items'},
                  },
                  {
                    'id': 'title',
                    'component': 'Text',
                    'text': {'path': 'name'},
                    'variant': 'h1',
                  },
                  {
                    'id': 'other',
                    'component': 'Text',
                    'text': 'Another widget',
                  },
                ],
              },
            },
          ],
        ),
        registry: EditableCatalogRegistry(
          catalogId: 'test',
          catalogVersion: 1,
          components: [
            EditableComponentContract(type: 'Text', properties: const []),
          ],
        ),
      );
      addTearDown(controller.dispose);
      void select(String id, {String? path}) => controller.open(
        GenUiComponentSelection(
          surfaceId: 'review',
          componentId: id,
          componentType: 'Text',
          definitionRevision: controller.snapshot.revision,
          dataPath: path,
        ),
      );
      controller.select(
        const GenUiComponentSelection(
          surfaceId: 'review',
          componentId: 'title',
          componentType: 'Text',
          definitionRevision: 1,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: TextButton(
                    onPressed: () => select('title', path: '/items/1'),
                    child: const Text('Select second instance'),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 60,
                  child: TextButton(
                    onPressed: () => select('other'),
                    child: const Text('Select other'),
                  ),
                ),
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: TextButton(
                    onPressed: () => showEditableGenUiStudio(
                      context: context,
                      controller: controller,
                      galleryTypes: const ['Text'],
                      galleryCatalog: BasicCatalogItems.asCatalog(),
                      galleryViewModel: const {
                        'items': [
                          {'name': 'First restaurant'},
                          {'name': 'Second restaurant'},
                        ],
                      },
                      loadBounds: () => const Rect.fromLTWH(400, 100, 600, 650),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('genui-surface-tree')), findsOneWidget);
      final preview = find.byKey(const Key('genui-widget-preview'));
      expect(
        find.descendant(
          of: preview,
          matching: find.text('First restaurant', findRichText: true),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Select second instance'));
      await tester.pumpAndSettle();
      expect(controller.selection?.dataPath, '/items/1');
      expect(
        find.descendant(
          of: preview,
          matching: find.text('Second restaurant', findRichText: true),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Select other'));
      await tester.pumpAndSettle();
      expect(controller.selection?.componentId, 'other');
      expect(
        find.byKey(const Key('editable-genui-studio-dialog')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('moves, resizes and restores the studio bounds', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    Rect? saved;
    double? savedSplit;
    final controller = EditableGenUiController(
      initial: const GenUiEditSnapshot(revision: 1, messages: []),
      registry: EditableCatalogRegistry(
        catalogId: 'test',
        catalogVersion: 1,
        components: [],
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showEditableGenUiStudio(
              context: context,
              controller: controller,
              galleryTypes: const [],
              loadBounds: () => saved,
              saveBounds: (bounds) => saved = bounds,
              loadSplitFraction: () => savedSplit,
              saveSplitFraction: (fraction) => savedSplit = fraction,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final window = find.byKey(const Key('editable-genui-studio-dialog'));
    final original = tester.getRect(window);
    final splitter = find.byKey(const Key('genui-studio-splitter'));
    final originalSplit = tester.getRect(splitter).left;
    await tester.drag(splitter, const Offset(-120, 0));
    await tester.pumpAndSettle();
    final adjustedSplit = tester.getRect(splitter).left;
    expect(adjustedSplit, lessThan(originalSplit));
    expect(savedSplit, isNotNull);
    await tester.tap(find.byTooltip('Close editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.getRect(splitter).left, adjustedSplit);
    await tester.drag(
      find.byKey(const Key('genui-studio-resize')),
      const Offset(-720, -200),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(window).width, lessThan(original.width));
    await tester.tap(find.byKey(const Key('genui-studio-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Open structure'), findsOneWidget);
    await tester.tap(find.text('Open structure'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close structure'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('genui-studio-drag')),
      const Offset(75, 25),
    );
    await tester.pumpAndSettle();
    final adjusted = tester.getRect(window);
    expect(adjusted.left, greaterThan(original.left));
    expect(saved, isNotNull);
    await tester.tap(find.byTooltip('Close editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.getRect(window), adjusted);
  });
}
