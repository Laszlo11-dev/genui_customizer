import 'package:genui_customizer/src/core/core.dart';
import 'package:test/test.dart';

void main() {
  final registry = EditableCatalogRegistry(
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
        protectedProperties: const {'binding'},
      ),
    ],
  );

  test('applies atomic property patches and preserves unknown properties', () {
    final session = EditableGenUiSession(
      initial: _snapshot(),
      registry: registry,
    );
    session.select(
      const GenUiComponentSelection(
        surfaceId: 'surface',
        componentId: 'panel',
        componentType: 'Panel',
        definitionRevision: 3,
      ),
    );

    session.apply(
      const GenUiPropertyPatch(
        expectedRevision: 3,
        componentId: 'panel',
        changes: {'variant': 'detailed'},
        origin: GenUiEditOrigin.manual,
      ),
    );

    expect(session.component('panel')?['variant'], 'detailed');
    expect(session.component('panel')?['unknown'], 42);
    expect(session.current.revision, 4);
    expect(session.selection?.definitionRevision, 4);
  });

  test('undo, redo and cancel share one history for every edit origin', () {
    final session = EditableGenUiSession(
      initial: _snapshot(),
      registry: registry,
    );
    session.apply(
      const GenUiPropertyPatch(
        expectedRevision: 3,
        componentId: 'panel',
        changes: {'variant': 'detailed'},
        origin: GenUiEditOrigin.ai,
      ),
    );
    session.undo();
    expect(session.component('panel')?['variant'], 'compact');
    session.redo();
    expect(session.component('panel')?['variant'], 'detailed');
    session.cancel();
    expect(session.component('panel')?['variant'], 'compact');
    expect(session.isDirty, isFalse);
  });

  test('rejects a patch that repeats the current value', () {
    final session = EditableGenUiSession(
      initial: _snapshot(),
      registry: registry,
    );
    expect(
      () => session.apply(
        const GenUiPropertyPatch(
          expectedRevision: 3,
          componentId: 'panel',
          changes: {'variant': 'compact'},
          origin: GenUiEditOrigin.ai,
        ),
      ),
      throwsFormatException,
    );
    expect(session.current.revision, 3);
    expect(session.isDirty, isFalse);
  });

  test('rejects stale, protected and invalid changes', () {
    final session = EditableGenUiSession(
      initial: _snapshot(),
      registry: registry,
    );
    expect(
      () => session.apply(
        const GenUiPropertyPatch(
          expectedRevision: 2,
          componentId: 'panel',
          changes: {'variant': 'detailed'},
          origin: GenUiEditOrigin.manual,
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => session.apply(
        const GenUiPropertyPatch(
          expectedRevision: 3,
          componentId: 'panel',
          changes: {'binding': '/other'},
          origin: GenUiEditOrigin.manual,
        ),
      ),
      throwsFormatException,
    );
  });

  test('validates a saved property-only transition against its base', () {
    final edited = _snapshot().messages
        .map((message) => Map<String, Object?>.from(message))
        .toList();
    final session = EditableGenUiSession(
      initial: _snapshot(),
      registry: registry,
    );
    final valid = session.apply(
      const GenUiPropertyPatch(
        expectedRevision: 3,
        componentId: 'panel',
        changes: {'variant': 'detailed'},
        origin: GenUiEditOrigin.manual,
      ),
    );
    validateEditableTransition(
      baseMessages: _snapshot().messages,
      editedMessages: valid.messages,
      registry: registry,
    );
    expect(
      () => validateEditableTransition(
        baseMessages: _snapshot().messages,
        editedMessages: edited
          ..first['extra'] = {
            'id': 'other',
            'component': 'Panel',
            'variant': 'compact',
          },
        registry: registry,
      ),
      throwsFormatException,
    );
  });
}

GenUiEditSnapshot _snapshot() => const GenUiEditSnapshot(
  revision: 3,
  messages: [
    {
      'updateComponents': {
        'components': [
          {
            'id': 'panel',
            'component': 'Panel',
            'variant': 'compact',
            'binding': '/trusted',
            'unknown': 42,
          },
        ],
      },
    },
  ],
);
