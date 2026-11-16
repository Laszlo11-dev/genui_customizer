# A2UI Tech Reader

A standalone Flutter RSS / Atom reader. **Flutter owns the app shell**: source and occasion controls, navigation, and the JSON inspector. **A2UI owns the news stream**: story cards, images, metadata, sections, article actions, and loading / empty / error states. GenUI Touch edits approved presentation values in that stream.

## Run

Requires Flutter >=3.47 with Dart >=3.13.

```bash
cd example
flutter pub get
flutter run -d windows
# or flutter run -d chrome
flutter test
flutter analyze
```

Run these commands from the repository root; after `cd example`, the remaining commands run in the reader directory. The repository pins Flutter 3.47.9 in `.fvmrc`; with FVM, use `fvm flutter` in place of `flutter`.

For Android Studio, create a Flutter run configuration with `example/lib/main.dart` as its entrypoint and `example` as its working directory. A run configuration in `.idea/runConfigurations` is local and ignored by Git; it is not included in a fresh checkout. For private Windows testing, add `GEMINI_API_KEY` as an environment variable in that configuration.

For a repeatable first run without a live RSS server, open **Settings**, select **Demo feed**, then use **1-min demo** in the AppBar or open **Touch**. The feed snapshot is bundled; publisher images and **Read original** links still use the network.

To enable **Ask AI** from a terminal, provide a Gemini API key:

```powershell
$env:GEMINI_API_KEY = 'your-key'
flutter run -d windows
```

You can also use `--dart-define=GEMINI_API_KEY=...` (required for web). Without a key, generating a new Ask AI layout is disabled; an already saved Ask AI occasion can still be selected. Selecting a new Ask AI layout opens a prompt editor prefilled with **Holidays at Sea**; the request starts only after **Generate A2UI**. **Edit AI prompt** opens the editor again. Gemini chooses a coordinated presentation for the page shell and A2UI feed: palette, thematic UI headings, grid, feature or wire layout, card typography, images, and buttons. The app keeps the feed content, filtering, article order, and original links.

The reader's independent HTTP client requests `gemini-3.6-flash` and falls back to `gemini-3.5-flash-lite`. Each model gets one retry on HTTP 503. A primary timeout (12 seconds per request) switches directly to the fallback (18 seconds per request). Other HTTP errors are shown without this retry. If generation fails, the feed stays visible alongside the error. Model availability depends on the Gemini service and the supplied account; these names describe the current code defaults. The reader does not depend on the chat example or its client.

A key supplied with `--dart-define` is compiled into the app, including browser builds. The Pages workflow builds without a key. For a public deployment with AI generation, add a server-side proxy; this sample does not include one.

Windows and web platform runners are included in the example.

If Windows reports a CMake cache/source directory mismatch after moving or copying an app, run `flutter clean`, `flutter pub get`, then `flutter run -d windows` from the reader directory. Generated build files must not be copied from the chat sample or another app. The `flutter pub outdated` notice is informational and does not cause this error.

## How it works

The Dart sources under `lib/` are grouped by role: `a2ui/` builds the A2UI feed and AI layout, `news/` defines the news catalog and Touch appearance, `rss/` handles feed loading and filtering, `demo/` holds the guided tour and bundled feed, and `platform/` reads the optional local API key. `main.dart`, `reader_app.dart`, and `models.dart` remain at the top level as the entrypoint, app shell, and shared data model.

`RssService` downloads and parses RSS or Atom into `NewsItem`. The Flutter shell applies the political-news filter and selects an occasion. `NewsA2uiBuilder.build` turns the resulting articles into A2UI 1.0 `createSurface` and `updateComponents` messages. The host registers the basic catalog and the local `newsGalleryCatalog`; the official `A2uiSurface` renders the news stream. Article buttons emit A2UI actions; the host opens the corresponding original URL.

Feed downloads have a 15-second network timeout and a 2 MiB response limit. Native downloads enforce both while reading the stream; the browser client checks size after buffering the response. XML parsing follows the download. Relative article links are resolved against the feed URL and any `xml:base` value. If refreshing fails after a successful load, the reader shows the error above the last loaded stories and identifies their source. The reader displays up to 24 articles after filtering.

RSS `<category>` and Atom `<category term="…">` tags are retained on each `NewsItem`. The **Hide politics & war** chip is enabled by default. It filters explicit political and war tags, plus clear political signals in titles. The broad `Policy` tag alone does not hide an article because it also covers technology regulation. This is a heuristic filter, so ambiguous or untagged stories may still need manual review. The chip can be turned off to show the full feed.

The local gallery in `lib/news/news_gallery.dart` defines `NewsPage`, `NewsSection`, `NewsStory`, and `NewsGrid`. Their schemas expose presentation values in A2UI: the whole page background, component colors, type sizes and weight, card shape and spacing, image position and height, button style and color, elevation, grid columns and gaps. Touch edits only the presentation properties listed in `lib/news/news_touch.dart` as defaults for each catalog type. Content, article links, and actions remain outside its contract.

## Edit the news appearance

Open **GenUI Touch** with the Touch button in the demo panel, triple-click a news component on desktop, or long-press it on touch devices. The gesture opens the editor on that component's **type**. Choose **NewsPage** to change the whole page background, or choose **NewsSection**, **NewsStory**, or **NewsGrid** for component appearance. Under **NewsStory**, **Read original button color** sets the action button color independently of the story accent. The new value applies immediately and to later feed updates. The editor shows a current example value until you set a default. Use the reset icon beside an overridden property, **Use original** in the color chooser, or **Restore original [type] appearance** to remove overrides and show the generated values for the current edition. **Save profile** saves the edited remote or local layer; **Discard unsaved defaults** restores that layer's last saved values. The Studio identifies the selected layer above the fields.

