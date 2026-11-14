import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/basic_catalog.dart';
import 'package:a2ui_tech_reader/a2ui_builder.dart';
import 'package:a2ui_tech_reader/models.dart';
import 'package:a2ui_tech_reader/news_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('official renderer displays each generated news edition', (
    tester,
  ) async {
    final items = [
      NewsItem(
        title: 'A new laptop',
        link: Uri.parse('https://example.org/a'),
        source: 'Example',
        summary: 'A useful gadget',
        imageUrl: 'https://example.org/photo.jpg',
      ),
      NewsItem(
        title: 'Solar design',
        link: Uri.parse('https://example.org/b'),
        source: 'Example',
        summary: 'Spring technology',
      ),
      NewsItem(
        title: 'Ski sensor',
        link: Uri.parse('https://example.org/c'),
        source: 'Example',
        summary: 'Winter sport technology',
      ),
    ];
    for (final occasion in [
      Occasion.everyday,
      Occasion.christmas,
      Occasion.winter,
      Occasion.easter,
    ]) {
      final processor = MessageProcessor<ComponentImplementation>(
        catalogs: [basicCatalog(), newsGalleryCatalog],
      );
      SurfaceModel<ComponentImplementation>? surface;
      processor.model.onSurfaceCreated.subscribe((value) => surface = value);
      final errors = processor.processMessagesWithErrors(
        NewsA2uiBuilder.build(items, occasion),
      );
      expect(
        errors.map((error) => error.toJson()).toList(),
        isEmpty,
        reason: occasion.name,
      );
      expect(surface, isNotNull, reason: occasion.name);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: A2uiSurface(surface: surface!)),
          ),
        ),
      );
      expect(find.text('A new laptop'), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image).first);
      final networkImage = image.image as NetworkImage;
      expect(
        networkImage.webHtmlElementStrategy,
        WebHtmlElementStrategy.fallback,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      processor.dispose();
    }
  });

  testWidgets('gallery story dispatches its article action', (tester) async {
    final processor = MessageProcessor<ComponentImplementation>(
      catalogs: [basicCatalog(), newsGalleryCatalog],
    );
    SurfaceModel<ComponentImplementation>? surface;
    String? actionName;
    processor.model.onSurfaceCreated.subscribe((value) => surface = value);
    processor.model.onAction.subscribe((value) => actionName = value.name);
    final errors = processor.processMessagesWithErrors(
      NewsA2uiBuilder.build([
        NewsItem(
          title: 'Article',
          link: Uri.parse('https://example.org/a'),
          source: 'Example',
        ),
      ], Occasion.everyday),
    );
    expect(errors, isEmpty);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: A2uiSurface(surface: surface!)),
        ),
      ),
    );
    await tester.tap(find.text('Read original ↗'));
    await tester.pump();
    expect(actionName, 'open_0');
    await tester.pumpWidget(const SizedBox.shrink());
    processor.dispose();
  });
}
