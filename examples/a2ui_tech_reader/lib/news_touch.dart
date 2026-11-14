import 'dart:convert';

import 'package:genui_customizer/genui_customizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'news_gallery.dart';

/// Initial demo preferences. These records are created once per installation;
/// subsequent Studio saves belong to the selected user.
List<TouchConfiguration> demoLocalConfigurations() {
  final page = '$newsGalleryCatalogId\u0000NewsPage';
  final section = '$newsGalleryCatalogId\u0000NewsSection';
  final story = '$newsGalleryCatalogId\u0000NewsStory';
  final grid = '$newsGalleryCatalogId\u0000NewsGrid';
  return [
    TouchConfiguration(
      id: 'preferences',
      name: 'Joe preferences',
      userId: 'joe',
      profile: TouchProfile(
        defaults: {
          page: {'backgroundColor': '#FFFFFF'},
          section: {
            'backgroundColor': '#FFFFFF',
            'textColor': '#111827',
            'accentColor': '#1D4ED8',
            'titleSize': 36,
          },
          story: {
            'backgroundColor': '#FFFFFF',
            'textColor': '#111827',
            'mutedColor': '#374151',
            'accentColor': '#1D4ED8',
            'borderColor': '#111827',
            'titleSize': 30,
            'titleWeight': 'bold',
            'summarySize': 20,
            'buttonStyle': 'filled',
          },
          grid: {'columns': 1, 'gap': 24},
        },
      ),
      data: const {
        'description': 'Larger text and stronger contrast',
        'demoSeedVersion': 2,
      },
    ),
    TouchConfiguration(
      id: 'preferences',
      name: 'Fred preferences',
      userId: 'fred',
      profile: const TouchProfile(),
      data: const {
        'description': 'Keep the received occasion appearance',
        'demoSeedVersion': 2,
      },
    ),
    TouchConfiguration(
      id: 'preferences',
      name: 'Emily preferences',
      userId: 'emily',
      profile: TouchProfile(
        defaults: {
          page: {'backgroundColor': '#FFF1F2'},
          section: {
            'backgroundColor': '#FCE7F3',
            'textColor': '#831843',
            'accentColor': '#DB2777',
          },
          story: {
            'backgroundColor': '#FFF1F2',
            'textColor': '#831843',
            'mutedColor': '#9D174D',
            'accentColor': '#DB2777',
            'borderColor': '#F9A8D4',
            'buttonStyle': 'filled',
          },
        },
      ),
      data: const {'description': 'Pink appearance', 'demoSeedVersion': 2},
    ),
  ];
}

Future<void> seedDemoLocalConfigurations(
  TouchLocalConfigurationStore store,
) async {
  for (final configuration in demoLocalConfigurations()) {
    final userId = configuration.userId!;
    final existing = await store.load(userId, configuration.id);
    if (existing == null) {
      await store.save(userId, configuration);
    } else if (existing.data['description'] ==
            configuration.data['description'] &&
        existing.data['demoSeedVersion'] != 2) {
      final pageKey = '$newsGalleryCatalogId\u0000NewsPage';
      final pageDefault = configuration.profile.defaults[pageKey];
      final defaults = {
        for (final entry in existing.profile.defaults.entries)
          entry.key: Map<String, Object?>.from(entry.value),
        if (pageDefault != null &&
            !existing.profile.defaults.containsKey(pageKey))
          pageKey: Map<String, Object?>.from(pageDefault),
      };
      await store.save(
        userId,
        existing.copyWith(
          profile: TouchProfile(
            defaults: defaults,
            roles: existing.profile.roles,
          ),
          data: {...existing.data, 'demoSeedVersion': 2},
        ),
      );
    }
  }
}

/// This reader has no accounts: preferences belong to this app installation.
final class ReaderTouchStorage implements TouchStorage {
  const ReaderTouchStorage();

  static const _key = 'a2ui_tech_reader.touch_profile.v2';

  @override
  Future<TouchProfile?> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return null;
    final saved = TouchProfile.fromJson(
      (jsonDecode(raw) as Map).cast<String, Object?>(),
    );
    // Older reader profiles may contain item-role overrides. The reader now
    // edits catalog types only, so keep its type defaults and drop those roles.
    return TouchProfile(defaults: saved.defaults);
  }

  @override
  Future<void> save(TouchProfile profile) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(profile.toJson()),
    );
    if (!saved) throw StateError('Could not save the Touch profile.');
  }
}

