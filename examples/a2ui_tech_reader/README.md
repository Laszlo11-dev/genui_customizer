# A2UI Tech Reader

A standalone Flutter RSS / Atom reader. **Flutter owns the app shell**: source and occasion controls, search, navigation, and the JSON inspector. **A2UI owns the news stream**: story cards, images, metadata, sections, article actions, and loading / empty / error states. GenUI Touch edits approved presentation values in that stream.

## Run

Requires Flutter with Dart >=3.10.

```bash
flutter pub get
flutter run -d windows
# or flutter run -d chrome
flutter test
flutter analyze
```

For Android Studio, select the **A2UI Tech Reader (Ask AI)** run configuration and replace `PASTE_YOUR_GEMINI_API_KEY_HERE` in its Additional run args with your key. The configuration is stored in the ignored `.idea/runConfigurations` folder, so your key stays out of Git.

To enable **Ask AI** from a terminal, provide a Gemini API key:

```powershell
$env:GEMINI_API_KEY = 'your-key'
flutter run -d windows
```

You can also use `--dart-define=GEMINI_API_KEY=...` (required for web). Without a key, Ask AI remains visible but disabled. Selecting Ask AI opens a prompt editor prefilled with **Holidays at Sea**; the request starts only after **Generate A2UI**. **Edit AI prompt** opens the editor again. Gemini chooses a coordinated presentation for the page shell and A2UI feed: palette, thematic UI headings, grid or feature layout, card typography, images, and buttons. The app keeps the feed content, filtering, article order, and original links. On HTTP 503, the reader retries once, then uses the chat example's Flash-Lite fallback. A timeout also switches to Flash-Lite. If both models fail, the original feed stays visible alongside the error. A key supplied to a browser build is exposed to that browser; use a server-side proxy for a public deployment.

Windows and web platform runners are included in the example.

## How it works

`RssService` downloads and parses RSS or Atom into `NewsItem`. The Flutter shell filters these items for search and selects an occasion. `NewsA2uiBuilder.build` turns the resulting articles into A2UI 1.0 `createSurface` and `updateComponents` messages. The host registers the basic catalog and the local `newsGalleryCatalog`; the official `A2uiSurface` renders the news stream. Article buttons emit A2UI actions; the host opens the corresponding original URL.

RSS `<category>` and Atom `<category term="…">` tags are retained on each `NewsItem`. The **Hide politics & war** chip is enabled by default. It filters explicit political and war tags, plus clear political signals in titles. The broad `Policy` tag alone does not hide an article because it also covers technology regulation. This is a heuristic filter, so ambiguous or untagged stories may still need manual review. The chip can be turned off to show the full feed.

The local gallery in `lib/news_gallery.dart` defines `NewsSection`, `NewsStory`, and `NewsGrid`. Their schemas expose presentation values in A2UI: colors, type sizes and weight, card shape and spacing, image position and height, button style, elevation, grid columns and gaps. Touch edits only the presentation properties listed in `lib/news_touch.dart` as defaults for each catalog type. Content, article links, and actions remain outside its contract.

## Edit the news appearance

Open **GenUI Touch** with the tune icon in the app bar, triple-click a news component on desktop, or long-press it on touch devices. The gesture opens the editor on that component's **type**. Choose **NewsSection**, **NewsStory**, or **NewsGrid**, then change a property. The new value applies immediately to every current component of that type and to later feed updates. The editor shows a current example value until you set a default. Use the reset icon beside an overridden property, **Use original** in the color chooser, or **Restore original [type] appearance** to remove overrides and show the generated values for the current edition. Press **Save profile** to keep changed defaults or resets after restart; the button is disabled when there is nothing new to save. **Discard unsaved defaults** restores the last saved profile and updates the current feed. The profile is stored locally for this app installation using shared preferences and is loaded before the first generated surface. There is no account sync or tenant separation.

Changing the source, search, occasion, or AI layout recreates the A2UI news surface and reapplies the type defaults. Old reader profiles retain their type defaults, but their item-role rules are ignored. Numeric values are clamped by the renderer. Color fields display the current color as a swatch and offer 16 named colors; previously saved colors outside the palette remain visible until changed.

Switching occasions fades the old feed out, then brings the new A2UI surface in with a short upward motion. The header and shell colors transition alongside it. Rapid selections cancel the earlier transition cleanly.

The four editions share the same renderer. Normal uses a lead article and three-column grid. Christmas groups actual gift-related stories. Winter Games separates winter-sport matches and shows a news wire. Easter groups actual spring-related stories. Group headings appear only when matching stories exist. No article content is changed. Adding an edition means adding a builder composition, with no occasion-specific Flutter article widgets.

Use the **data object** button in the app bar to inspect the generated A2UI JSON before Touch applies saved appearance. Refreshing, changing sources, searching, and switching occasions regenerate that JSON.

## Web feeds

A browser can fetch only RSS feeds that permit the app's origin under CORS. A blocked feed appears as an A2UI error state. For a reliable hosted demo, use feeds with permissive CORS or a same-origin gateway under your control. Windows does not have browser CORS restrictions.

The presets provide technology-oriented sources; a general feed may still contain unrelated articles. Images and dates are optional and omitted when absent. Article buttons open publisher pages.
