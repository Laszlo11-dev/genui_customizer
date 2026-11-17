import 'dart:async';

import 'package:flutter/foundation.dart';

/// A cue is an app action at a specific point in a scene. The same script can
/// be played on a timer for capture or advanced by the viewer during onboarding.
enum DemoAction {
  showEveryday,
  showFred,
  showChristmas,
  showWinterGames,
  showJoe,
  showEmily,
  openStoryStudio,
  makeButtonPink,
  closeStudio,
}

class DemoCue {
  const DemoCue(this.at, this.action);

  final Duration at;
  final DemoAction action;
}

class DemoScene {
  const DemoScene({
    required this.duration,
    required this.title,
    required this.narration,
    this.cues = const [],
  });

  final Duration duration;
  final String title;
  final String narration;
  final List<DemoCue> cues;
}

/// The one-minute intro opens on Winter Games, then shows editions and a Touch edit.
const introScript = <DemoScene>[
  DemoScene(
    duration: Duration(seconds: 8),
    title: 'One feed, three looks',
    narration: 'One feed. Watch the page change instantly for Joe, then Emily.',
    cues: [
      DemoCue(Duration(seconds: 1), DemoAction.showJoe),
      DemoCue(Duration(seconds: 4), DemoAction.showEmily),
    ],
  ),
  DemoScene(
    duration: Duration(seconds: 7),
    title: 'Stories from RSS',
    narration: 'The stories and links come from RSS. A2UI renders the news page, and GenUI Touch lets people shape its appearance.',
    cues: [
      DemoCue(Duration.zero, DemoAction.showFred),
      DemoCue(Duration.zero, DemoAction.showEveryday),
    ],
  ),
  DemoScene(
    duration: Duration(seconds: 10),
    title: 'Christmas to Winter Games',
    narration: 'The same stories take on a Christmas edition, then a Winter Games layout with a new palette and composition.',
    cues: [
      DemoCue(Duration.zero, DemoAction.showChristmas),
      DemoCue(Duration(seconds: 5), DemoAction.showWinterGames),
    ],
  ),
  DemoScene(
    duration: Duration(seconds: 12),
    title: 'Joe and Emily',
    narration: 'Joe chooses larger text and stronger contrast. Emily prefers pink. Both see the same stories in their own style.',
    cues: [
      DemoCue(Duration.zero, DemoAction.showJoe),
      DemoCue(Duration(seconds: 6), DemoAction.showEmily),
    ],
  ),
  DemoScene(
    duration: Duration(seconds: 15),
    title: 'Emily changes the button',
    narration: 'Emily opens Touch Studio and changes the Read original button to pink. The new color appears immediately on the story cards.',
    cues: [
      DemoCue(Duration.zero, DemoAction.openStoryStudio),
      DemoCue(Duration(seconds: 6), DemoAction.makeButtonPink),
    ],
  ),
  DemoScene(
    duration: Duration(seconds: 8),
    title: 'Try GenUI Touch',
    narration: 'Choose a look, then make it your own with GenUI Touch.',
    cues: [DemoCue(Duration.zero, DemoAction.closeStudio)],
  ),
];

class DemoTourController extends ChangeNotifier {
  DemoTourController({
    required this.scenes,
    required this.onStart,
    required this.onAction,
    required this.onStop,
  });

  final List<DemoScene> scenes;
  final Future<void> Function() onStart;
  final Future<void> Function(DemoAction) onAction;
  final Future<void> Function() onStop;

  Timer? _timer;
  Duration _elapsed = Duration.zero;
  int _sceneIndex = -1;
  int _nextCue = 0;
  bool _busy = false;
  bool _playing = false;
  bool _finished = false;

  int get sceneIndex => _sceneIndex;
  DemoScene? get scene => _sceneIndex < 0 ? null : scenes[_sceneIndex];
  bool get active => _sceneIndex >= 0;
  bool get playing => _playing;
  bool get ended => _finished;

  Future<void> replay() async {
    await stop();
    await start();
  }

  Future<void> start() async {
    if (active || _busy) return;
    _busy = true;
    try {
      await onStart();
      _sceneIndex = 0;
      _nextCue = 0;
      _elapsed = Duration.zero;
      _finished = false;
      _playing = true;
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (_playing) {
          _elapsed += const Duration(milliseconds: 100);
          _tick();
        }
      });
      notifyListeners();
      await _tick();
    } finally {
      _busy = false;
    }
  }

  void pause() {
    _playing = false;
    notifyListeners();
  }

  void resume() {
    if (!active) return;
    _playing = true;
    notifyListeners();
  }

  Future<void> next() async {
    if (!active || _busy) return;
    _busy = true;
    try {
      // A manual advance still performs the scene's pending actions.
      final cues = scene!.cues;
      while (_nextCue < cues.length) {
        await onAction(cues[_nextCue++].action);
      }
      await _advance();
    } finally {
      _busy = false;
    }
  }

  Future<void> _tick() async {
    if (!active || !_playing || _busy) return;
    _busy = true;
    try {
      final current = scene!;
      while (_nextCue < current.cues.length &&
          _elapsed >= current.cues[_nextCue].at) {
        await onAction(current.cues[_nextCue++].action);
      }
      if (_elapsed >= current.duration) await _advance();
    } finally {
      _busy = false;
    }
  }

  Future<void> _advance() async {
    if (_sceneIndex + 1 == scenes.length) {
      _finished = true;
      pause();
      return;
    }
    _sceneIndex++;
    _nextCue = 0;
    _elapsed = Duration.zero;
    notifyListeners();
    final cues = scene!.cues;
    while (_nextCue < cues.length && cues[_nextCue].at == Duration.zero) {
      await onAction(cues[_nextCue++].action);
    }
  }

  Future<void> stop() async {
    if (!active) return;
    _timer?.cancel();
    _timer = null;
    _playing = false;
    _finished = false;
    _sceneIndex = -1;
    notifyListeners();
    await onStop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
