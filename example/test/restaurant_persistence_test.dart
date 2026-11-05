import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_customizer_example/src/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('a Studio style edit survives a new search and restart', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const RestaurantFinderApp());
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customize results'));
    await tester.pumpAndSettle();

    for (final id in ['item-list', 'item-card-template', 'card-layout']) {
      final toggle = find.byKey(Key('genui-tree-toggle-$id'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
    }
    final imageNode = find.byKey(const Key('genui-tree-node-card-image'));
    await tester.ensureVisible(imageNode);
    await tester.tap(imageNode);
    await tester.pumpAndSettle();
    final variant = find.byKey(const ValueKey('editable-property-variant'));
    expect(variant, findsOneWidget);
    await tester.tap(variant);
    await tester.pumpAndSettle();
    await tester.tap(find.text('smallFeature').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final raw = await SharedPreferencesAsync().getString(
      'restaurant_finder_appearance_v1',
    );
    expect(raw, isNotNull);
    expect(jsonDecode(raw!)['rules'], isNotEmpty);

    await tester.tap(find.byTooltip('Close editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(find.text('River Table'), findsWidgets);
    await tester.tap(find.text('Customize results'));
    await tester.pumpAndSettle();
    for (final id in [
      'restaurant-list',
      'row-template',
      'card-template-left',
      'card-layout-left',
    ]) {
      final toggle = find.byKey(Key('genui-tree-toggle-$id'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
    }
    final nextImage = find.byKey(
      const Key('genui-tree-node-template-image-left'),
    );
    await tester.ensureVisible(nextImage);
    await tester.tap(nextImage);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('editable-property-variant')),
          )
          .initialValue,
      'smallFeature',
    );
    await tester.tap(find.byTooltip('Close editor'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const RestaurantFinderApp());
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customize results'));
    await tester.pumpAndSettle();
    for (final id in ['item-list', 'item-card-template', 'card-layout']) {
      final toggle = find.byKey(Key('genui-tree-toggle-$id'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(imageNode);
    await tester.tap(imageNode);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('editable-property-variant')),
          )
          .initialValue,
      'smallFeature',
    );
  });
}
