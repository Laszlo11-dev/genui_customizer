import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui_customizer/genui_customizer.dart';
import 'package:genui_customizer_example/src/session.dart';

void main() {
  test(
    'official Restaurant Finder responses retain new content and appearance',
    () {
      final first =
          (jsonDecode(File('assets/first_search.json').readAsStringSync())
                  as List)
              .map((value) => Map<String, Object?>.from(value as Map))
              .toList();
      final edited = (jsonDecode(jsonEncode(first)) as List)
          .map((value) => Map<String, Object?>.from(value as Map))
          .toList();
      final components =
          (edited[1]['updateComponents'] as Map)['components'] as List;
      final image = components.cast<Map>().firstWhere(
        (component) => component['id'] == 'card-image',
      );
      image['variant'] = 'smallFeature';

      final profile = GenUiAppearanceProfile.capture(
        before: GenUiEditSnapshot(revision: 1, messages: first),
        after: GenUiEditSnapshot(revision: 2, messages: edited),
        registry: RestaurantSession.editableRegistry,
        roleFor: RestaurantSession.componentRole,
      );
      final next =
          (jsonDecode(File('assets/next_search.json').readAsStringSync())
                  as List)
              .map((value) => Map<String, Object?>.from(value as Map))
              .toList();
      final applied = [
        for (final message in next)
          profile.applyToMessage(
            message: message,
            registry: RestaurantSession.editableRegistry,
            roleFor: RestaurantSession.componentRole,
          ),
      ];
      final resultComponents =
          (applied[1]['updateComponents'] as Map)['components'] as List;
      final images = resultComponents.cast<Map>().where(
        (component) => component['component'] == 'Image',
      );
      expect(images, hasLength(2));
      expect(
        images.every((image) => image['variant'] == 'smallFeature'),
        isTrue,
      );
      expect(jsonEncode(applied), contains('River Table'));
      expect(jsonEncode(applied), contains('Corner Kitchen'));
    },
  );
}