List<TouchContract> readerTouchContracts() => [
  TouchContract(
    catalogId: newsGalleryCatalogId,
    componentType: 'NewsPage',
    properties: const [
      TouchProperty(
        name: 'backgroundColor',
        label: 'Whole page background',
        kind: TouchValueKind.color,
      ),
    ],
  ),
  TouchContract(
    catalogId: newsGalleryCatalogId,
    componentType: 'NewsSection',
    properties: const [
      TouchProperty(
        name: 'backgroundColor',
        label: 'Background color',
        kind: TouchValueKind.color,
      ),
      TouchProperty(
        name: 'textColor',
        label: 'Text color',
        kind: TouchValueKind.color,
      ),
      TouchProperty(
        name: 'accentColor',
        label: 'Accent color',
        kind: TouchValueKind.color,
      ),
      TouchProperty(
        name: 'titleSize',
        label: 'Heading size',
        kind: TouchValueKind.number,
      ),
      TouchProperty(
        name: 'padding',
        label: 'Padding',
        kind: TouchValueKind.number,
      ),
      TouchProperty(
        name: 'cornerRadius',
        label: 'Corner radius',
        kind: TouchValueKind.number,
      ),
      TouchProperty(
        name: 'showRule',
        label: 'Show rule',
        kind: TouchValueKind.boolean,
      ),
    ],
  ),
  TouchContract(
    catalogId: newsGalleryCatalogId,
    componentType: 'NewsStory',
    properties: const [
      TouchProperty(
        name: 'backgroundColor',
        label: 'Background color',
        kind: TouchValueKind.color,
      ),
      TouchProperty(
        name: 'textColor',
        label: 'Text color',
        kind: TouchValueKind.color,
      ),
      TouchProperty(
        name: 'mutedColor',
        label: 'Secondary text color',
        kind: TouchValueKind.color,
      ),
      TouchProperty(
        name: 'accentColor',
        label: 'Accent color',
        kind: TouchValueKind.color,
      ),
      TouchProperty(
        name: 'buttonColor',
        label: 'Read original button color',
        kind: TouchValueKind.color,
      ),
      TouchProperty(
        name: 'borderColor',
        label: 'Border color',
        kind: TouchValueKind.color,
      ),
      TouchProperty(
        name: 'cornerRadius',
        label: 'Corner radius',
        kind: TouchValueKind.number,
      ),
      TouchProperty(
        name: 'padding',
        label: 'Padding',
        kind: TouchValueKind.number,
      ),
      TouchProperty(
        name: 'imageHeight',
        label: 'Image height',
        kind: TouchValueKind.number,
      ),
      TouchProperty(
        name: 'imagePosition',
        label: 'Image position',
        kind: TouchValueKind.choice,
        choices: ['top', 'left', 'none'],
      ),
      TouchProperty(
        name: 'imageFit',
        label: 'Image fit',
        kind: TouchValueKind.choice,
        choices: ['cover', 'contain'],
      ),
      TouchProperty(
        name: 'titleSize',
        label: 'Title size',
        kind: TouchValueKind.number,
      ),
      TouchProperty(
        name: 'titleWeight',
        label: 'Title weight',
        kind: TouchValueKind.choice,
        choices: ['regular', 'medium', 'bold'],
      ),
      TouchProperty(
        name: 'summarySize',
        label: 'Summary size',
        kind: TouchValueKind.number,
      ),
      TouchProperty(
        name: 'showSummary',
        label: 'Show summary',
        kind: TouchValueKind.boolean,
      ),
      TouchProperty(
        name: 'showDate',
        label: 'Show date',
        kind: TouchValueKind.boolean,
      ),
      TouchProperty(
        name: 'buttonStyle',
        label: 'Button style',
        kind: TouchValueKind.choice,
        choices: ['outline', 'filled', 'text'],
      ),
      TouchProperty(
        name: 'elevation',
        label: 'Elevation',
        kind: TouchValueKind.number,
      ),
    ],
  ),
  TouchContract(
    catalogId: newsGalleryCatalogId,
    componentType: 'NewsGrid',
    properties: const [
      TouchProperty(
        name: 'columns',
        label: 'Columns',
        kind: TouchValueKind.number,
      ),
      TouchProperty(name: 'gap', label: 'Gap', kind: TouchValueKind.number),
    ],
  ),
];
