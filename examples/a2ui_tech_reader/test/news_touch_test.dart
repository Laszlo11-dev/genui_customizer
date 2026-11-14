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
  testWidgets('invalid saved occasion data falls back to a working edition', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await const SharedPreferencesTouchRemoteStore().save(
      TouchConfiguration(
        id: Occasion.christmas.name,
        name: 'Christmas',
        profile: const TouchProfile(),
        data: const {
          'style': {'headline': 42},
          'palette': {'accent': 42},
          'composition': {'layout': 'unknown'},
        },
      ),
    );
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TechReaderApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<Occasion>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Christmas').last);
    await tester.pumpAndSettle();
    expect(find.text('The holiday edit'), findsOneWidget);
    expect(find.byType(A2uiSurface), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Touch demo controls fit a narrow screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TechReaderApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('corrupt saved configuration does not block occasion switching', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'genui_touch.remote.v1.christmas': '{broken json',
    });
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TechReaderApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<Occasion>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Christmas').last);
    await tester.pumpAndSettle();
    expect(find.text('The holiday edit'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'demo user configurations match their descriptions and seed once',
    () async {
      SharedPreferences.setMockInitialValues({});
      const store = SharedPreferencesTouchLocalStore();
      await seedDemoLocalConfigurations(store);
      final joe = await store.load('joe', 'preferences');
      final fred = await store.load('fred', 'preferences');
      final emily = await store.load('emily', 'preferences');
      final storyKey = '$newsGalleryCatalogId\u0000NewsStory';
      final gridKey = '$newsGalleryCatalogId\u0000NewsGrid';
      final pageKey = '$newsGalleryCatalogId\u0000NewsPage';
      expect(joe?.profile.defaults[pageKey]?['backgroundColor'], '#FFFFFF');
      expect(joe?.profile.defaults[storyKey]?['titleSize'], 30);
      expect(joe?.profile.defaults[storyKey]?['summarySize'], 20);
      expect(joe?.profile.defaults[gridKey]?['columns'], 1);
      expect(fred?.profile.defaults, isEmpty);
      expect(emily?.profile.defaults[storyKey]?['accentColor'], '#DB2777');
      expect(emily?.profile.defaults[pageKey]?['backgroundColor'], '#FFF1F2');
      for (final configuration in demoLocalConfigurations()) {
        for (final contract in readerTouchContracts()) {
          final key = '${contract.catalogId}\u0000${contract.componentType}';
          for (final entry
              in (configuration.profile.defaults[key] ?? {}).entries) {
            expect(
              contract.properties[entry.key]?.accepts(entry.value),
              isTrue,
            );
          }
        }
      }
      await store.save('joe', joe!.copyWith(profile: const TouchProfile()));
      await seedDemoLocalConfigurations(store);
      expect(
        (await store.load('joe', 'preferences'))?.profile.defaults,
        isEmpty,
      );
    },
  );

  test(
    'older demo preference gains page color without resetting edits',
    () async {
      SharedPreferences.setMockInitialValues({});
      const store = SharedPreferencesTouchLocalStore();
      final storyKey = '$newsGalleryCatalogId\u0000NewsStory';
      final pageKey = '$newsGalleryCatalogId\u0000NewsPage';
      await store.save(
        'joe',
        TouchConfiguration(
          id: 'preferences',
          name: 'Joe preferences',
          userId: 'joe',
          profile: TouchProfile(
            defaults: {
              storyKey: {'titleSize': 33},
            },
          ),
          data: const {'description': 'Larger text and stronger contrast'},
        ),
      );
      await seedDemoLocalConfigurations(store);
      final migrated = (await store.load('joe', 'preferences'))!;
      expect(migrated.profile.defaults[storyKey]?['titleSize'], 33);
      expect(migrated.profile.defaults[pageKey]?['backgroundColor'], '#FFFFFF');
      expect(migrated.data['demoSeedVersion'], 2);

      await store.save(
        'joe',
        migrated.copyWith(
          profile: TouchProfile(
            defaults: {
              storyKey: {'titleSize': 33},
            },
          ),
        ),
      );
      await seedDemoLocalConfigurations(store);
      expect(
        (await store.load('joe', 'preferences'))?.profile.defaults[pageKey],
        isNull,
      );
    },
  );

  testWidgets('user picker applies Joe, Emily, and Fred preferences', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TechReaderApp());
    await tester.pumpAndSettle();

    Future<void> choose(String name) async {
      await tester.tap(find.byKey(const Key('demo-user-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
    }

    Object? section(String property) => tester
        .widget<A2uiSurface>(find.byType(A2uiSurface))
        .surface
        .componentsModel
        .get('status_title')
        ?.toJson()[property];

    Color pageColor() => Theme.of(
      tester.element(find.byType(A2uiSurface)),
    ).scaffoldBackgroundColor;

    final remoteBackground = section('backgroundColor');
    final remotePageColor = pageColor();
    await choose('Joe');
    expect(section('backgroundColor'), '#FFFFFF');
    expect(section('titleSize'), 36);
    expect(pageColor(), const Color(0xFFFFFFFF));
    await choose('Emily');
    expect(section('backgroundColor'), '#FCE7F3');
    expect(pageColor(), const Color(0xFFFFF1F2));
    await choose('Fred');
    expect(section('backgroundColor'), remoteBackground);
    expect(pageColor(), remotePageColor);
  });

  testWidgets('saving an occasion stores its shell, palette, and layout id', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TechReaderApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save occasion'));
    await tester.pumpAndSettle();
    final saved = await const SharedPreferencesTouchRemoteStore().load(
      'everyday',
    );
    expect(saved, isNotNull);
    expect(saved!.data['occasion'], 'everyday');
    final style = (saved.data['style'] as Map).cast<String, Object?>();
    final palette = (saved.data['palette'] as Map).cast<String, Object?>();
    final composition = (saved.data['composition'] as Map)
        .cast<String, Object?>();
    expect(
      PortalStyle.fromJson(style).headline,
      styleFor(Occasion.everyday).headline,
    );
    expect(
      OccasionPalette.fromJson(palette).accent,
      paletteFor(Occasion.everyday).accent,
    );
    expect(OccasionComposition.fromJson(composition).layout, Occasion.everyday);
  });

  testWidgets('Emily sees only pink choices in the Touch color picker', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TechReaderApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('demo-user-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emily').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open GenUI Touch'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('touch-color-field-backgroundColor')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('touch-color-choice-blush')), findsOneWidget);
    expect(
      find.byKey(const Key('touch-color-choice-bubblegum')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('touch-color-choice-indigo')), findsNothing);
    expect(find.byKey(const Key('touch-color-choice-green')), findsNothing);
    await tester.tap(find.byKey(const Key('touch-color-choice-blush')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<A2uiSurface>(find.byType(A2uiSurface))
          .surface
          .componentsModel
          .get('root')
          ?.toJson()['backgroundColor'],
      '#FFF1F2',
    );
  });

  testWidgets('NewsPage Gallery color paints and saves the whole page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TechReaderApp());
    await tester.pumpAndSettle();

    Color shellBackground() => Theme.of(
      tester.element(find.byType(A2uiSurface)),
    ).scaffoldBackgroundColor;
    Object? pageBackground() => tester
        .widget<A2uiSurface>(find.byType(A2uiSurface))
        .surface
        .componentsModel
        .get('root')
        ?.toJson()['backgroundColor'];

    expect(pageBackground(), '#F3F5F9');
    await tester.tap(find.byTooltip('Open GenUI Touch'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance for all NewsPage components'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('touch-color-field-backgroundColor')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('touch-color-choice-indigo')));
    await tester.pumpAndSettle();
    expect(pageBackground(), '#4F46E5');
    expect(shellBackground(), const Color(0xFF4F46E5));
    expect(
      Theme.of(
        tester.element(find.byType(A2uiSurface)),
      ).textTheme.bodyMedium?.color,
      Colors.white,
    );

    await tester.tap(find.widgetWithIcon(IconButton, Icons.save_outlined));
    await tester.pumpAndSettle();
    final saved = await const SharedPreferencesTouchRemoteStore().load(
      'everyday',
    );
    expect(
      saved
          ?.profile
          .defaults['$newsGalleryCatalogId\u0000NewsPage']?['backgroundColor'],
      '#4F46E5',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const TechReaderApp());
    await tester.pumpAndSettle();
    expect(pageBackground(), '#4F46E5');
    expect(shellBackground(), const Color(0xFF4F46E5));
  });

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
    expect(find.text('Appearance for all NewsPage components'), findsOneWidget);
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
    expect(find.text('NewsPage'), findsOneWidget);
    expect(find.text('Surface'), findsNothing);
    expect(find.text('Gallery'), findsNothing);
    final save = find.widgetWithIcon(IconButton, Icons.save_outlined);
    expect(tester.widget<IconButton>(save).onPressed, isNull);

    await tester.tap(find.text('NewsSection').last);
    await tester.pumpAndSettle();

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
    final key = prefs.getKeys().singleWhere((key) => key.contains('remote.v1'));
    final remote = TouchConfiguration.fromJson(
      (jsonDecode(prefs.getString(key)!) as Map).cast<String, Object?>(),
    );
    final profile = remote.profile;
    expect(remote.data['occasion'], 'everyday');
    expect(remote.data['style'], isA<Map>());
    expect(remote.data['palette'], isA<Map>());
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
    final resetProfile = TouchConfiguration.fromJson(
      (jsonDecode(prefs.getString(key)!) as Map).cast<String, Object?>(),
    ).profile;
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
    TouchContract contract(String type) =>
        contracts.firstWhere((item) => item.componentType == type);
    touch.setGalleryDefault(contract('NewsSection'), 'titleSize', 36);
    touch.setGalleryDefault(contract('NewsStory'), 'buttonStyle', 'text');
    touch.setGalleryDefault(contract('NewsGrid'), 'gap', 24);
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
    final section = readerTouchContracts().firstWhere(
      (contract) => contract.componentType == 'NewsSection',
    );
    final story = readerTouchContracts().firstWhere(
      (contract) => contract.componentType == 'NewsStory',
    );
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
