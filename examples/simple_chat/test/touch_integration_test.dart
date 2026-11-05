import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_customizer/genui_customizer.dart';
import 'package:simple_chat/agent/recorded_ai_client.dart';
import 'package:simple_chat/chat_session.dart';
import 'package:simple_chat/main.dart';
import 'package:simple_chat/primitives/app_mode.dart';
import 'package:simple_chat/primitives/climbing/a2ui_components/climbing.dart';
import 'package:simple_chat/touch_integration.dart';

void select(
  EditableGenUiController editor,
  String surface,
  String id,
  String type,
) {
  editor.select(
    GenUiComponentSelection(
      surfaceId: surface,
      componentId: id,
      componentType: type,
      definitionRevision: editor.snapshot.revision,
    ),
  );
}

void main() {
  late ChatTouchIntegration touch;
  late SurfaceController host;

  setUp(() {
    touch = ChatTouchIntegration(
      catalog: BasicCatalogItems.asCatalog(),
      onChanged: () {},
    );
    host = SurfaceController(catalogs: [touch.decoratedCatalog]);
  });
  tearDown(() {
    touch.dispose();
    host.dispose();
  });

  void create(String id) {
    touch.handleMessage(
      core.CreateSurfaceMessage(surfaceId: id, catalogId: basicCatalogId),
      host,
    );
    touch.handleMessage(
      core.UpdateComponentsMessage(
        surfaceId: id,
        components: [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['label'],
          },
          {
            'id': 'label',
            'component': 'Text',
            'text': {'path': '/title'},
            'variant': 'body',
          },
        ],
      ),
      host,
    );
  }

  test('same component IDs in two replies remain isolated', () {
    create('one');
    create('two');
    final one = touch.editorFor('one')!;
    select(one, 'one', 'label', 'Text');
    one.apply({'variant': 'h1'});
    expect(one.component('label')!['variant'], 'h1');
    expect(touch.editorFor('two')!.component('label')!['variant'], 'body');
    expect(
      host
          .contextFor('one')
          .definition
          .value!
          .components['label']!
          .properties['variant'],
      'h1',
    );
    expect(
      host
          .contextFor('two')
          .definition
          .value!
          .components['label']!
          .properties['variant'],
      'body',
    );
  });

  test(
    'incremental updates retain the root, untouched edits, and bindings',
    () {
      create('one');
      final editor = touch.editorFor('one')!;
      select(editor, 'one', 'label', 'Text');
      editor.apply({'variant': 'h1'});
      touch.handleMessage(
        core.UpdateComponentsMessage(
          surfaceId: 'one',
          components: [
            {'id': 'extra', 'component': 'Text', 'text': 'New content'},
          ],
        ),
        host,
      );
      expect(editor.component('root'), isNotNull);
      expect(editor.component('label')!['variant'], 'h1');
      expect(editor.component('label')!['text'], {'path': '/title'});
      expect(editor.component('extra')!['text'], 'New content');
      expect(
        editor.canUndo,
        isFalse,
        reason: 'Incoming deltas rebase the editor.',
      );
    },
  );

  test('agent replacement of an edited component becomes authoritative', () {
    create('one');
    final editor = touch.editorFor('one')!;
    select(editor, 'one', 'label', 'Text');
    editor.apply({'variant': 'h1'});
    touch.handleMessage(
      core.UpdateComponentsMessage(
        surfaceId: 'one',
        components: [
          {
            'id': 'label',
            'component': 'Text',
            'text': 'Agent replacement',
            'variant': 'h5',
          },
        ],
      ),
      host,
    );
    expect(editor.component('label')!['variant'], 'h5');
    expect(editor.component('root'), isNotNull);
  });

  test(
    'save establishes a conversation checkpoint and discard restores it',
    () async {
      create('one');
      final editor = touch.editorFor('one')!;
      select(editor, 'one', 'label', 'Text');
      editor.apply({'variant': 'h1'});
      await editor.save();
      expect(editor.isDirty, isFalse);
      editor.apply({'variant': 'caption'});
      editor.cancel();
      expect(editor.component('label')!['variant'], 'h1');
      expect(editor.isDirty, isFalse);
    },
  );

  test('Touch refuses content, binding, and structural changes', () {
    create('one');
    final editor = touch.editorFor('one')!;
    select(editor, 'one', 'label', 'Text');
    editor.apply({'text': 'Overwritten'});
    expect(editor.error, contains('protected'));
    expect(editor.component('label')!['text'], {'path': '/title'});
    select(editor, 'one', 'root', 'Column');
    editor.apply({'children': []});
    expect(editor.error, contains('protected'));
    expect(editor.component('root')!['children'], ['label']);
  });

  test('data updates bypass Touch and surface deletion removes its editor', () {
    create('one');
    touch.handleMessage(
      core.UpdateDataModelMessage(
        surfaceId: 'one',
        path: '/title',
        value: 'Live data',
      ),
      host,
    );
    expect(
      host.contextFor('one').dataModel.getValue<String>(DataPath('/title')),
      'Live data',
    );
    final oldEditor = touch.editorFor('one')!;
    String? removedId;
    touch.onSurfaceRemoved = (id) => removedId = id;
    touch.handleMessage(core.DeleteSurfaceMessage(surfaceId: 'one'), host);
    expect(touch.editorFor('one'), isNull);
    expect(host.activeSurfaceIds, isEmpty);
    expect(removedId, 'one');
    select(oldEditor, 'one', 'label', 'Text');
    oldEditor.apply({'variant': 'h1'});
    expect(host.activeSurfaceIds, isEmpty);
  });

  test(
    'recorded responses use the real transport and create separate surfaces',
    () async {
      final client = RecordedChatAiClient(mode: AppMode.customCatalog);
      final session = ChatSession(
        aiClient: client,
        mode: AppMode.customCatalog,
      ) as A2uiChatSession;
      addTearDown(session.dispose);
      await session.sendMessage('Climbing');
      await Future<void>.delayed(Duration.zero);
      await session.sendMessage('Another location');
      await Future<void>.delayed(Duration.zero);
      expect(session.surfaceController.activeSurfaceIds, [
        'recorded-1',
        'recorded-2',
      ]);
      final editor = session.touch.editorFor('recorded-1')!;
      select(editor, 'recorded-1', 'location', 'ClimbingLocation');
      editor.apply({'imageVisibility': 'hide', 'density': 'compact'});
      expect(editor.error, isNull);
      expect(
        session.touch
            .editorFor('recorded-2')!
            .component('location')!['imageVisibility'],
        'show',
      );
    },
  );

  testWidgets(
    'basic button actions still generate replies and gestures target the second reply',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.byType(DropdownButton<AppMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Basic catalog').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(find.byType(Surface), findsOneWidget);
      await tester.tap(find.text('Show another idea'));
      await tester.pumpAndSettle();
      expect(find.byType(Surface), findsNWidgets(2));
      await tester.longPress(find.byType(Surface).last);
      await tester.pumpAndSettle();
      final propertyEditor = tester.widget<EditableGenUiPropertyEditor>(
        find.byType(EditableGenUiPropertyEditor),
      );
      expect(propertyEditor.controller.selection?.surfaceId, 'recorded-2');
      await tester.tap(find.byTooltip('Close editor'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'open Touch from a reply, edit the custom card, save and reopen',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(find.byType(ClimbingLocation), findsOneWidget);
      await tester.tap(find.text('GenUI Touch'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('genui-tree-node-location')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('editable-property-imageVisibility')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('hide').last);
      await tester.pumpAndSettle();
      final liveCard = tester
          .widgetList<ClimbingLocation>(find.byType(ClimbingLocation))
          .first;
      expect(liveCard.showImage, isFalse);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close editor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GenUI Touch'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('genui-tree-node-location')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const ValueKey('editable-property-imageVisibility')),
            )
            .initialValue,
        'hide',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
