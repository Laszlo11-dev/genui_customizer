import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/basic_catalog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:genui_customizer/genui_customizer.dart';
import 'package:url_launcher/url_launcher.dart';

import 'a2ui_builder.dart';
import 'ai_layout.dart';
import 'demo_feed.dart';
import 'demo_tour.dart';
import 'models.dart';
import 'news_gallery.dart';
import 'news_touch.dart';
import 'news_filter.dart';
import 'rss_service.dart';
import 'readable_color.dart';
import 'runtime_key_stub.dart'
    if (dart.library.io) 'runtime_key_io.dart'
    as runtime_key;

const _definedApiKey = String.fromEnvironment('GEMINI_API_KEY');

enum _DemoUser {
  tenantEditor('Tenant editor', 'An editor for the tenant.'),
  joe('Joe', 'Joe has trouble seeing clearly.'),
  fred('Fred', 'Fred is curious and does not overwrite what he receives.'),
  emily('Emily', 'Emily loves every color, as long as it\'s pink.');

  const _DemoUser(this.label, this.description);

  final String label;
  final String description;
}

// Emily's very serious rule: every offered color is pink.
const _emilyPalette = <TouchColorSwatch>[
  TouchColorSwatch('Blush', '#FFF1F2'),
  TouchColorSwatch('Rosewater', '#FFE4E6'),
  TouchColorSwatch('Petal', '#FCE7F3'),
  TouchColorSwatch('Cotton candy', '#FBCFE8'),
  TouchColorSwatch('Bubblegum', '#F9A8D4'),
  TouchColorSwatch('Rose', '#FDA4AF'),
  TouchColorSwatch('Hot pink', '#EC4899'),
  TouchColorSwatch('Fuchsia', '#D946EF'),
  TouchColorSwatch('Raspberry', '#DB2777'),
  TouchColorSwatch('Magenta', '#C026D3'),
  TouchColorSwatch('Berry', '#BE185D'),
  TouchColorSwatch('Plum pink', '#9D174D'),
];

void main() {
  final key = _definedApiKey.isNotEmpty
      ? _definedApiKey
      : (runtime_key.geminiKeyFromProcess() ?? '');
  runApp(TechReaderApp(apiKey: key.trim()));
}

