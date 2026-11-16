import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/basic_catalog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:genui_customizer/genui_customizer.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:a2ui_tech_reader/a2ui/a2ui_builder.dart';
import 'package:a2ui_tech_reader/a2ui/ai_layout.dart';
import 'package:a2ui_tech_reader/demo/demo_feed.dart';
import 'package:a2ui_tech_reader/demo/demo_tour.dart';

import 'models.dart';

import 'package:a2ui_tech_reader/news/news_gallery.dart';
import 'package:a2ui_tech_reader/news/news_touch.dart';
import 'package:a2ui_tech_reader/rss/news_filter.dart';
import 'package:a2ui_tech_reader/rss/rss_service.dart';
import 'package:a2ui_tech_reader/news/readable_color.dart';

part 'demo/reader_demo.dart';

const _demoPanelSurface = Color(0xFF222A3A);
const _demoPanelHeader = Color(0xFF151D2B);
const _demoPanelAccent = Color(0xFF9DABFF);
const _demoPanelInk = Color(0xFFF3F6FF);

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
  void _updateDemoState(VoidCallback update) => setState(update);

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
  Occasion _occasion = Occasion.everyday;
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

  Occasion get _active => _occasion;

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
    final isDemoFeed =
        _source == demoFeedPreset.name && requestedSource.isEmpty;
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
      final result = isDemoFeed
          ? demoRssStories()
          : await _rss.load(requestedSource, source: presetSource);
      if (!mounted || id != _requestId) return;
      setState(() {
        _articles = result;
        _articlesSource = isDemoFeed
            ? demoFeedPreset.name
            : presetSource ?? requestedSource;
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

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'GenUI Touch',
      children: [
        const Text('Make generated UI your own.'),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () =>
                launchUrl(Uri.https('pub.dev', '/packages/genui_customizer')),
            icon: const Icon(Icons.open_in_new),
            label: const Text('pub.dev package'),
          ),
        ),
      ],
    );
  }

  Widget _buildOccasionPanel() => Column(
    key: const Key('occasion-panel'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ConstrainedBox(
        key: const Key('tour-occasion-picker'),
        constraints: const BoxConstraints(maxWidth: 390),
        child: DropdownButtonFormField<Occasion>(
          key: ValueKey(_occasion),
          isExpanded: true,
          initialValue: _occasion,
          dropdownColor: const Color(0xFF30394A),
          style: const TextStyle(color: _demoPanelInk, fontSize: 15),
          decoration: const InputDecoration(
            labelText: 'Remote',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: Occasion.values.map((o) {
            final locked =
                o == Occasion.askAi && _aiService == null && !_hasSavedAiLayout;
            const disabledColor = Color(0xFF91A0BC);
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

  Widget _buildUserPanel({required bool showActions}) {
    final actionStyle = OutlinedButton.styleFrom(
      foregroundColor: _demoPanelInk,
      side: const BorderSide(color: Color(0xFF75829B)),
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
    final actions = <Widget>[
      Tooltip(
        message: 'Open GenUI Touch',
        child: OutlinedButton.icon(
          key: const Key('tour-touch-button'),
          onPressed: _touchReady ? _openTouchStudio : null,
          style: actionStyle,
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('Touch'),
        ),
      ),
      if (_demoUser == _DemoUser.tenantEditor)
        Tooltip(
          message: 'Save occasion',
          child: OutlinedButton.icon(
            onPressed: _touchReady ? _saveOccasion : null,
            style: actionStyle,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save'),
          ),
        ),
      OutlinedButton.icon(
        key: const Key('tour-debug-button'),
        onPressed: _showJson,
        style: actionStyle,
        icon: const Icon(Icons.data_object, size: 18),
        label: const Text('Debug'),
      ),
      OutlinedButton.icon(
        key: const Key('tour-about-button'),
        onPressed: _showAbout,
        style: actionStyle,
        icon: const Icon(Icons.info_outline, size: 18),
        label: const Text('About'),
      ),
    ];
    return Column(
      key: const Key('user-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
              dropdownColor: const Color(0xFF30394A),
              style: const TextStyle(color: _demoPanelInk, fontSize: 15),
              decoration: const InputDecoration(
                labelText: 'Local',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              selectedItemBuilder: (context) => [
                for (final user in _DemoUser.values)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(user.label),
                  ),
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
                            style: const TextStyle(color: Color(0xFFB8C5DD)),
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
        if (showActions) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: actions),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _demoUser.description,
            style: const TextStyle(color: Color(0xFFB8C5DD)),
          ),
        ),
      ],
    );
  }

  Widget _buildDemoPanels({required bool actionsInHeader}) {
    final panelTheme = Theme.of(context).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _demoPanelAccent,
        brightness: Brightness.dark,
        surface: _demoPanelSurface,
      ),
      textTheme: ThemeData.dark(useMaterial3: true).textTheme,
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF30394A),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF75829B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _demoPanelAccent, width: 1.5),
        ),
      ),
    );
    return Theme(
      data: panelTheme,
      child: Card(
        elevation: 16,
        shadowColor: Colors.black.withValues(alpha: 0.55),
        color: _demoPanelSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(),
        child: ExpansionTile(
          key: const Key('touch-demo-panel'),
          initiallyExpanded: true,
          backgroundColor: _demoPanelSurface,
          collapsedBackgroundColor: _demoPanelSurface,
          dense: true,
          minTileHeight: 40,
          visualDensity: VisualDensity.compact,
          onExpansionChanged: (expanded) =>
              setState(() => _demoExpanded = expanded),
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: EdgeInsets.zero,
          showTrailingIcon: false,
          title: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: _demoPanelHeader,
            child: Row(
              children: [
                Container(width: 3, height: 18, color: _demoPanelAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Touch demo',
                    style: const TextStyle(
                      color: _demoPanelInk,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (actionsInHeader) ...[
                  IconButton(
                    key: const Key('tour-touch-button'),
                    onPressed: _touchReady ? _openTouchStudio : null,
                    tooltip: 'Open GenUI Touch',
                    color: _demoPanelInk,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.tune, size: 18),
                  ),
                  IconButton(
                    key: const Key('tour-debug-button'),
                    onPressed: _showJson,
                    tooltip: 'Debug',
                    color: _demoPanelInk,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.data_object, size: 18),
                  ),
                  IconButton(
                    key: const Key('tour-about-button'),
                    onPressed: _showAbout,
                    tooltip: 'About',
                    color: _demoPanelInk,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.info_outline, size: 18),
                  ),
                  if (_demoUser == _DemoUser.tenantEditor)
                    IconButton(
                      onPressed: _touchReady ? _saveOccasion : null,
                      tooltip: 'Save occasion',
                      color: _demoPanelInk,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.save_outlined, size: 18),
                    ),
                ],
                Icon(
                  _demoExpanded ? Icons.expand_less : Icons.expand_more,
                  color: _demoPanelInk,
                ),
              ],
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              color: _demoPanelSurface,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildOccasionPanel(),
                  const SizedBox(height: 14),
                  _buildUserPanel(showActions: !actionsInHeader),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
      if (_source == demoFeedPreset.name)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Curated A2UI, Flutter, and Touch reading list. '
            'The links open the original articles and package pages.',
          ),
        )
      else
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
            final wide = constraints.maxWidth >= 1120;
            final feed = ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 56),
              children: [
                SizedBox(height: wide ? 4 : 12),
                if (!wide) ...[
                  _buildDemoPanels(actionsInHeader: true),
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
                      ? 'Curated RSS snapshot · Read original opens each source page.'
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
                      width: 320,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                        child: _buildDemoPanels(actionsInHeader: false),
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
