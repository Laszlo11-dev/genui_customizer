import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/basic_catalog.dart';
import 'package:a2ui_tech_reader/a2ui_builder.dart';
import 'package:a2ui_tech_reader/main.dart';
import 'package:a2ui_tech_reader/models.dart';
import 'package:a2ui_tech_reader/news_gallery.dart';
import 'package:a2ui_tech_reader/news_touch.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_customizer/genui_customizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryStorage implements TouchStorage {
  TouchProfile? profile;

  @override
  Future<TouchProfile?> load() async => profile;

  @override
  Future<void> save(TouchProfile value) async => profile = value;
}

void main() {
  testWidgets('narrow editor opens component types in a drawer', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(650, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TechReaderApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open GenUI Touch'));
    await tester.pumpAndSettle();

    expect(find.text('Component types'), findsNothing);
    expect(
      find.text('Appearance for all NewsSection components'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('genui-studio-open-components')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('genui-studio-open-components')));
    await tester.pumpAndSettle();
    expect(find.text('NewsStory'), findsOneWidget);

    await tester.tap(find.text('NewsStory'));
    await tester.pumpAndSettle();
    expect(
      find.text('Appearance for all NewsStory components'),
      findsOneWidget,
    );
    expect(find.text('Component types'), findsNothing);
  });

  testWidgets('triple-click opens the reader type editor', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TechReaderApp());
    await tester.pumpAndSettle();
    final surface = tester
        .widget<A2uiSurface>(find.byType(A2uiSurface))
        .surface;
    final title = surface.componentsModel
        .get('status_title')
        ?.toJson()['title'];
    expect(title, isA<String>());
    for (var i = 0; i < 3; i++) {
      await tester.tap(
        find.text(title! as String),
        kind: PointerDeviceKind.mouse,
      );
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('genui-touch-studio-dialog')), findsOneWidget);
    expect(
      find.text('Appearance for all NewsSection components'),
      findsOneWidget,
    );
    expect(find.text('Surface'), findsNothing);
  });

  testWidgets('triple-click on a nested story selects NewsStory', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final touch = GenUiTouchController(
      contracts: readerTouchContracts(),
      showSelectionOutline: false,
    );
    var studioRequests = 0;
    touch.onStudioRequested = () => studioRequests++;
    final processor = MessageProcessor<ComponentImplementation>(
      catalogs: [basicCatalog(), touch.decorateCatalog(newsGalleryCatalog)],
    );
    touch.attachProcessor(processor);
    addTearDown(() {
      touch.dispose();
      processor.dispose();
    });
    touch.processAgentMessages(
      NewsA2uiBuilder.build([
        for (var i = 0; i < 2; i++)
          NewsItem(
            title: 'Story $i',
            link: Uri.parse('https://example.org/$i'),
            source: 'Example',
          ),
      ], Occasion.everyday),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: A2uiSurface(
              surface: processor.model.getSurface(NewsA2uiBuilder.surfaceId)!,
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Story 1'));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Story 1'), kind: PointerDeviceKind.mouse);
    }
    await tester.pump();
    expect(studioRequests, 1);
    expect(touch.selection?.componentType, 'NewsStory');
    await tester.pumpWidget(
      MaterialApp(
        home: GenUiTouchStudio(
          controller: touch,
          surfaceId: NewsA2uiBuilder.surfaceId,
          galleryOnly: true,
        ),
      ),
    );
    expect(
      find.text('Appearance for all NewsStory components'),
      findsOneWidget,
    );
  });

  testWidgets('reader edits types and saves a current section default', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TechReaderApp());
    await tester.pump();
    await tester.tap(find.byTooltip('Open GenUI Touch'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('genui-touch-studio-dialog')), findsOneWidget);
    expect(find.text('Component types'), findsOneWidget);
    expect(find.text('NewsSection'), findsOneWidget);
    expect(find.text('NewsStory'), findsOneWidget);
    expect(find.text('NewsGrid'), findsOneWidget);
    expect(find.text('Surface'), findsNothing);
    expect(find.text('Gallery'), findsNothing);
    final save = find.widgetWithIcon(IconButton, Icons.save_outlined);
    expect(tester.widget<IconButton>(save).onPressed, isNull);

    await tester.tap(
      find.byKey(const Key('touch-color-field-backgroundColor')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'touch-color-choice-',
            ),
      ),
      findsNWidgets(16),
    );
    await tester.tap(find.byKey(const Key('touch-color-choice-indigo')));
    await tester.pumpAndSettle();

    final surface = tester
        .widget<A2uiSurface>(find.byType(A2uiSurface))
        .surface;
    expect(
      surface.componentsModel.get('status_title')?.toJson()['backgroundColor'],
      '#4F46E5',
    );
    expect(tester.widget<IconButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Appearance saved'), findsWidgets);
    expect(tester.widget<IconButton>(save).onPressed, isNull);
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getKeys().singleWhere(
      (key) => key.contains('touch_profile'),
    );
    final profile = TouchProfile.fromJson(
      (jsonDecode(prefs.getString(key)!) as Map).cast<String, Object?>(),
    );
    expect(
      profile
          .defaults['$newsGalleryCatalogId\u0000NewsSection']?['backgroundColor'],
      '#4F46E5',
    );
    await tester.tap(
      find.byKey(const Key('touch-color-field-backgroundColor')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('touch-color-choice-teal')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<A2uiSurface>(find.byType(A2uiSurface))
          .surface
          .componentsModel
          .get('status_title')
          ?.toJson()['backgroundColor'],
      '#0F766E',
    );
    await tester.tap(find.text('Discard unsaved defaults'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<A2uiSurface>(find.byType(A2uiSurface))
          .surface
          .componentsModel
          .get('status_title')
          ?.toJson()['backgroundColor'],
      '#4F46E5',
    );
    expect(tester.widget<IconButton>(save).onPressed, isNull);

    await tester.tap(
      find.byKey(const Key('touch-color-field-backgroundColor')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use original'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<A2uiSurface>(find.byType(A2uiSurface))
          .surface
          .componentsModel
          .get('status_title')
          ?.toJson()['backgroundColor'],
      isNot('#4F46E5'),
    );
    expect(tester.widget<IconButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final resetProfile = TouchProfile.fromJson(
      (jsonDecode(prefs.getString(key)!) as Map).cast<String, Object?>(),
    );
    expect(
      resetProfile
          .defaults['$newsGalleryCatalogId\u0000NewsSection']?['backgroundColor'],
      isNull,
    );
  });

  test('one default applies to every component of its catalog type', () async {
    final storage = _MemoryStorage();
    final touch = GenUiTouchController(
      contracts: readerTouchContracts(),
      storage: storage,
    );
    final processor = MessageProcessor<ComponentImplementation>(
      catalogs: [basicCatalog(), newsGalleryCatalog],
    );
    touch.attachProcessor(processor);
    addTearDown(() {
      touch.dispose();
      processor.dispose();
    });
    final articles = [
      for (var i = 0; i < 4; i++)
        NewsItem(
          title: 'Story $i',
          link: Uri.parse('https://example.org/$i'),
          source: 'Example',
        ),
    ];
    touch.processAgentMessages(
      NewsA2uiBuilder.build(articles, Occasion.everyday),
    );
    final contracts = readerTouchContracts();
    touch.setGalleryDefault(contracts[0], 'titleSize', 36);
    touch.setGalleryDefault(contracts[1], 'buttonStyle', 'text');
    touch.setGalleryDefault(contracts[2], 'gap', 24);
    touch.processAgentMessages({
      'version': '1.0',
      'deleteSurface': {'surfaceId': NewsA2uiBuilder.surfaceId},
    });
    touch.processAgentMessages(
      NewsA2uiBuilder.build(articles, Occasion.everyday),
    );
    final components = processor.model
        .getSurface(NewsA2uiBuilder.surfaceId)!
        .componentsModel
        .all
        .toList();
    final sections = components.where(
      (component) => component.type == 'NewsSection',
    );
    final stories = components.where(
      (component) => component.type == 'NewsStory',
    );
    final grids = components.where((component) => component.type == 'NewsGrid');
    expect(sections.length, greaterThan(1));
    expect(stories.length, greaterThan(1));
    expect(grids, isNotEmpty);
    expect(
      sections.every((component) => component.toJson()['titleSize'] == 36),
      isTrue,
    );
    expect(
      stories.every((component) => component.toJson()['buttonStyle'] == 'text'),
      isTrue,
    );
    expect(grids.every((component) => component.toJson()['gap'] == 24), isTrue);
    await touch.save();
    expect(storage.profile?.defaults.length, 3);
  });

  test('original appearance can be restored by property or type', () {
    final touch = GenUiTouchController(contracts: readerTouchContracts());
    addTearDown(touch.dispose);
    final section = readerTouchContracts().first;
    final story = readerTouchContracts()[1];
    final sectionKey = '$newsGalleryCatalogId\u0000NewsSection';
    final storyKey = '$newsGalleryCatalogId\u0000NewsStory';
    touch.setGalleryDefault(section, 'textColor', '#0F766E');
    touch.setGalleryDefault(section, 'titleSize', 36);
    touch.setGalleryDefault(story, 'textColor', '#202735');

    touch.removeGalleryDefault(section, 'textColor');
    expect(touch.profile.defaults[sectionKey], {'titleSize': 36});
    expect(touch.profile.defaults[storyKey], {'textColor': '#202735'});

    touch.clearGalleryDefaults(section);
    expect(touch.profile.defaults.containsKey(sectionKey), isFalse);
    expect(touch.profile.defaults[storyKey], {'textColor': '#202735'});
  });

  test('reader keeps old type defaults and ignores old item roles', () async {
    final old = TouchProfile(
      defaults: {
        '$newsGalleryCatalogId\u0000NewsStory': {'buttonStyle': 'text'},
      },
      roles: {
        '$newsGalleryCatalogId\u0000NewsSection\u0000lead': {'titleSize': 40},
      },
    );
    SharedPreferences.setMockInitialValues({
      'a2ui_tech_reader.touch_profile.v2': jsonEncode(old.toJson()),
    });
    final loaded = await const ReaderTouchStorage().load();
    expect(loaded?.defaults, old.defaults);
    expect(loaded?.roles, isEmpty);
  });
}
