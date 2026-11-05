# Restaurant Finder runtime customization

This example adapts the [official A2UI Restaurant Finder Flutter client](https://github.com/a2ui-project/a2ui/tree/main/samples/client/flutter/restaurant_finder)
at commit `43696ef4309eaa08d5cf25106718703daeaf6d88`.
The copied Flutter source, recorded A2UI responses, and two images retain
their original Google copyright notices and Apache 2.0 license
(`UPSTREAM_LICENSE`). The example changes the client to demonstrate
`genui_customizer` inside a real GenUI app. See the
[install guide](INSTALL_GUIDE.md) for every integration source change and why
it is needed in another host application.

In Android Studio, create a **Flutter** run configuration with Dart entrypoint
`lib/main.dart`, then select an **Android device**, **Windows (desktop)**, or
**Chrome**. A **Dart Command Line Application** configuration
cannot run Flutter and produces `dart:ui` errors. The example starts with
recorded responses; no agent server or API key is required.

From the example directory, the equivalent web commands are:

```sh
flutter pub get
flutter run -d chrome
```

For Windows desktop, replace `chrome` with `windows`.
For an Android device, replace `chrome` with its device ID from `flutter devices`.

1. Search to show the first recorded restaurant result.
2. Open **Customize results**, select a restaurant image or name, change its
   presentation, and save. Triple click on desktop or long press on touch also
   opens the selected widget.
3. Search again. A new recorded result and different layout appear with the
   saved presentation. Reload the page and search once more to verify storage.
4. Use **Reset saved appearance** and search again to restore the agent's
   default presentation.

The Studio overflow menu includes **GenUI debug**. In recorded mode it shows
the last search request and replayed A2UI response; in live mode it shows the
latest received A2UI messages. The current UI and saved appearance are also
available there.

The Studio also remembers its window position and size after a move or resize,
including when the app is started again. If the available screen is smaller,
the window fits itself back inside the visible area.

The example replays recorded agent output by default and uses local device
storage. It makes no AI request or credentialed call. The original A2A client
transport remains in `lib/src/session.dart`. To connect a separately running,
approved local agent, set `GENUI_CUSTOMIZER_AGENT_URL` with `--dart-define` to
its loopback HTTP URL. The original Python agent is referenced upstream but is
not bundled into this Flutter package. The host application owns its agent
configuration and authorization.
