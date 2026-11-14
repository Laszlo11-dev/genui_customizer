import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/basic_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_customizer/genui_customizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _PendingStorage implements TouchStorage {
  final pending = Completer<void>();
  TouchProfile? saved;

  @override
  Future<TouchProfile?> load() async => saved;

  @override
  Future<void> save(TouchProfile profile) async {
    await pending.future;
    saved = profile;
  }
}

class _DeferredLoadStorage implements TouchStorage {
  final pending = Completer<TouchProfile?>();

  @override
  Future<TouchProfile?> load() => pending.future;

  @override
  Future<void> save(TouchProfile profile) async {}
}

void main() {
  test('late load does not replace edits made while loading', () async {
    final contract = TouchContract(
      catalogId: 'catalog',
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
    final storage = _DeferredLoadStorage();
    final touch = GenUiTouchController(contracts: [contract], storage: storage);
    addTearDown(touch.dispose);
    final load = touch.load();
    touch.setGalleryDefault(contract, 'variant', 'body');
    storage.pending.complete(TouchProfile());
    await load;

    expect(touch.profile.defaults['catalog\u0000Text']?['variant'], 'body');
    expect(touch.hasUnsavedProfileChanges, isTrue);
  });

  test('configuration data is a deep immutable JSON copy', () {
    final values = <Object?>['first'];
    final input = <String, Object?>{
      'nested': <String, Object?>{'items': values},
    };
    final configuration = TouchConfiguration(
      id: 'one',
      name: 'One',
      profile: const TouchProfile.empty(),
      data: input,
    );
    values.add('second');
    input.clear();
    expect((configuration.data['nested'] as Map)['items'], ['first']);
    expect(() => configuration.data.clear(), throwsUnsupportedError);
    expect(
      () =>
          ((configuration.data['nested'] as Map)['items'] as List).add('third'),
      throwsUnsupportedError,
    );
  });

  test('legacy configuration keys migrate to async preferences', () async {
    final legacy = TouchConfiguration(
      id: 'old',
      name: 'Old',
      profile: const TouchProfile.empty(),
    );
    SharedPreferences.setMockInitialValues({
      'genui_touch.remote.v1.old': jsonEncode(legacy.toJson()),
    });
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    const store = SharedPreferencesTouchRemoteStore();

    expect((await store.load('old'))?.name, 'Old');
    expect((await store.list()).single.id, 'old');
    await store.delete('old');
    expect(await store.load('old'), isNull);
  });

  test('save keeps newer edits unsaved while writing its snapshot', () async {
    final contract = TouchContract(
      catalogId: 'catalog',
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
    final storage = _PendingStorage();
    final touch = GenUiTouchController(contracts: [contract], storage: storage);
    addTearDown(touch.dispose);
    touch.setGalleryDefault(contract, 'variant', 'body');
    final save = touch.save();
    touch.setGalleryDefault(contract, 'variant', 'caption');
    storage.pending.complete();
    await save;

    expect(storage.saved?.defaults['catalog\u0000Text']?['variant'], 'body');
    expect(touch.profile.defaults['catalog\u0000Text']?['variant'], 'caption');
    expect(touch.hasUnsavedProfileChanges, isTrue);
  });

  test(
    'completed save cannot mark a different configuration as saved',
    () async {
      final contract = TouchContract(
        catalogId: 'catalog',
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
      final touch = GenUiTouchController(contracts: [contract]);
      addTearDown(touch.dispose);
      final pending = Completer<void>();
      touch.useConfigurations(
        remote: TouchProfile(),
        local: TouchProfile(),
        editRemote: false,
        saveEditedProfile: (_) => pending.future,
      );
      touch.setGalleryDefault(contract, 'variant', 'caption');
      final save = touch.save();

      touch.useConfigurations(
        remote: TouchProfile(),
        local: TouchProfile(),
        editRemote: false,
        saveEditedProfile: (_) async {},
      );
      touch.setGalleryDefault(contract, 'variant', 'body');
      pending.complete();
      await save;

      expect(touch.hasUnsavedProfileChanges, isTrue);
      expect(touch.profile.defaults['catalog\u0000Text']?['variant'], 'body');
    },
  );

  test('remote and local records round-trip independently', () async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    const remoteStore = SharedPreferencesTouchRemoteStore();
    const localStore = SharedPreferencesTouchLocalStore();
    final remote = TouchConfiguration(
      id: 'christmas',
      name: 'Christmas',
      profile: TouchProfile(
        defaults: {
          'catalog\u0000Text': {'variant': 'caption'},
        },
      ),
      data: {
        'occasion': 'christmas',
        'style': {'headline': 'The holiday edit'},
        'layout': 'holiday-groups',
      },
    );
    final local = TouchConfiguration(
      id: 'preferences',
      name: 'Emily preferences',
      userId: 'emily',
      profile: TouchProfile(),
    );
    await remoteStore.save(remote);
    await localStore.save('emily', local);
    expect((await remoteStore.load('christmas'))?.data, remote.data);
    expect((await remoteStore.list()).single.id, 'christmas');
    expect((await localStore.list('emily')).single.userId, 'emily');
    expect(await localStore.list('fred'), isEmpty);
    await expectLater(localStore.save('fred', local), throwsArgumentError);
    await remoteStore.delete('christmas');
    expect(await remoteStore.load('christmas'), isNull);
    expect((await localStore.load('emily', 'preferences'))?.id, 'preferences');
  });

  test('edits save only their layer and local wins on render', () async {
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
    final key = '${BasicCatalog.v1_0Id}\u0000Text';
    final remote = TouchProfile(
      defaults: {
        key: {'variant': 'caption'},
      },
    );
    final local = TouchProfile(
      defaults: {
        key: {'variant': 'body'},
      },
    );
    final touch = GenUiTouchController(contracts: [contract]);
    final processor = MessageProcessor<ComponentImplementation>(
      catalogs: [basicCatalog()],
    );
    touch.attachProcessor(processor);
    addTearDown(touch.dispose);
    addTearDown(processor.dispose);
    TouchProfile? saved;
    touch.useConfigurations(
      remote: remote,
      local: local,
      editRemote: false,
      saveEditedProfile: (profile) async => saved = profile,
    );
    touch.processAgentMessages([
      {
        'version': '1.0',
        'createSurface': {'surfaceId': 'one', 'catalogId': BasicCatalog.v1_0Id},
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
    expect(
      processor.model
          .getSurface('one')
          ?.componentsModel
          .get('root')
          ?.toJson()['variant'],
      'body',
    );
    touch.setGalleryDefault(contract, 'variant', 'caption');
    await touch.save();
    expect(saved?.defaults[key]?['variant'], 'caption');
    expect(remote.defaults[key]?['variant'], 'caption');
    expect(local.defaults[key]?['variant'], 'body');
  });
}
