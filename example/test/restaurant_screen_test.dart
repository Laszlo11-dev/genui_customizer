import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_customizer_example/src/main.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets(
    'recorded searches show new content and open the runtime Studio',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const RestaurantFinderApp());
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(find.text('The Fancy Place'), findsWidgets);

      await tester.tap(find.text('Customize results'));
      await tester.pumpAndSettle();
      expect(find.textContaining('GenUI Studio'), findsWidgets);
      await tester.tap(find.byKey(const Key('genui-studio-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GenUI debug'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Find me 3 Chinese restaurants'),
        findsWidgets,
      );
      await tester.tap(find.text('Response'));
      await tester.pumpAndSettle();
      expect(find.textContaining('updateComponents'), findsWidgets);
      await tester.tap(find.byTooltip('Close debug'));
      await tester.pumpAndSettle();
      final studio = find.byKey(const Key('editable-genui-studio-dialog'));
      final initialBounds = tester.getRect(studio);
      await tester.drag(
        find.byKey(const Key('genui-studio-resize')),
        const Offset(-350, -150),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('genui-studio-drag')),
        const Offset(65, 25),
      );
      await tester.pumpAndSettle();
      final savedBounds = tester.getRect(studio);
      expect(savedBounds.width, lessThan(initialBounds.width));
      expect(savedBounds.left, greaterThan(initialBounds.left));

      await tester.tap(find.byTooltip('Close editor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Customize results'));
      await tester.pumpAndSettle();
      expect(tester.getRect(studio), savedBounds);
      await tester.tap(find.byTooltip('Close editor'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      expect(find.text('River Table'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(const RestaurantFinderApp());
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Customize results'));
      await tester.pumpAndSettle();
      expect(tester.getRect(studio), savedBounds);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
