import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_customizer_example/src/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('Gallery style defaults survive restart and style new widgets', (
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
    await tester.tap(find.byKey(const Key('genui-studio-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<String>, 'Gallery view'),
    );
    await tester.pumpAndSettle();
    final textType = find.descendant(
      of: find.byKey(const Key('genui-gallery')),
      matching: find.text('Text'),
    );
    await tester.scrollUntilVisible(
      textType,
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('genui-gallery')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(textType);
    await tester.pumpAndSettle();
    final variant = find.byKey(const ValueKey('editable-property-variant'));
    await tester.tap(variant);
    await tester.pumpAndSettle();
    await tester.tap(find.text('caption').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('genui-save-defaults')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close editor'));
    await tester.pumpAndSettle();

    final raw = await SharedPreferencesAsync().getString(
      'restaurant_finder_gallery_defaults_v1',
    );
    expect(jsonDecode(raw!)['Text']['variant'], 'caption');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const RestaurantFinderApp());
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customize results'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('genui-tree-node-title-heading')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('editable-property-variant')),
          )
          .initialValue,
      'caption',
    );
  });
}
