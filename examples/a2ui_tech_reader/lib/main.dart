import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/basic_catalog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'a2ui_builder.dart';
import 'models.dart';
import 'news_gallery.dart';
import 'news_filter.dart';
import 'rss_service.dart';

void main() => runApp(const TechReaderApp());

class TechReaderApp extends StatelessWidget {
  const TechReaderApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'A2UI Tech Reader',
    home: ReaderPage(),
  );
}

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key});
  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage>
    with SingleTickerProviderStateMixin {
  final _rss = RssService();
  final _sourceController = TextEditingController(text: feedPresets.first.url);
  final _searchController = TextEditingController();
  late MessageProcessor<ComponentImplementation> _processor;
  SurfaceModel<ComponentImplementation>? _surface;
  Occasion _occasion = Occasion.auto;
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
    _processor = _newProcessor();
    // Show a real A2UI surface immediately, even before network responds.
    _render();
    _refresh();
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
    // Keep actions tied to the article list that produced this surface.
    final articles = _renderedArticles;
    final processor = MessageProcessor<ComponentImplementation>(
      catalogs: [basicCatalog(), newsGalleryCatalog],
    );
    processor.model.onSurfaceCreated.subscribe((created) {
      if (!mounted) return;
      setState(() => _surface = created);
    });
    processor.model.onAction.subscribe((action) {
      final match = RegExp(r'^open_(\d+)$').firstMatch(action.name);
      if (match == null) return;
      final index = int.tryParse(match.group(1)!);
      if (index == null || index >= articles.length) return;
      final url = articles[index].link;
      if (url.scheme == 'https' || url.scheme == 'http') {
        launchUrl(url, mode: LaunchMode.externalApplication);
      }
    });
    return processor;
  }

  void _render() {
    final query = _searchController.text.trim().toLowerCase();
    _renderedArticles = _articles.where((article) {
      if (_hidePolitical && isPoliticalNews(article)) return false;
      return query.isEmpty ||
          '${article.title} ${article.summary} ${article.source}'
              .toLowerCase()
              .contains(query);
    }).toList();
    _messages = NewsA2uiBuilder.build(
      _renderedArticles,
      _active,
      compact: _compact,
      loading: _loading,
      error: _error,
    );
    final old = _processor;
    _processor = _newProcessor();
    _surface = null;
    old.dispose();
    try {
      _processor.processMessages(_messages);
    } catch (e) {
      setState(() => _error = 'A2UI renderer: $e');
    }
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
    final previous = _active;
    setState(() => _occasion = value);
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

  @override
  void dispose() {
    _requestId++;
    _feedTransition.dispose();
    _rss.dispose();
    _processor.dispose();
    _sourceController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = styleFor(_active);
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: style.accent,
        surface: style.surface,
      ),
      scaffoldBackgroundColor: style.background,
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: style.ink,
        displayColor: style.ink,
      ),
      cardTheme: CardThemeData(
        color: style.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: style.ink.withValues(alpha: 0.09)),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      appBarTheme: AppBarTheme(backgroundColor: style.background),
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
              onPressed: _showJson,
              tooltip: 'View A2UI JSON',
              icon: const Icon(Icons.data_object),
            ),
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
                          color: style.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Live RSS stories · rendered by A2UI',
                        style: TextStyle(
                          color: style.ink.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
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
                              (p) => DropdownMenuItem(
                                value: p.name,
                                child: Text(p.name),
                              ),
                            )
                            .toList(),
                        onChanged: _choosePreset,
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: DropdownButtonFormField<Occasion>(
                        initialValue: _occasion,
                        decoration: const InputDecoration(
                          labelText: 'Occasion / A2UI layout',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: Occasion.values
                            .map(
                              (o) => DropdownMenuItem(
                                value: o,
                                child: Text(o.label),
                              ),
                            )
                            .toList(),
                        onChanged: _changeOccasion,
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
                  onChanged: (_) => _render(),
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
