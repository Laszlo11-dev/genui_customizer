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

`RssService` downloads and parses RSS or Atom into `NewsItem`. The Flutter shell filters these items for search and selects an occasion. `NewsA2uiBuilder.build` turns the resulting articles into A2UI 1.0 `createSurface` and `updateComponents` messages. The host registers the basic catalog and the local `newsGalleryCatalog`; the official `A2uiSurface` renders the news stream. Article buttons emit A2UI actions; the host opens the corresponding original URL.

RSS `<category>` and Atom `<category term="…">` tags are retained on each `NewsItem`. The **Hide politics & war** chip is enabled by default. It filters explicit political and war tags, plus clear political signals in titles. The broad `Policy` tag alone does not hide an article because it also covers technology regulation. This is a heuristic filter, so ambiguous or untagged stories may still need manual review. The chip can be turned off to show the full feed.

The local gallery in `lib/news_gallery.dart` defines `NewsSection`, `NewsStory`, and `NewsGrid`. Their schemas expose presentation values in A2UI: colors, type sizes and weight, card shape and spacing, image position and height, button style, elevation, grid columns and gaps. The occasion builder supplies different values for Everyday, Christmas, Winter Games, and Easter. This gallery is ready for a later Touch integration, but Touch is not connected in this app yet. Content and article actions remain separate from presentation values.

Switching occasions fades the old feed out, then brings the new A2UI surface in with a short upward motion. The header and shell colors transition alongside it. Rapid selections cancel the earlier transition cleanly.

The four editions share the same renderer. Normal uses a lead article and three-column grid. Christmas groups actual gift-related stories. Winter Games separates winter-sport matches and shows a news wire. Easter groups actual spring-related stories. Group headings appear only when matching stories exist. No article content is changed. Adding an edition means adding a builder composition, with no occasion-specific Flutter article widgets.

Use the **data object** button in the app bar to inspect the exact JSON passed to the processor. Refreshing, changing sources, searching, and switching occasions regenerate that JSON.

## Web feeds

A browser can fetch only RSS feeds that permit the app's origin under CORS. A blocked feed appears as an A2UI error state. For a reliable hosted demo, use feeds with permissive CORS or a same-origin gateway under your control. Windows does not have browser CORS restrictions.

The presets provide technology-oriented sources; a general feed may still contain unrelated articles. Images and dates are optional and omitted when absent. Article buttons open publisher pages.
