import 'package:a2ui_tech_reader/a2ui_builder.dart';
import 'package:a2ui_tech_reader/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final items = List.generate(4, (i) => NewsItem(
    title: 'Story $i',
    link: Uri.parse('https://example.com/$i'),
    source: 'test',
  ));

  test('generates A2UI 1.0 surface and updates', () {
    final messages = NewsA2uiBuilder.build(items, Occasion.everyday);
    expect(messages.first['version'], '1.0');
    expect(messages.first.containsKey('createSurface'), true);
    expect(messages.last.containsKey('updateComponents'), true);
    final updated = messages.last['updateComponents']! as Map<String, Object?>;
    final components = updated['components']! as List<Map<String, Object?>>;
    expect(components.any((c) => c['component'] == 'Card'), true);
    expect(components.any((c) => c['component'] == 'Button'), true);
  });

  test('occasion switches the A2UI component tree', () {
    final everyday = NewsA2uiBuilder.build(items, Occasion.everyday);
    final christmas = NewsA2uiBuilder.build(items, Occasion.christmas);
    expect(everyday.toString(), isNot(christmas.toString()));
  });
}
