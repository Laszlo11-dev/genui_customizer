# A2UI Tech Reader

A standalone Flutter RSS / Atom reader. **Flutter owns the app shell**: source and occasion controls, search, navigation, and the JSON inspector. **A2UI owns the news stream**: story cards, images, metadata, sections, article actions, and loading / empty / error states. Touch is not used.

## Run

Requires Flutter with Dart >=3.10.

```bash
flutter pub get
flutter run -d windows
# or flutter run -d chrome
flutter test
flutter analyze
```

Windows and web platform runners are included in the example.

## How it works

`RssService` downloads and parses RSS or Atom into `NewsItem`. The Flutter shell filters these items for search and selects an occasion. `NewsA2uiBuilder.build` turns the resulting articles into A2UI 1.0 `createSurface` and `updateComponents` messages for `BasicCatalog.v1_0Id`. `MessageProcessor<ComponentImplementation>` processes those messages and the official `A2uiSurface` renders the news stream. Article buttons emit A2UI actions; the host opens the corresponding original URL.

The four editions share the same renderer. Normal uses a lead article and three-column grid. Christmas groups actual gift-related stories. Winter Games separates winter-sport matches and shows a news wire. Easter groups actual spring-related stories. Group headings appear only when matching stories exist. No article content is changed. Adding an edition means adding a builder composition, with no occasion-specific Flutter article widgets.

Use the **data object** button in the app bar to inspect the exact JSON passed to the processor. Refreshing, changing sources, searching, and switching occasions regenerate that JSON.

## Web feeds

A browser can fetch only RSS feeds that permit the app's origin under CORS. A blocked feed appears as an A2UI error state. For a reliable hosted demo, use feeds with permissive CORS or a same-origin gateway under your control. Windows does not have browser CORS restrictions.

The presets provide technology-oriented sources; a general feed may still contain unrelated articles. Images and dates are optional and omitted when absent. Article buttons open publisher pages.
