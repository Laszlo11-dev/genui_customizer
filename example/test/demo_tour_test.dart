import 'package:a2ui_tech_reader/demo/demo_feed.dart';
import 'package:a2ui_tech_reader/demo/demo_tour.dart';
import 'package:a2ui_tech_reader/main.dart';
import 'package:a2ui_tech_reader/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  test(
    'intro has sixty seconds and changes the button after showing Emily',
    () {
      expect(
        introScript.fold<int>(
          0,
          (sum, scene) => sum + scene.duration.inSeconds,
        ),
        60,
      );
      final actions = [
        for (final scene in introScript)
          for (final cue in scene.cues) cue.action,
      ];
      expect(actions, [
        DemoAction.showChristmas,
        DemoAction.showWinterGames,
        DemoAction.showJoe,
        DemoAction.showEmily,
        DemoAction.openStoryStudio,
        DemoAction.makeButtonPink,
        DemoAction.closeStudio,
      ]);
    },
  );

  test(
    'manual advance executes pending cues and stop restores the host',
    () async {
      final actions = <DemoAction>[];
      var starts = 0;
      var stops = 0;
      final tour = DemoTourController(
        scenes: introScript,
        onStart: () async => starts++,
        onAction: (action) async => actions.add(action),
        onStop: () async => stops++,
      );
      addTearDown(tour.dispose);

      await tour.start();
      tour.pause();
      expect(starts, 1);
      await tour.next();
      expect(actions, [DemoAction.showChristmas]);
      await tour.next();
      expect(actions.last, DemoAction.showJoe);
      await tour.next();
      expect(actions.last, DemoAction.openStoryStudio);
      await tour.next();
      expect(actions, [
        DemoAction.showChristmas,
        DemoAction.showWinterGames,
        DemoAction.showJoe,
        DemoAction.showEmily,
        DemoAction.openStoryStudio,
        DemoAction.makeButtonPink,
        DemoAction.closeStudio,
      ]);
      await tour.next();
      expect(tour.ended, isTrue);
      await tour.replay();
      expect(starts, 2);
      expect(stops, 1);
      expect(tour.sceneIndex, 0);
      await tour.stop();
      expect(stops, 2);
      expect(tour.active, isFalse);
    },
  );

  test(
    'curated RSS snapshot features current A2UI, Flutter, and Touch links',
    () {
      final stories = demoRssStories();
      expect(stories.length, 5);
      expect(stories.every((story) => story.link.scheme == 'https'), isTrue);
      expect(stories.where((story) => story.imageUrl != null).length, 3);
      expect(stories.first.source, 'Google Developers Blog');
      expect(stories.any((story) => story.link.host == 'pub.dev'), isTrue);
      expect(
        stories.any((story) => story.title.contains('Flutter 3.50')),
        isTrue,
      );
      expect(stories.last.source, 'GenUI Touch');
      expect(stories.last.link.host, 'github.com');
      expect(
        stories
            .where((story) => story.published != null)
            .every((story) => story.published!.year >= 2026),
        isTrue,
      );
    },
  );

  testWidgets('curated demo feed can be selected outside the tour', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TechReaderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('feed-settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(demoFeedPreset.name).last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Curated A2UI, Flutter, and Touch'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'The links open the original articles and package pages.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Close RSS controls'));
    await tester.pumpAndSettle();
    expect(find.textContaining(demoRssStories().first.title), findsWidgets);
    expect(find.text('1-min demo'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('intro presents curated RSS and Christmas edition', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TechReaderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('1-min demo'));
    await tester.pump();
    expect(find.textContaining('Curated RSS'), findsWidgets);
    expect(find.textContaining('Stories from RSS'), findsOneWidget);
    await tester.tap(find.byTooltip('Next scene'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('Christmas to Winter Games'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButtonFormField<Occasion>>(
            find.byType(DropdownButtonFormField<Occasion>),
          )
          .initialValue,
      Occasion.christmas,
    );
    await tester.tap(find.byTooltip('Close demo'));
    await tester.pump();
    expect(find.text('1-min demo'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tour opens a compact Studio and clicks the pink swatch', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Uri? openedArticle;
    await tester.pumpWidget(
      TechReaderApp(
        openArticle: (url) async {
          openedArticle = url;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('1-min demo'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Read original').first);
    await tester.pump();
    expect(openedArticle, demoRssStories().first.link);
    await tester.tap(find.byTooltip('Pause demo'));
    await tester.pump();

    Future<void> advance() async {
      await tester.tap(find.byTooltip('Next scene'));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await advance(); // Christmas
    expect(
      tester
          .widget<DropdownButtonFormField<Occasion>>(
            find.byType(DropdownButtonFormField<Occasion>),
          )
          .initialValue,
      Occasion.christmas,
    );
    await advance(); // Winter Games and Joe
    expect(
      tester
          .widget<DropdownButtonFormField<Occasion>>(
            find.byType(DropdownButtonFormField<Occasion>),
          )
          .initialValue,
      Occasion.winter,
    );
    await advance(); // Emily, then Touch Studio
    final studio = find.byKey(const Key('genui-touch-studio-dialog'));
    expect(studio, findsOneWidget);
    expect(tester.getSize(studio).width, lessThanOrEqualTo(560));
    expect(tester.getTopLeft(studio).dx, greaterThan(900));
    expect(
      find.byKey(const Key('touch-color-field-buttonColor')),
      findsOneWidget,
    );
    final beforeButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Read original').first,
    );
    expect(
      beforeButton.style?.backgroundColor?.resolve({}),
      isNot(const Color(0xFFDB2777)),
    );

    await tester.tap(find.byTooltip('Play demo'));
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byTooltip('Pause demo'));
    await tester.pump();
    // The timed cue opens the real picker and selects Emily's Raspberry swatch.
    final preview = tester.widget<Container>(
      find.byKey(const Key('touch-color-preview-buttonColor')),
    );
    expect(
      (preview.decoration! as BoxDecoration).color,
      const Color(0xFFDB2777),
    );
    final readButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Read original').first,
    );
    expect(
      readButton.style?.backgroundColor?.resolve({}),
      const Color(0xFFDB2777),
    );
    final linkIcon = find.descendant(
      of: find.widgetWithText(FilledButton, 'Read original').first,
      matching: find.byIcon(Icons.open_in_new),
    );
    expect(linkIcon, findsOneWidget);
    expect(IconTheme.of(tester.element(linkIcon)).color, Colors.white);
    expect(tester.takeException(), isNull);
    await advance(); // Close Studio and show final frame.
    await advance(); // Finish the script.
    expect(find.text('Replay'), findsOneWidget);
    await tester.tap(find.text('Replay'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('Stories from RSS'), findsOneWidget);
    await tester.tap(find.byTooltip('Close demo'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
