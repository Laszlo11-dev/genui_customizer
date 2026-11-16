part of 'reader_app.dart';

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

extension _ReaderDemoTour on _ReaderPageState {
  void _onTourChanged() {
    if (mounted) _updateDemoState(() {});
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
    _updateDemoState(() {
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
    _updateDemoState(() {
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
    _updateDemoState(() => _demoUser = user);
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
    _updateDemoState(() {
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