class TechReaderApp extends StatelessWidget {
  const TechReaderApp({super.key, this.apiKey = '', this.openArticle});
  final String apiKey;
  final Future<bool> Function(Uri)? openArticle;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'A2UI Tech Reader',
    home: ReaderPage(apiKey: apiKey, openArticle: openArticle),
  );
}

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, this.apiKey = '', this.openArticle});
  final String apiKey;
  final Future<bool> Function(Uri)? openArticle;
  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage>
    with SingleTickerProviderStateMixin {
  List<FeedPreset> get _availableFeeds => kIsWeb ? webFeedPresets : feedPresets;

  final _rss = RssService();
  GeminiLayoutService? _aiService;
  AiLayout? _aiLayout;
  String? _aiError;
  String _aiPrompt = 'Holidays at Sea';
  int _aiRequestId = 0;
  final _sourceController = TextEditingController(text: feedPresets.first.url);
  late MessageProcessor<ComponentImplementation> _processor;
  late final GenUiTouchController _touch;
  late final DemoTourController _tour;
  bool _tourStudioOpen = false;
  List<NewsItem>? _tourPreviousArticles;
  String? _tourPreviousArticlesSource;
  String? _tourPreviousError;
  Occasion? _tourPreviousOccasion;
  _DemoUser? _tourPreviousUser;
  AiLayout? _tourPreviousAiLayout;
  String? _tourPreviousAiError;
  final TouchConfigurationStore _remoteStore =
      const SharedPreferencesTouchRemoteStore();
  final TouchLocalConfigurationStore _localStore =
      const SharedPreferencesTouchLocalStore();
  late final Future<void> _seedUsers;
  TouchConfiguration? _remoteConfiguration;
  PortalStyle? _occasionStyle;
  OccasionPalette? _occasionPalette;
  OccasionComposition? _occasionComposition;
  bool _touchReady = false;
  bool _demoExpanded = true;
  bool _hasSavedAiLayout = false;
  SurfaceModel<ComponentImplementation>? _surface;
  Occasion _occasion = Occasion.auto;
  _DemoUser _demoUser = _DemoUser.tenantEditor;
  String _source = feedPresets.first.name;
  List<NewsItem> _articles = [];
  String? _articlesSource;
  List<NewsItem> _renderedArticles = [];
  List<Map<String, Object?>> _messages = [];
  String? _error;
  bool _loading = false;
  bool _compact = false;
  bool _hidePolitical = true;
  int _requestId = 0;
  int _occasionChangeId = 0;
  late final AnimationController _feedTransition;
  late final Animation<double> _feedOpacity;
  late final Animation<Offset> _feedOffset;

  Occasion get _active => resolvedOccasion(_occasion, DateTime.now());

  @override
  void initState() {
    super.initState();
    if (widget.apiKey.isNotEmpty) {
      _aiService = GeminiLayoutService(widget.apiKey);
    }
    _feedTransition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 170),
      value: 1,
    );
    _feedOpacity = _feedTransition.drive(
      CurveTween(curve: Curves.easeOutCubic),
    );
    _feedOffset = _feedTransition.drive(
      Tween<Offset>(
        begin: const Offset(0, 0.025),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
    );
    _touch = GenUiTouchController(
      contracts: readerTouchContracts(),
      showSelectionOutline: false,
    );
    _touch.onStudioRequested = _openTouchStudio;
    _tour = DemoTourController(
      scenes: introScript,
      onStart: _startIntroTour,
      onAction: _runIntroAction,
      onStop: _stopIntroTour,
    )..addListener(_onTourChanged);
    _processor = _newProcessor();
    _touch.attachProcessor(_processor);
    _seedUsers = seedDemoLocalConfigurations(_localStore)
        .catchError((Object error) {
          debugPrint('Could not seed demo users: $error');
        });
    _initializeTouch();
  }

  Future<void> _initializeTouch() async {
    try {
      await _loadConfigurationContext();
    } catch (error) {
      // A damaged local profile must not prevent the news feed from loading.
      debugPrint('Could not load Touch appearance: $error');
    }
    if (!mounted) return;
    _touchReady = true;
    _render();
    _refresh();
    try {
      final savedAi = (await _loadRemote(Occasion.askAi))?.data ?? const {};
      final available =
          _readOccasionData<AiLayout?>(
            savedAi,
            'aiLayout',
            null,
            AiLayout.fromJson,
          ) !=
          null;
      if (mounted) setState(() => _hasSavedAiLayout = available);
    } catch (error) {
      debugPrint('Could not load saved AI occasion: $error');
    }
  }

  Map<String, Object?> _occasionData(Occasion edition) => {
    'occasion': edition.name,
    'style':
        (edition == Occasion.askAi && _aiLayout != null
                ? styleForAi(_aiLayout!)
                : (_occasionStyle ?? styleFor(edition)))
            .toJson(),
    'palette': (_occasionPalette ?? paletteFor(edition)).toJson(),
    'composition': (_occasionComposition ?? compositionFor(edition)).toJson(),
    if (edition == Occasion.askAi && _aiLayout != null)
      'aiLayout': _aiLayout!.toJson(),
    if (edition == Occasion.askAi) 'aiPrompt': _aiPrompt,
  };

  Future<bool> _loadConfigurationContext() async {
    final edition = _active;
    final user = _demoUser;
    final storedRemote = await _loadRemote(edition);
    final legacyProfile = storedRemote == null && edition == Occasion.everyday
        ? await _loadLegacyProfile()
        : null;
    final remote =
        storedRemote ??
        TouchConfiguration(
          id: edition.name,
          name: edition.label,
          profile: legacyProfile ?? const TouchProfile.empty(),
          data: {
            'occasion': edition.name,
            'style': styleFor(edition).toJson(),
            'palette': paletteFor(edition).toJson(),
            'composition': compositionFor(edition).toJson(),
          },
        );
    final local = await _loadLocal(user);
    if (!mounted || edition != _active || user != _demoUser) return false;
    final data = remote.data;
    final style = _readOccasionData(
      data,
      'style',
      styleFor(edition),
      PortalStyle.fromJson,
    );
    final palette = _readOccasionData(
      data,
      'palette',
      paletteFor(edition),
      OccasionPalette.fromJson,
    );
    final composition = _readOccasionData(
      data,
      'composition',
      compositionFor(edition),
      OccasionComposition.fromJson,
    );
    final savedAi = edition == Occasion.askAi
        ? _readOccasionData<AiLayout?>(
            data,
            'aiLayout',
            null,
            AiLayout.fromJson,
          )
        : null;
    _remoteConfiguration = remote;
    _occasionStyle = style;
    _occasionPalette = palette;
    _occasionComposition = composition;
    if (savedAi != null) {
      _aiLayout = savedAi;
      _aiPrompt = data['aiPrompt'] as String? ?? _aiPrompt;
    }
    _touch.useConfigurations(
      remote: remote.profile,
      local: local?.profile ?? const TouchProfile.empty(),
      editRemote: user == _DemoUser.tenantEditor,
      label: user == _DemoUser.tenantEditor
          ? 'Remote: ${remote.name}'
          : 'Local: ${user.label}',
      saveEditedProfile: (profile) async {
        if (user == _DemoUser.tenantEditor) {
          final updated = remote.copyWith(
            profile: profile,
            data: _occasionData(edition),
          );
          await _remoteStore.save(updated);
          _remoteConfiguration = updated;
        } else {
          await _localStore.save(
            user.name,
            (local ??
                    TouchConfiguration(
                      id: 'preferences',
                      name: '${user.label} preferences',
                      userId: user.name,
                      profile: const TouchProfile.empty(),
                    ))
                .copyWith(profile: profile),
          );
        }
      },
    );
    return true;
  }

  Future<TouchConfiguration?> _loadRemote(Occasion edition) async {
    try {
      return await _remoteStore.load(edition.name);
    } catch (error) {
      debugPrint('Could not load ${edition.name} appearance: $error');
      return null;
    }
  }

  Future<TouchProfile?> _loadLegacyProfile() async {
    try {
      return await const ReaderTouchStorage().load();
    } catch (error) {
      debugPrint('Could not load legacy appearance: $error');
      return null;
    }
  }

  Future<TouchConfiguration?> _loadLocal(_DemoUser user) async {
    if (user == _DemoUser.tenantEditor) return null;
    try {
      return await _localStore.load(user.name, 'preferences');
    } catch (error) {
      debugPrint('Could not load ${user.name} preferences: $error');
      return null;
    }
  }

  T _readOccasionData<T>(
    Map<String, Object?> data,
    String key,
    T fallback,
    T Function(Map<String, Object?>) parse,
  ) {
    final raw = data[key];
    if (raw == null) return fallback;
    try {
      if (raw is! Map) throw const FormatException('Expected an object.');
      return parse(raw.cast<String, Object?>());
    } catch (error) {
      debugPrint('Invalid saved $key, using defaults: $error');
      return fallback;
    }
  }

  Future<bool> _resolveUnsavedConfiguration() async {
    if (!_touch.hasUnsavedProfileChanges) return true;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved appearance changes'),
        content: const Text('Save changes before switching configuration?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (action == 'save') {
      await _touch.save();
      return true;
    }
    return action == 'discard';
  }

  Future<void> _changeDemoUser(_DemoUser? user) async {
    if (user == null || user == _demoUser) return;
    if (!await _resolveUnsavedConfiguration() || !mounted) return;
    await _seedUsers;
    if (!mounted) return;
    setState(() => _demoUser = user);
    if (await _loadConfigurationContext() && mounted) _render();
  }

  Future<void> _saveOccasion() async {
    final remote = _remoteConfiguration;
    if (remote == null) return;
    try {
      if (_touch.hasUnsavedProfileChanges) {
        await _touch.save();
      } else {
        final updated = remote.copyWith(data: _occasionData(_active));
        await _remoteStore.save(updated);
        _remoteConfiguration = updated;
      }
      if (mounted) {
        if (_active == Occasion.askAi && _aiLayout != null) {
          setState(() => _hasSavedAiLayout = true);
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Occasion saved')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save occasion: $error')),
        );
      }
    }
  }

  void _openTouchStudio() {
    if (!_touchReady) return;
    if (_tour.active) _tourStudioOpen = true;
    showGenUiTouchStudio(
      context: context,
      controller: _touch,
      surfaceId: NewsA2uiBuilder.surfaceId,
      galleryOnly: true,
      colorPalette: _demoUser == _DemoUser.emily ? _emilyPalette : null,
      onGalleryChanged: _render,
      boundsPersistence: _tour.active
          ? _TourStudioBounds(MediaQuery.sizeOf(context))
          : const SharedPreferencesTouchStudioBoundsPersistence(),
    ).whenComplete(() => _tourStudioOpen = false);
  }

  void _onTourChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _startIntroTour() async {
    await _seedUsers;
    _tourPreviousArticles = _articles;
    _tourPreviousArticlesSource = _articlesSource;
    _tourPreviousError = _error;
    _tourPreviousOccasion = _occasion;
    _tourPreviousUser = _demoUser;
    _tourPreviousAiLayout = _aiLayout;
    _tourPreviousAiError = _aiError;
    ++_requestId; // A live feed response must not replace the recording fixture.
    setState(() {
      _articles = demoRssStories();
      _articlesSource = 'Curated RSS snapshot';
      _error = null;
      _loading = false;
      _occasion = Occasion.everyday;
      _demoUser = _DemoUser.fred;
      _aiLayout = null;
      _aiError = null;
      _occasionStyle = styleFor(Occasion.everyday);
      _occasionPalette = paletteFor(Occasion.everyday);
      _occasionComposition = compositionFor(Occasion.everyday);
    });
    // The tour uses seeded, temporary profiles. Existing saved preferences are
    // restored when it closes and are never overwritten by the recording.
    _touch.useConfigurations(
      remote: const TouchProfile.empty(),
      local: const TouchProfile.empty(),
      editRemote: false,
      label: 'Demo: Fred',
      saveEditedProfile: (_) async {},
    );
    _render();
  }

  Future<void> _runIntroAction(DemoAction action) async {
    switch (action) {
      case DemoAction.showChristmas:
        await _setTourOccasion(Occasion.christmas);
      case DemoAction.showWinterGames:
        await _setTourOccasion(Occasion.winter);
      case DemoAction.showJoe:
        await _setTourUser(_DemoUser.joe);
      case DemoAction.showEmily:
        await _setTourUser(_DemoUser.emily);
      case DemoAction.openStoryStudio:
        _touch.select(
          const TouchSelection(
            surfaceId: NewsA2uiBuilder.surfaceId,
            componentId: 'story_0',
            catalogId: newsGalleryCatalogId,
            componentType: 'NewsStory',
            instanceId: 'story_0',
            dataPath: '',
          ),
        );
        await _visualClick(const Key('tour-touch-button'), 'Open Touch');
        final button = _findTourElement(const Key('tour-touch-button'))?.widget;
        if (button is OutlinedButton) button.onPressed?.call();
      case DemoAction.makeButtonPink:
        const fieldKey = Key('touch-color-field-buttonColor');
        final field = await _waitForTourElement(fieldKey);
        if (field != null) {
          await Scrollable.ensureVisible(
            field,
            duration: const Duration(milliseconds: 350),
            alignment: 0.5,
          );
          await _visualClick(fieldKey, 'Button color');
          final colorField = _findTourElement(fieldKey)?.widget;
          if (colorField is InkWell) colorField.onTap?.call();
          const pinkKey = Key('touch-color-choice-raspberry');
          final pink = await _waitForTourElement(pinkKey);
          if (pink != null) {
            await _visualClick(pinkKey, 'Choose pink');
            final choice = _findTourElement(pinkKey)?.widget;
            if (choice is InkWell) choice.onTap?.call();
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await _highlightReadButton('Now pink', const Color(0xFFDB2777));
      case DemoAction.closeStudio:
        await _closeTourStudio(animate: true);
    }
  }

  Future<void> _setTourOccasion(Occasion occasion) async {
    await _visualClick(
      const Key('tour-occasion-picker'),
      'Select ${occasion.label}',
    );
    await _feedTransition.reverse().orCancel;
    if (!mounted) return;
    setState(() {
      _occasion = occasion;
      _occasionStyle = styleFor(occasion);
      _occasionPalette = paletteFor(occasion);
      _occasionComposition = compositionFor(occasion);
    });
    _render();
    await _feedTransition.forward().orCancel;
  }

  Future<void> _setTourUser(_DemoUser user) async {
    await _visualClick(const Key('tour-user-picker'), 'Select ${user.label}');
    await _feedTransition.reverse().orCancel;
    if (!mounted) return;
    setState(() => _demoUser = user);
    final localProfile = user == _DemoUser.fred
        ? const TouchProfile.empty()
        : demoLocalConfigurations()
              .firstWhere((configuration) => configuration.userId == user.name)
              .profile;
    _touch.useConfigurations(
      remote: const TouchProfile.empty(),
      local: localProfile,
      editRemote: false,
      label: 'Demo: ${user.label}',
      saveEditedProfile: (_) async {},
    );
    _render();
    await _feedTransition.forward().orCancel;
  }

  Element? _findTourElement(Key key) {
    final root = Navigator.of(context, rootNavigator: true).context as Element;
    Element? found;
    void visit(Element element) {
      if (found != null) return;
      if (element.widget.key == key) {
        found = element;
        return;
      }
      element.visitChildren(visit);
    }

    visit(root);
    return found;
  }

  Element? _firstReadButton() {
    final root = Navigator.of(context, rootNavigator: true).context as Element;
    Element? button;
    void visit(Element element) {
      if (button != null) return;
      final widget = element.widget;
      if (widget is Text && widget.data == 'Read original') {
        element.visitAncestorElements((ancestor) {
          if (ancestor.widget is ButtonStyleButton) {
            button = ancestor;
            return false;
          }
          return true;
        });
        return;
      }
      element.visitChildren(visit);
    }

    visit(root);
    return button;
  }

  Future<void> _highlightReadButton(String label, Color color) async {
    final box = _firstReadButton()?.renderObject;
    if (box is! RenderBox || !box.attached || !mounted) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: _TourClickMarker(
          target: rect,
          label: label,
          color: color,
          showCursor: false,
        ),
      ),
    );
    overlay.insert(entry);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    entry.remove();
    entry.dispose();
  }

  Future<Element?> _waitForTourElement(Key key) async {
    for (var attempt = 0; attempt < 30 && mounted; attempt++) {
      final element = _findTourElement(key);
      if (element != null) return element;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return null;
  }

  Future<void> _visualClick(Key key, String label) async {
    final element = await _waitForTourElement(key);
    final box = element?.renderObject;
    if (box is! RenderBox || !box.attached || !mounted) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: _TourClickMarker(target: rect, label: label),
      ),
    );
    overlay.insert(entry);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    entry.remove();
    entry.dispose();
  }

  Future<void> _closeTourStudio({bool animate = false}) async {
    if (!_tourStudioOpen || !mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    // Opening the Studio first loads saved window bounds. A quick manual skip
    // may reach this cue before its route has been pushed.
    for (
      var attempt = 0;
      attempt < 20 && _tourStudioOpen && !navigator.canPop();
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!_tourStudioOpen || !mounted || !navigator.canPop()) return;
    if (animate) {
      const closeKey = Key('genui-studio-close');
      await _visualClick(closeKey, 'Close Studio');
      final close = _findTourElement(closeKey)?.widget;
      if (close is IconButton && close.onPressed != null) {
        close.onPressed!();
        _tourStudioOpen = false;
        return;
      }
    }
    _tourStudioOpen = false;
    navigator.pop();
  }

  Future<void> _stopIntroTour() async {
    await _closeTourStudio();
    if (_tourPreviousArticles == null || !mounted) return;
    setState(() {
      _articles = _tourPreviousArticles!;
      _articlesSource = _tourPreviousArticlesSource;
      _error = _tourPreviousError;
      _occasion = _tourPreviousOccasion!;
      _demoUser = _tourPreviousUser!;
      _aiLayout = _tourPreviousAiLayout;
      _aiError = _tourPreviousAiError;
      _tourPreviousArticles = null;
    });
    await _loadConfigurationContext();
    if (mounted) _render();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final compact = MediaQuery.sizeOf(context).width < 760;
    if (_compact != compact) {
      _compact = compact;
      _render();
    }
  }

  MessageProcessor<ComponentImplementation> _newProcessor() {
    final processor = MessageProcessor<ComponentImplementation>(
      catalogs: [basicCatalog(), _touch.decorateCatalog(newsGalleryCatalog)],
    );
    processor.model.onSurfaceCreated.subscribe((created) {
      if (!mounted) return;
      setState(() => _surface = created);
    });
    processor.model.onAction.subscribe((action) {
      final match = RegExp(r'^open_(\d+)$').firstMatch(action.name);
      if (match == null) return;
      final index = int.tryParse(match.group(1)!);
      if (index == null || index >= _renderedArticles.length) return;
      final url = _renderedArticles[index].link;
      if (url.scheme == 'https' || url.scheme == 'http') {
        unawaited(
          widget.openArticle?.call(url) ??
              launchUrl(url, mode: LaunchMode.externalApplication),
        );
      }
    });
    return processor;
  }

  void _render() {
    if (!_touchReady) return;
    _renderedArticles = _filteredArticles();
    _messages = NewsA2uiBuilder.build(
      _renderedArticles,
      _active,
      compact: _compact,
      loading: _loading,
      error: _error,
      staleSource: _articlesSource,
      aiLayout: _aiLayout,
      aiError: _aiError,
      occasionPalette: _occasionPalette,
      occasionComposition: _occasionComposition,
      pageBackgroundColor: _active == Occasion.askAi && _aiLayout != null
          ? _aiLayout!.pageColor
          : _hex(_occasionStyle?.background ?? styleFor(_active).background),
    );
    _surface = null;
    try {
      _touch.processAgentMessages({
        'version': '1.0',
        'deleteSurface': {'surfaceId': NewsA2uiBuilder.surfaceId},
      });
      _touch.processAgentMessages(_messages);
    } catch (e) {
      setState(() => _error = 'A2UI renderer: $e');
    }
  }

  String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  Color _pageBackground(PortalStyle fallback) {
    final value = _surface?.componentsModel
        .get('root')
        ?.toJson()['backgroundColor'];
    if (value is! String) return fallback.background;
    final hex = value.replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(hex)) {
      return fallback.background;
    }
    return Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
  }

  Future<void> _refresh() async {
    final id = ++_requestId;
    final requestedSource = _sourceController.text.trim();
    final presetSource = _availableFeeds
        .where((feed) => feed.url == requestedSource)
        .firstOrNull
        ?.name;
    setState(() {
      _loading = true;
      _error = null;
    });
    _render();
    try {
      final result = await _rss.load(requestedSource, source: presetSource);
      if (!mounted || id != _requestId) return;
      setState(() {
        _articles = result;
        _articlesSource = presetSource ?? requestedSource;
        _loading = false;
      });
      _render();
    } catch (e) {
      if (!mounted || id != _requestId) return;
      debugPrint('Could not load RSS feed: $e');
      setState(() {
        _loading = false;
        _error = kIsWeb
            ? 'Could not load this feed in the browser. Try another source or check the connection.'
            : 'Could not load this feed. Check the URL and connection, then retry.';
      });
      _render();
    }
  }

  void _choosePreset(String? name) {
    if (name == null) return;
    final preset = _availableFeeds.firstWhere((p) => p.name == name);
    setState(() {
      _source = name;
      _sourceController.text = preset.url;
    });
    _refresh();
  }

  Future<void> _changeOccasion(Occasion? value) async {
    if (value == null || value == _occasion) return;
    if (value == Occasion.askAi && _aiService == null && !_hasSavedAiLayout) {
      return;
    }
    if (!await _resolveUnsavedConfiguration() || !mounted) return;
    String? prompt;
    if (value == Occasion.askAi && !_hasSavedAiLayout) {
      prompt = await _editAiPrompt();
      if (!mounted || prompt == null) return;
    }
    final previous = _active;
    setState(() {
      _occasion = value;
      _aiLayout = null;
      _aiError = null;
    });
    ++_aiRequestId;
    if (!await _loadConfigurationContext() || !mounted) return;
    if (prompt != null) {
      _aiPrompt = prompt;
      _generateAiLayout(prompt);
    }
    if (_active == previous) return;
    final changeId = ++_occasionChangeId;
    try {
      await _feedTransition.reverse().orCancel;
      if (!mounted || changeId != _occasionChangeId) return;
      _render();
      await _feedTransition.forward().orCancel;
    } on TickerCanceled {
      // A newer occasion selection owns the transition.
    }
  }

  Future<String?> _editAiPrompt() async {
    final prompt = await showDialog<String>(
      context: context,
      builder: (_) => _AiPromptDialog(initialPrompt: _aiPrompt),
    );
    if (prompt != null) _aiPrompt = prompt;
    return prompt;
  }

  Future<void> _retryAiLayout() async {
    final prompt = await _editAiPrompt();
    if (!mounted || prompt == null) return;
    _generateAiLayout(prompt);
  }

  Future<void> _generateAiLayout(String prompt) async {
    final service = _aiService;
    if (service == null || _occasion != Occasion.askAi) return;
    final id = ++_aiRequestId;
    setState(() {
      _aiLayout = null;
      _aiError = null;
    });
    _render();
    try {
      final layout = await service.create(prompt);
      if (!mounted || id != _aiRequestId) return;
      setState(() => _aiLayout = layout);
    } catch (e) {
      if (!mounted || id != _aiRequestId) return;
      setState(() => _aiError = '$e');
    }
    _render();
  }

  List<NewsItem> _filteredArticles() {
    return _articles
        .where((article) {
          return !_hidePolitical || !isPoliticalNews(article);
        })
        .take(24)
        .toList();
  }

  void _showJson() {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 820,
          height: 650,
          child: Column(
            children: [
              ListTile(
                title: const Text('Current A2UI JSON'),
                trailing: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(_messages),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOccasionPanel() => Column(
    key: const Key('occasion-panel'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Remote'),
      const SizedBox(height: 12),
      ConstrainedBox(
        key: const Key('tour-occasion-picker'),
        constraints: const BoxConstraints(maxWidth: 390),
        child: DropdownButtonFormField<Occasion>(
          key: ValueKey(_occasion),
          isExpanded: true,
          initialValue: _occasion,
          decoration: const InputDecoration(
            labelText: 'Occasion / A2UI layout',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: Occasion.values.map((o) {
            final locked =
                o == Occasion.askAi && _aiService == null && !_hasSavedAiLayout;
            final disabledColor = Theme.of(context).disabledColor;
            return DropdownMenuItem(
              value: o,
              enabled: !locked,
              child: locked
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: disabledColor,
                        ),
                        const SizedBox(width: 8),
                        Text(o.label, style: TextStyle(color: disabledColor)),
                      ],
                    )
                  : Text(o.label),
            );
          }).toList(),
          onChanged: _changeOccasion,
        ),
      ),
    ],
  );

  Widget _buildUserPanel({required bool vertical}) {
    final controls = <Widget>[
      ConstrainedBox(
        key: const Key('tour-user-picker'),
        constraints: const BoxConstraints(maxWidth: 390),
        child: KeyedSubtree(
          key: ValueKey(_demoUser),
          child: DropdownButtonFormField<_DemoUser>(
            key: const Key('demo-user-picker'),
            initialValue: _demoUser,
            isExpanded: true,
            itemHeight: 76,
            decoration: const InputDecoration(
              labelText: 'User',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            selectedItemBuilder: (context) => [
              for (final user in _DemoUser.values)
                Align(alignment: Alignment.centerLeft, child: Text(user.label)),
            ],
            items: _DemoUser.values
                .map(
                  (user) => DropdownMenuItem(
                    value: user,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          user.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: _changeDemoUser,
          ),
        ),
      ),
      Tooltip(
        message: 'Open GenUI Touch',
        child: OutlinedButton.icon(
          key: const Key('tour-touch-button'),
          onPressed: _touchReady ? _openTouchStudio : null,
          icon: const Icon(Icons.tune),
          label: const Text('Touch'),
        ),
      ),
      if (_demoUser == _DemoUser.tenantEditor)
        OutlinedButton.icon(
          onPressed: _touchReady ? _saveOccasion : null,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save occasion'),
        ),
      OutlinedButton.icon(
        onPressed: _showJson,
        icon: const Icon(Icons.data_object),
        label: const Text('Debug'),
      ),
    ];
    return Column(
      key: const Key('user-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Local'),
        const SizedBox(height: 12),
        if (vertical)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: controls,
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: controls,
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(_demoUser.description),
        ),
      ],
    );
  }

  Widget _buildDemoPanels({required bool vertical}) => Card(
    elevation: 16,
    shadowColor: Colors.black.withValues(alpha: 0.55),
    color: Theme.of(context).colorScheme.inverseSurface,
    shape: const RoundedRectangleBorder(),
    child: ExpansionTile(
      key: const Key('touch-demo-panel'),
      initiallyExpanded: true,
      onExpansionChanged: (expanded) =>
          setState(() => _demoExpanded = expanded),
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: EdgeInsets.zero,
      showTrailingIcon: false,
      title: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Theme.of(context).colorScheme.inverseSurface,
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Touch demo',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                ),
              ),
            ),
            Icon(
              _demoExpanded ? Icons.expand_less : Icons.expand_more,
              color: Theme.of(context).colorScheme.onInverseSurface,
            ),
          ],
        ),
      ),
      children: [
        Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildOccasionPanel(),
              const SizedBox(height: 24),
              _buildUserPanel(vertical: vertical),
            ],
          ),
        ),
      ],
    ),
  );

  void _showFeedControls() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: StatefulBuilder(
              builder: (context, updateDialog) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Live RSS stories · rendered by A2UI',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close RSS controls',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildFeedControlsPanel(updateDialog),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedControlsPanel(StateSetter updateDialog) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              key: ValueKey(_source),
              initialValue: _availableFeeds.any((p) => p.name == _source)
                  ? _source
                  : null,
              decoration: const InputDecoration(
                labelText: 'RSS preset',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _availableFeeds
                  .map(
                    (p) => DropdownMenuItem(value: p.name, child: Text(p.name)),
                  )
                  .toList(),
              onChanged: (name) {
                _choosePreset(name);
                updateDialog(() {});
              },
            ),
          ),
          Tooltip(
            message: 'Uses feed tags and clear title signals. Technology policy stays visible.',
            child: FilterChip(
              selected: _hidePolitical,
              label: const Text('Hide politics & war'),
              onSelected: (value) {
                setState(() => _hidePolitical = value);
                updateDialog(() {});
                _render();
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _sourceController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Custom RSS / Atom URL',
                hintText: 'https://example.com/feed.xml',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _refresh(),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.rss_feed),
            label: const Text('Load'),
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (_occasion == Occasion.askAi)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _retryAiLayout,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit AI prompt'),
          ),
        ),
    ],
  );

  @override
  void dispose() {
    _requestId++;
    _aiRequestId++;
    _aiService?.dispose();
    _tour.removeListener(_onTourChanged);
    _tour.dispose();
    _feedTransition.dispose();
    _rss.dispose();
    _touch.dispose();
    _processor.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = _active == Occasion.askAi ? _aiLayout : null;
    final style = layout == null
        ? (_occasionStyle ?? styleFor(_active))
        : styleForAi(layout);
    final pageBackground = _pageBackground(style);
    final pageInk = readableColor(
      pageBackground == style.background ? style.ink : const Color(0xFF192336),
      pageBackground,
    );
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: style.accent,
        surface: style.surface,
        brightness: pageInk == Colors.white
            ? Brightness.dark
            : Brightness.light,
      ),
      scaffoldBackgroundColor: pageBackground,
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: pageInk,
        displayColor: pageInk,
      ),
      cardTheme: CardThemeData(
        color: style.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: pageInk.withValues(alpha: 0.09)),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      appBarTheme: AppBarTheme(backgroundColor: pageBackground),
    );
    return AnimatedTheme(
      data: theme,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.auto_stories_outlined, color: pageInk),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Live RSS stories · rendered by A2UI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: _touchReady && !_tour.active ? _tour.start : null,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('1-min demo'),
            ),
            IconButton(
              key: const Key('feed-settings-button'),
              onPressed: _showFeedControls,
              tooltip: 'RSS settings',
              icon: const Icon(Icons.settings_outlined),
            ),
            IconButton(
              onPressed: _loading ? null : _refresh,
              tooltip: 'Refresh RSS',
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1440;
            final feed = ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 56),
              children: [
                SizedBox(height: wide ? 4 : 12),
                if (!wide) ...[
                  _buildDemoPanels(vertical: false),
                  const SizedBox(height: 12),
                ],
                // The article cards, headings, actions, and occasion-specific
                // content below are produced by the official A2UI renderer.
                FadeTransition(
                  opacity: _feedOpacity,
                  child: SlideTransition(
                    position: _feedOffset,
                    child: _surface != null
                        ? AnimatedScale(
                            scale: _tour.active && _tour.sceneIndex == 0
                                ? 1.025
                                : 1,
                            duration: const Duration(milliseconds: 1800),
                            curve: Curves.easeInOut,
                            alignment: Alignment.topCenter,
                            child: A2uiSurface(
                              key: ObjectKey(_surface),
                              surface: _surface!,
                            ),
                          )
                        : const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Loading A2UI surface…'),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _tour.active
                      ? 'Curated RSS snapshot · Read original opens each publisher article.'
                      : 'Articles belong to their respective publishers. Open the original link to read. No scraping or article republishing.',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            );
            if (!wide) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: feed,
                ),
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1500),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: feed),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 360,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                        child: _buildDemoPanels(vertical: true),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        bottomNavigationBar: _tour.active
            ? SafeArea(
                child: Material(
                  elevation: 12,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 730),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_tour.sceneIndex + 1}/${_tour.scenes.length} · ${_tour.scene!.title} · Curated RSS',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(_tour.scene!.narration),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: _tour.playing
                                  ? 'Pause demo'
                                  : 'Play demo',
                              onPressed: _tour.playing
                                  ? _tour.pause
                                  : _tour.resume,
                              icon: Icon(
                                _tour.playing ? Icons.pause : Icons.play_arrow,
                              ),
                            ),
                            if (_tour.ended)
                              FilledButton.icon(
                                onPressed: _tour.replay,
                                icon: const Icon(Icons.replay),
                                label: const Text('Replay'),
                              )
                            else
                              IconButton(
                                tooltip: 'Next scene',
                                onPressed: _tour.next,
                                icon: const Icon(Icons.skip_next),
                              ),
                            IconButton(
                              tooltip: 'Close demo',
                              onPressed: _tour.stop,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

/// The tour's window sits beside the lead story and never changes saved bounds.
class _TourStudioBounds implements TouchStudioBoundsPersistence {
  const _TourStudioBounds(this.viewport);

  final Size viewport;

  @override
  Future<Rect?> load() async {
    final width = (viewport.width * 0.38).clamp(360.0, 560.0);
    final height = (viewport.height - 250).clamp(420.0, 650.0);
    return Rect.fromLTWH(viewport.width - width - 28, 72, width, height);
  }

  @override
  Future<void> save(Rect bounds) async {}
}

/// A visible pointer and focus ring for scripted UI actions in a recording.
class _TourClickMarker extends StatelessWidget {
  const _TourClickMarker({
    required this.target,
    required this.label,
    this.color = const Color(0xFFDB2777),
    this.showCursor = true,
  });

  final Rect target;
  final String label;
  final Color color;
  final bool showCursor;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 650),
    curve: Curves.easeOutCubic,
    builder: (context, progress, _) {
      final center = target.center;
      final labelLeft = (center.dx - 80).clamp(
        12.0,
        MediaQuery.sizeOf(context).width - 180,
      );
      return Stack(
        children: [
          Positioned.fromRect(
            rect: target.inflate(5 + (1 - progress) * 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            left: labelLeft,
            top: (target.top - 43).clamp(8.0, double.infinity),
            child: Material(
              color: const Color(0xFF292333),
              borderRadius: BorderRadius.circular(20),
              elevation: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
          if (showCursor)
            Positioned(
              left: center.dx + (1 - progress) * 55 - 16,
              top: center.dy + (1 - progress) * 45 - 16,
              child: Transform.scale(
                scale: progress > 0.75 ? 1.2 : 1,
                child: Icon(
                  Icons.ads_click,
                  size: 32,
                  color: color,
                  shadows: const [Shadow(color: Colors.white, blurRadius: 7)],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _AiPromptDialog extends StatefulWidget {
  const _AiPromptDialog({required this.initialPrompt});

  final String initialPrompt;

  @override
  State<_AiPromptDialog> createState() => _AiPromptDialogState();
}

class _AiPromptDialogState extends State<_AiPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPrompt);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ask AI · A2UI layout'),
    content: SizedBox(
      width: 520,
      child: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 3,
        maxLines: 7,
        decoration: const InputDecoration(
          labelText: 'Visual direction',
          hintText: 'Describe the A2UI look you want',
          border: OutlineInputBorder(),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final value = _controller.text.trim();
          if (value.isNotEmpty) Navigator.pop(context, value);
        },
        child: const Text('Generate A2UI'),
      ),
    ],
  );
}
