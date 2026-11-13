import 'dart:convert';

import 'package:genui_customizer/genui_customizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'news_gallery.dart';

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
