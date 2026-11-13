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
import 'models.dart';
import 'news_gallery.dart';
import 'news_touch.dart';
import 'news_filter.dart';
import 'rss_service.dart';
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

void main() {
  final key = _definedApiKey.isNotEmpty
      ? _definedApiKey
      : (runtime_key.geminiKeyFromProcess() ?? '');
  runApp(TechReaderApp(apiKey: key.trim()));
}

class TechReaderApp extends StatelessWidget {
  const TechReaderApp({super.key, this.apiKey = ''});
  final String apiKey;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'A2UI Tech Reader',
    home: ReaderPage(apiKey: apiKey),
  );
}

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, this.apiKey = ''});
  final String apiKey;
  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage>
    with SingleTickerProviderStateMixin {
  final _rss = RssService();
  GeminiLayoutService? _aiService;
  AiLayout? _aiLayout;
  String? _aiError;
  String _aiPrompt = 'Holidays at Sea';
  int _aiRequestId = 0;
  final _sourceController = TextEditingController(text: feedPresets.first.url);
  final _searchController = TextEditingController();
  late MessageProcessor<ComponentImplementation> _processor;
  late final GenUiTouchController _touch;
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
  bool _hasSavedAiLayout = false;
  SurfaceModel<ComponentImplementation>? _surface;
  Occasion _occasion = Occasion.auto;
  _DemoUser _demoUser = _DemoUser.tenantEditor;
  String _source = feedPresets.first.name;
  List<NewsItem> _articles = [];
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
    _processor = _newProcessor();
    _touch.attachProcessor(_processor);
    _seedUsers = seedDemoLocalConfigurations(_localStore).catchError((
      Object error,
    ) {
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
      final available =
          (await _remoteStore.load(Occasion.askAi.name))?.data['aiLayout']
              is Map;
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
    final storedRemote = await _remoteStore.load(edition.name);
    final legacyProfile = storedRemote == null && edition == Occasion.everyday
        ? await const ReaderTouchStorage().load()
        : null;
    final remote =
        storedRemote ??
        TouchConfiguration(
          id: edition.name,
          name: edition.label,
          profile: legacyProfile ?? const TouchProfile(),
          data: {
            'occasion': edition.name,
            'style': styleFor(edition).toJson(),
            'palette': paletteFor(edition).toJson(),
            'composition': compositionFor(edition).toJson(),
          },
        );
    final local = user == _DemoUser.tenantEditor
        ? null
        : await _localStore.load(user.name, 'preferences');
    if (!mounted || edition != _active || user != _demoUser) return false;
    final data = remote.data;
    _remoteConfiguration = remote;
    _occasionStyle = data['style'] is Map
        ? PortalStyle.fromJson((data['style'] as Map).cast<String, Object?>())
        : styleFor(edition);
    _occasionPalette = data['palette'] is Map
        ? OccasionPalette.fromJson(
            (data['palette'] as Map).cast<String, Object?>(),
          )
        : paletteFor(edition);
    _occasionComposition = data['composition'] is Map
        ? OccasionComposition.fromJson(
            (data['composition'] as Map).cast<String, Object?>(),
          )
        : compositionFor(edition);
    if (edition == Occasion.askAi && data['aiLayout'] is Map) {
      _aiLayout = AiLayout.fromJson(
        (data['aiLayout'] as Map).cast<String, Object?>(),
      );
      _aiPrompt = data['aiPrompt'] as String? ?? _aiPrompt;
    }
    _touch.useConfigurations(
      remote: remote.profile,
      local: local?.profile ?? const TouchProfile(),
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
                      profile: const TouchProfile(),
                    ))
                .copyWith(profile: profile),
          );
        }
      },
    );
    return true;
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Occasion saved')));
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
    showGenUiTouchStudio(
      context: context,
      controller: _touch,
      surfaceId: NewsA2uiBuilder.surfaceId,
      galleryOnly: true,
      onGalleryChanged: _render,
    );
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
        launchUrl(url, mode: LaunchMode.externalApplication);
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
    setState(() {
      _loading = true;
      _error = null;
    });
    _render();
    try {
      final result = await _rss.load(_sourceController.text);
      if (!mounted || id != _requestId) return;
      setState(() {
        _articles = result;
        _loading = false;
      });
      _render();
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _error = kIsWeb
            ? '$e. This feed may block browser requests (CORS). Try another source or a same-origin feed gateway.'
            : '$e';
      });
      _render();
    }
  }

  void _choosePreset(String? name) {
    if (name == null) return;
    final preset = feedPresets.firstWhere((p) => p.name == name);
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
    final query = _searchController.text.trim().toLowerCase();
    return _articles
        .where((article) {
          if (_hidePolitical && isPoliticalNews(article)) return false;
          return query.isEmpty ||
              '${article.title} ${article.summary} ${article.source}'
                  .toLowerCase()
                  .contains(query);
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

  Widget _buildTouchDemoPanel() => Card(
    child: ExpansionTile(
      key: const Key('touch-demo-panel'),
      initiallyExpanded: true,
      title: const Text('Touch demo'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 390,
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
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
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<Occasion>(
                isExpanded: true,
                initialValue: _occasion,
                decoration: const InputDecoration(
                  labelText: 'Occasion / A2UI layout',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: Occasion.values.map((o) {
                  final locked =
                      o == Occasion.askAi &&
                      _aiService == null &&
                      !_hasSavedAiLayout;
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
                              Text(
                                o.label,
                                style: TextStyle(color: disabledColor),
                              ),
                            ],
                          )
                        : Text(o.label),
                  );
                }).toList(),
                onChanged: _changeOccasion,
              ),
            ),
            Tooltip(
              message: 'Open GenUI Touch',
              child: OutlinedButton.icon(
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
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(_demoUser.description),
        ),
      ],
    ),
  );

  Widget _buildFeedControlsPanel(Color ink) => ExpansionTile(
    key: const Key('feed-controls-panel'),
    initiallyExpanded: false,
    minTileHeight: 40,
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(top: 8, bottom: 12),
    shape: const Border(),
    collapsedShape: const Border(),
    iconColor: ink.withValues(alpha: 0.7),
    collapsedIconColor: ink.withValues(alpha: 0.7),
    title: Text(
      'Live RSS stories · rendered by A2UI',
      style: TextStyle(color: ink.withValues(alpha: 0.7)),
    ),
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
              initialValue: feedPresets.any((p) => p.name == _source)
                  ? _source
                  : null,
              decoration: const InputDecoration(
                labelText: 'RSS preset',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: feedPresets
                  .map(
                    (p) => DropdownMenuItem(value: p.name, child: Text(p.name)),
                  )
                  .toList(),
              onChanged: _choosePreset,
            ),
          ),
          Tooltip(
            message:
                'Uses feed tags and clear title signals. Technology policy stays visible.',
            child: FilterChip(
              selected: _hidePolitical,
              label: const Text('Hide politics & war'),
              onSelected: (value) {
                setState(() => _hidePolitical = value);
                _render();
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _searchController,
        onChanged: (_) {
          _render();
        },
        decoration: const InputDecoration(
          labelText: 'Search stories',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
          isDense: true,
        ),
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
    _feedTransition.dispose();
    _rss.dispose();
    _touch.dispose();
    _processor.dispose();
    _sourceController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = _active == Occasion.askAi ? _aiLayout : null;
    final style = layout == null
        ? (_occasionStyle ?? styleFor(_active))
        : styleForAi(layout);
    final pageBackground = _pageBackground(style);
    final pageInk = pageBackground == style.background
        ? style.ink
        : pageBackground.computeLuminance() < 0.18
        ? Colors.white
        : const Color(0xFF192336);
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
              Icon(Icons.auto_stories_outlined, color: style.accent),
              const SizedBox(width: 10),
              const Text(
                'A2UI / TECH READER',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _loading ? null : _refresh,
              tooltip: 'Refresh RSS',
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 56),
              children: [
                const SizedBox(height: 12),
                _buildTouchDemoPanel(),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, ?current],
                  ),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.08),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Column(
                    key: ValueKey(_active),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        style.kicker,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: style.accent,
                          letterSpacing: 2,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        style.headline,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 46,
                          letterSpacing: -1.8,
                          color: pageInk,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildFeedControlsPanel(pageInk),
                const SizedBox(height: 16),
                // The article cards, headings, actions, and occasion-specific
                // content below are produced by the official A2UI renderer.
                FadeTransition(
                  opacity: _feedOpacity,
                  child: SlideTransition(
                    position: _feedOffset,
                    child: _surface != null
                        ? A2uiSurface(
                            key: ObjectKey(_surface),
                            surface: _surface!,
                          )
                        : const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Loading A2UI surface…'),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Articles belong to their respective publishers. Open the original link to read. No scraping or article republishing.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
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