The **Touch demo** section uses a dark, high-contrast panel with a compact header and expands and collapses the controls together. **Remote** labels the occasion and layout selector; **Local** labels the user selector and editing actions. **Tenant editor** edits the selected occasion's remote appearance. **Save occasion** stores the complete occasion record: its edition identifier, Flutter shell style, A2UI palette and composition, optional Ask AI layout and prompt, and Touch appearance rules. Joe, Fred, and Emily edit separate local preferences. The reader applies the remote appearance first and the selected user's local preferences second. Switching user or occasion loads the matching records and asks what to do with unsaved Studio edits. All records are local to this app installation; the demo has no account synchronization or backend. Existing single-profile defaults are used as the initial Everyday remote profile until that occasion is saved in the new format.

The Touch demo panel opens by default. On first use, the reader creates three local records: **Joe** gets a white page, larger headings and summaries, high contrast colors, and a single-column feed; **Emily** gets a pink page, sections, and story colors; **Fred** starts with no overrides, so he sees the received occasion appearance. Older demo records gain the page background once while preserving saved edits. Later changes are not reset on startup.

The AppBar title is **Live RSS stories · rendered by A2UI**. Its Settings action opens the RSS source, filter, and custom feed controls. The edition heading is supplied by the A2UI news surface.

The selectors are labelled **Remote** (occasion) and **Local** (user). Tenant editor, Joe, Fred, and Emily are demo roles; selecting them does not authenticate a user or enforce server permissions. Emily's Studio offers a custom palette of 12 pink shades; other users get the default 16-color palette.

## One-minute guided demo

`lib/main.dart` starts the app, `lib/reader_app.dart` contains the reader UI, and `lib/demo/reader_demo.dart` contains the tour actions, demo users, and visual cues.

Use **1-min demo** in the AppBar to play the English intro script. The five scenes show an Everyday page, switch to Christmas and then Winter Games, compare Joe and Emily, then let Emily change the **Read original** button to pink in Touch Studio before the closing frame. The local RSS snapshot contains a fixed A2UI and Flutter reading list, the A2UI Flutter package page on pub.dev, and the GenUI Touch project page. **Read original** opens the linked source page during the tour. A2UI renders the page; animated transitions, focus rings, and click markers show the selection and editing steps. The Studio opens in a compact window beside the news cards for this tour; its saved size is not changed. The bottom bar shows narration text and offers pause, next, close, and end-of-script replay controls; the app does not play an audio voice-over. Closing the demo restores the previous feed, occasion, and user profile without saving the scripted edit. The scene data and reusable controller live in `lib/demo/demo_tour.dart`; the curated RSS snapshot lives in `lib/demo/demo_feed.dart`. Thumbnail images are fetched from publishers at runtime, so a blocked image host may show the built-in fallback.

The snapshot is not automatically updated. The same **Demo feed** is available in the RSS preset selector outside the guided tour. Selecting it loads the bundled snapshot without a network feed request; links still point to the original articles and package or project pages.

Changing the source, filter, occasion, or AI layout recreates the A2UI news surface and reapplies the active remote and local type defaults. Old reader profiles retain their type defaults, but their item-role rules are ignored. Numeric values are clamped by the renderer. Color fields display the current color as a swatch and offer 16 named colors; previously saved colors outside the palette remain visible until changed.

Switching occasions fades the old feed out, then brings the new A2UI surface in with a short upward motion. The header and shell colors transition alongside it. Rapid selections cancel the earlier transition cleanly.

The four built-in editions share the same renderer. Everyday uses a lead article and three-column grid. Christmas groups actual gift-related stories. Winter Games separates winter-sport matches and shows a news wire. Easter groups actual spring-related stories. Group headings appear only when matching stories exist. No article content is changed. Adding an edition means adding a builder composition, with no occasion-specific Flutter article widgets.

Use **Debug** in the Touch demo panel to inspect the generated A2UI JSON before Touch applies saved appearance. Refreshing, changing sources, filtering, and switching occasions regenerate that JSON.

## Web feeds

A browser can fetch only RSS feeds that permit the app's origin under CORS. The web presets are The Register, Demo feed, and NASA; The Register is the default. The bundled Demo feed does not require a feed request. Other feed URLs can be entered manually, but a blocked custom feed appears as an A2UI error state. For a reliable hosted demo, use feeds with permissive CORS or a same-origin gateway under your control. Windows does not have browser CORS restrictions. Web story images can fall back to HTML image elements when their hosts do not permit Flutter's image fetch; these elements have different rendering and capture behavior.

The presets provide technology-oriented sources; a general feed may still contain unrelated articles. Images and dates are optional and omitted when absent. Article buttons open publisher pages.

## Validation and publication

The reader is a non-published sample of the `genui_customizer` library. Its application version is independent of the library version. The package [changelog](../CHANGELOG.md) records shared-library and reader changes. Maintainer release steps and known build warnings are in the repository's [release guide](https://github.com/Laszlo11-dev/genui_customizer/blob/main/doc/RELEASING.md). CI checks the library, reader, and additional chat sample; the separate Pages workflow validates the reader before deploying a key-free web build.
