import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui_customizer/genui_customizer.dart';

// Regression coverage for controller state isolation and asynchronous edits.
EditableGenUiController controller({
  EditableGenUiStorage? storage,
  EditableGenUiComposer? composer,
}) => EditableGenUiController(
  initial: const GenUiEditSnapshot(
    revision: 1,
    messages: [
      {
        'updateComponents': {
          'surfaceId': 's',
          'components': [
            {
              'id': 'a',
              'component': 'Text',
              'variant': 'body',
              'text': {'path': '/title'},
            },
            {
              'id': 'b',
              'component': 'Text',
              'variant': 'body',
              'text': 'Other',
            },
          ],
        },
      },
    ],
  ),
  registry: EditableCatalogRegistry(
    catalogId: 'c',
    catalogVersion: 1,
    components: [
      EditableComponentContract(
        type: 'Text',
        properties: const [
          EditablePropertyContract(
            name: 'variant',
            label: 'Style',
            type: EditablePropertyType.enumeration,
            enumValues: ['body', 'h1', 'h2'],
          ),
        ],
        protectedProperties: const {'text'},
      ),
    ],
  ),
  storage: storage,
  composer: composer,
);

void chooseA(EditableGenUiController value) => value.select(
  GenUiComponentSelection(
    surfaceId: 's',
    componentId: 'a',
    componentType: 'Text',
    definitionRevision: value.snapshot.revision,
  ),
);

final class WrongTargetComposer implements EditableGenUiComposer {
  @override
  Future<GenUiPropertyPatch> propose({
    required GenUiEditSnapshot snapshot,
    required GenUiComponentSelection selection,
    required String instruction,
    required GenUiEditConstraints constraints,
  }) async => GenUiPropertyPatch(
    expectedRevision: snapshot.revision,
    componentId: 'b',
    changes: const {'variant': 'h1'},
    origin: GenUiEditOrigin.ai,
  );
}

final class PendingComposer implements EditableGenUiComposer {
  final response = Completer<GenUiPropertyPatch>();
  @override
  Future<GenUiPropertyPatch> propose({
    required GenUiEditSnapshot snapshot,
    required GenUiComponentSelection selection,
    required String instruction,
    required GenUiEditConstraints constraints,
  }) => response.future;
}

GenUiPropertyPatch aiPatch(int revision) => GenUiPropertyPatch(
  expectedRevision: revision,
  componentId: 'a',
  changes: const {'variant': 'h1'},
  origin: GenUiEditOrigin.ai,
);

void main() {
  test('valid AI response still applies', () async {
    final ai = PendingComposer();
    final value = controller(composer: ai);
    addTearDown(value.dispose);
    chooseA(value);
    final editing = value.prompt('Larger');
    ai.response.complete(aiPatch(1));
    await editing;
    expect(value.component('a')!['variant'], 'h1');
    expect(value.error, isNull);
  });

  test(
    'AI response is stale even after undo returns to the original revision',
    () async {
      final ai = PendingComposer();
      final value = controller(composer: ai);
      addTearDown(value.dispose);
      chooseA(value);
      final editing = value.prompt('Larger');
      value.apply({'variant': 'h2'});
      value.undo();
      expect(value.snapshot.revision, 1);
      ai.response.complete(aiPatch(1));
      await editing;
      expect(value.component('a')!['variant'], 'body');
      expect(value.error, contains('UI changed'));
    },
  );

  test('AI cannot supply a fresh revision for a changed snapshot', () async {
    final ai = PendingComposer();
    final value = controller(composer: ai);
    addTearDown(value.dispose);
    chooseA(value);
    final editing = value.prompt('Larger');
    value.apply({'variant': 'h2'});
    ai.response.complete(aiPatch(value.snapshot.revision));
    await editing;
    expect(value.component('a')!['variant'], 'h2');
    expect(value.error, contains('UI changed'));
  });

  test(
    'old save completion does not overwrite a replacement surface baseline',
    () async {
      final pending = Completer<void>();
      final value = controller(
        storage: CallbackEditableGenUiStorage(
          onLoad: () async => null,
          onSave: (_) => pending.future,
        ),
      );
      addTearDown(value.dispose);
      chooseA(value);
      value.apply({'variant': 'h1'});
      final saving = value.save();
      final replacement = controller();
      addTearDown(replacement.dispose);
      value.setSurfaceSnapshot(replacement.snapshot);
      pending.complete();
      await saving;
      expect(value.isDirty, isFalse);
      value.apply({'variant': 'h2'});
      value.cancel();
      expect(value.component('a')!['variant'], 'body');
    },
  );

  test('save completion leaves newer edits dirty', () async {
    final pending = Completer<void>();
    GenUiEditSnapshot? persisted;
    final value = controller(
      storage: CallbackEditableGenUiStorage(
        onLoad: () async => null,
        onSave: (snapshot) async {
          persisted = snapshot;
          await pending.future;
        },
      ),
    );
    addTearDown(value.dispose);
    chooseA(value);
    value.apply({'variant': 'h1'});
    final saving = value.save();
    value.apply({'variant': 'h2'});
    pending.complete();
    await saving;
    final savedComponents =
        (persisted!.messages.single['updateComponents'] as Map)['components']
            as List;
    expect((savedComponents.first as Map)['variant'], 'h1');
    expect(value.component('a')!['variant'], 'h2');
    expect(value.isDirty, isTrue);
    expect(value.canUndo, isTrue);
    value.cancel();
    expect(value.component('a')!['variant'], 'h1');
  });

  test('AI response cannot patch an unselected component', () async {
    final value = controller(composer: WrongTargetComposer());
    addTearDown(value.dispose);
    chooseA(value);
    await value.prompt('Make this heading larger');
    expect(value.selection!.componentId, 'a');
    expect(value.component('a')!['variant'], 'body');
    expect(value.component('b')!['variant'], 'body');
    expect(value.error, contains('another component'));
  });

  test('component getter isolates protected nested state', () {
    final value = controller();
    addTearDown(value.dispose);
    var notifications = 0;
    value.addListener(() => notifications++);
    final binding = value.component('a')!['text'] as Map;
    binding['path'] = '/changed-without-validation';
    expect((value.component('a')!['text'] as Map)['path'], '/title');
    expect(value.snapshot.revision, 1);
    expect(value.canUndo, isFalse);
    expect(notifications, 0);
  });
}
