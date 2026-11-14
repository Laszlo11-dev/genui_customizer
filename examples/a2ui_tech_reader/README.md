# A2UI Tech Reader

A standalone Flutter RSS / Atom reader. **Flutter owns the app shell**: source and occasion controls, navigation, and the JSON inspector. **A2UI owns the news stream**: story cards, images, metadata, sections, article actions, and loading / empty / error states. GenUI Touch edits approved presentation values in that stream.

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

`RssService` downloads and parses RSS or Atom into `NewsItem`. The Flutter shell applies the political-news filter and selects an occasion. `NewsA2uiBuilder.build` turns the resulting articles into A2UI 1.0 `createSurface` and `updateComponents` messages. The host registers the basic catalog and the local `newsGalleryCatalog`; the official `A2uiSurface` renders the news stream. Article buttons emit A2UI actions; the host opens the corresponding original URL.

Feed downloads have a 15-second total timeout and a 2 MB response limit. Relative article links are resolved against the feed URL and any `xml:base` value. If refreshing fails after a successful load, the reader shows the error above the last loaded stories and identifies their source.

RSS `<category>` and Atom `<category term="…">` tags are retained on each `NewsItem`. The **Hide politics & war** chip is enabled by default. It filters explicit political and war tags, plus clear political signals in titles. The broad `Policy` tag alone does not hide an article because it also covers technology regulation. This is a heuristic filter, so ambiguous or untagged stories may still need manual review. The chip can be turned off to show the full feed.

The local gallery in `lib/news_gallery.dart` defines `NewsPage`, `NewsSection`, `NewsStory`, and `NewsGrid`. Their schemas expose presentation values in A2UI: the whole page background, component colors, type sizes and weight, card shape and spacing, image position and height, button style and color, elevation, grid columns and gaps. Touch edits only the presentation properties listed in `lib/news_touch.dart` as defaults for each catalog type. Content, article links, and actions remain outside its contract.

## Edit the news appearance

Open **GenUI Touch** with the Touch button in the demo panel, triple-click a news component on desktop, or long-press it on touch devices. The gesture opens the editor on that component's **type**. Choose **NewsPage** to change the whole page background, or choose **NewsSection**, **NewsStory**, or **NewsGrid** for component appearance. Under **NewsStory**, **Read original button color** sets the action button color independently of the story accent. The new value applies immediately and to later feed updates. The editor shows a current example value until you set a default. Use the reset icon beside an overridden property, **Use original** in the color chooser, or **Restore original [type] appearance** to remove overrides and show the generated values for the current edition. **Save profile** saves the edited remote or local layer; **Discard unsaved defaults** restores that layer's last saved values. The Studio identifies the selected layer above the fields.

In the Touch demo panel, **Tenant editor** edits the selected occasion's remote appearance. **Save occasion** stores the complete occasion record: its edition identifier, Flutter shell style, A2UI palette and composition, optional Ask AI layout and prompt, and Touch appearance rules. Joe, Fred, and Emily edit separate local preferences. The reader applies the remote appearance first and the selected user's local preferences second. Switching user or occasion loads the matching records and asks what to do with unsaved Studio edits. All records are local to this app installation; the demo has no account synchronization or backend. Existing single-profile defaults are used as the initial Everyday remote profile until that occasion is saved in the new format.

The Touch demo panel opens by default. On first use, the reader creates three local records: **Joe** gets a white page, larger headings and summaries, high contrast colors, and a single-column feed; **Emily** gets a pink page, sections, and story colors; **Fred** starts with no overrides, so he sees the received occasion appearance. Older demo records gain the page background once while preserving saved edits. Later changes are not reset on startup.

The AppBar title is **Live RSS stories · rendered by A2UI**. Its Settings action opens the RSS source, filter, and custom feed controls. The edition heading is supplied by the A2UI news surface.

Changing the source, filter, occasion, or AI layout recreates the A2UI news surface and reapplies the active remote and local type defaults. Old reader profiles retain their type defaults, but their item-role rules are ignored. Numeric values are clamped by the renderer. Color fields display the current color as a swatch and offer 16 named colors; previously saved colors outside the palette remain visible until changed.

Switching occasions fades the old feed out, then brings the new A2UI surface in with a short upward motion. The header and shell colors transition alongside it. Rapid selections cancel the earlier transition cleanly.

The four editions share the same renderer. Normal uses a lead article and three-column grid. Christmas groups actual gift-related stories. Winter Games separates winter-sport matches and shows a news wire. Easter groups actual spring-related stories. Group headings appear only when matching stories exist. No article content is changed. Adding an edition means adding a builder composition, with no occasion-specific Flutter article widgets.

Use **Debug** in the Touch demo panel to inspect the generated A2UI JSON before Touch applies saved appearance. Refreshing, changing sources, filtering, and switching occasions regenerate that JSON.

## Web feeds

A browser can fetch only RSS feeds that permit the app's origin under CORS. The web presets are The Register and NASA; The Register is the default. Other feed URLs can be entered manually, but a blocked custom feed appears as an A2UI error state. For a reliable hosted demo, use feeds with permissive CORS or a same-origin gateway under your control. Windows does not have browser CORS restrictions. Web story images can fall back to HTML image elements when their hosts do not permit Flutter's image fetch; these elements have different rendering and capture behavior.

The presets provide technology-oriented sources; a general feed may still contain unrelated articles. Images and dates are optional and omitted when absent. Article buttons open publisher pages.
