import 'package:genui_customizer/genui_customizer.dart';
import 'package:test/test.dart';

void main() {
  final registry = EditableCatalogRegistry(
    catalogId: 'restaurant',
    catalogVersion: 1,
    components: [
      EditableComponentContract(
        type: 'Image',
        properties: const [
          EditablePropertyContract(
            name: 'variant',
            label: 'Image size',
            type: EditablePropertyType.enumeration,
            enumValues: ['smallFeature', 'mediumFeature'],
          ),
        ],
        protectedProperties: const {'url'},
      ),
    ],
  );

  String? roleFor(Map<String, Object?> component) {
    final url = component['url'];
    if (component['component'] == 'Image' &&
        url is Map &&
        (url['path'] as String?)?.endsWith('imageUrl') == true) {
      return 'restaurant-image';
    }
    return null;
  }

  Map<String, Object?> message(String id, String image, String variant) => {
    'version': 'v0.9',
    'updateComponents': {
      'surfaceId': 'main',
      'components': [
        {
          'id': id,
          'component': 'Image',
          'variant': variant,
          'url': {'path': image},
        },
      ],
    },
  };

  test('saved appearance carries to new content without changing bindings', () {
    final original = GenUiEditSnapshot(
      revision: 1,
      messages: [message('image-1', 'first/imageUrl', 'mediumFeature')],
    );
    final edited = GenUiEditSnapshot(
      revision: 2,
      messages: [message('image-1', 'first/imageUrl', 'smallFeature')],
    );
    final profile = GenUiAppearanceProfile.capture(
      before: original,
      after: edited,
      registry: registry,
      roleFor: roleFor,
    );
    final reloaded = GenUiAppearanceProfile.fromJson(profile.toJson());
    final incoming = message('another-image', 'next/imageUrl', 'mediumFeature');
    final applied = reloaded.applyToMessage(
      message: incoming,
      registry: registry,
      roleFor: roleFor,
    );
    final image =
        ((applied['updateComponents'] as Map)['components'] as List).single
            as Map;
    expect(image['variant'], 'smallFeature');
    expect(image['url'], {'path': 'next/imageUrl'});
    expect(
      ((incoming['updateComponents'] as Map)['components'] as List)
          .single['variant'],
      'mediumFeature',
    );
  });

  test('profile refuses a different catalog version', () {
    final profile = GenUiAppearanceProfile(
      catalogId: 'restaurant',
      catalogVersion: 2,
      rules: const [],
    );
    expect(
      () => profile.applyToMessage(
        message: message('image', 'imageUrl', 'mediumFeature'),
        registry: registry,
        roleFor: roleFor,
      ),
      throwsFormatException,
    );
  });
}
