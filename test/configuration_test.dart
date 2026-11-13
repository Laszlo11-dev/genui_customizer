import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/basic_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_customizer/genui_customizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('remote and local records round-trip independently', () async {
    SharedPreferences.setMockInitialValues({});
    const remoteStore = SharedPreferencesTouchRemoteStore();
    const localStore = SharedPreferencesTouchLocalStore();
    final remote = TouchConfiguration(
      id: 'christmas',
      name: 'Christmas',
      profile: const TouchProfile(
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
      profile: const TouchProfile(),
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
