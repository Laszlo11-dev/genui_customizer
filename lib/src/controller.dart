import 'dart:async';

import 'package:genui_customizer/src/core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// Chooses the pointer gesture that opens an editable component.
enum EditTrigger { adaptive, tripleClick, longPress }

/// Host-supplied controls for editing, AI proposals, and saving.
final class EditableGenUiPermissions {
  const EditableGenUiPermissions({
    this.canEdit = true,
    this.canUseAi = true,
    this.canSave = true,
  });

  final bool canEdit;
  final bool canUseAi;
  final bool canSave;
}

/// Coordinates selection, edits, history, storage, and renderer notifications.
final class EditableGenUiController extends ChangeNotifier {
  EditableGenUiController({
    required GenUiEditSnapshot initial,
    required this.registry,
    this.composer,
    this.storage,
    this.permissions = const EditableGenUiPermissions(),
    this.trigger = EditTrigger.adaptive,
    this.onSnapshotChanged,
    this.onEditorRequested,
  }) : _session = EditableGenUiSession(initial: initial, registry: registry);

  final EditableCatalogRegistry registry;
  final EditableGenUiComposer? composer;
  final EditableGenUiStorage? storage;
  final EditableGenUiPermissions permissions;
  final EditTrigger trigger;
  final void Function(GenUiEditSnapshot snapshot)? onSnapshotChanged;
  VoidCallback? onEditorRequested;
  final EditableGenUiSession _session;
  final Map<String, EditablePropertyEditorDefinition> _sharedEditors = {};
  final Map<int, List<GenUiComponentSelection>> _downCandidates = {};
  final Map<int, List<GenUiComponentSelection>> _tapCandidates = {};
  final Map<int, Offset> _pointerOrigins = {};
  final Map<int, Timer> _longPressTimers = {};
  DateTime? _lastTapAt;
  Offset? _lastTapPosition;
  String? _lastTapComponentId;
  int _tapCount = 0;
  bool _busy = false;
  int _snapshotGeneration = 0;
  int _baselineGeneration = 0;
  String? _error;

  GenUiEditSnapshot get snapshot => _session.current;
  GenUiComponentSelection? get selection => _session.selection;
  bool get canUndo => _session.canUndo;
  bool get canRedo => _session.canRedo;
  bool get isDirty => _session.isDirty;
  bool get busy => _busy;
  String? get error => _error;

  Map<String, Object?>? component(String componentId) =>
      _session.component(componentId);

  EditablePropertyEditorDefinition? editorFor(String type) =>
      _sharedEditors[type] ?? registry.editorFor(type);

  void setSharedEditors(Map<String, EditablePropertyEditorDefinition> editors) {
    _sharedEditors
      ..clear()
      ..addAll(editors);
    notifyListeners();
  }

  bool canSelect(String componentType) =>
      permissions.canEdit && registry.contractFor(componentType) != null;

  void open(GenUiComponentSelection selection) {
    select(selection);
    onEditorRequested?.call();
  }

  void select(GenUiComponentSelection selection) {
    if (!permissions.canEdit) return;
    _session.select(selection);
    _error = null;
    notifyListeners();
  }

  void close() {
    _session.clearSelection();
    _error = null;
    notifyListeners();
  }

  /// Applies a local edit to the selection and reports validation errors in [error].
  void apply(Map<String, Object?> changes) {
    final selected = selection;
    if (selected == null) return;
    try {
      _session.apply(
        GenUiPropertyPatch(
          expectedRevision: snapshot.revision,
          componentId: selected.componentId,
          changes: changes,
          origin: GenUiEditOrigin.manual,
        ),
      );
      _error = null;
      _publish();
    } on FormatException catch (error) {
      _error = error.message;
      notifyListeners();
    }
  }

  Future<void> prompt(String instruction) async {
    final selected = selection;
    final ai = composer;
    if (_busy || !permissions.canUseAi || selected == null || ai == null)
      return;
    final normalized = instruction.trim();
    if (normalized.isEmpty) return;
    final contract = registry.contractFor(selected.componentType)!;
    final requestedSnapshot = snapshot;
    final generation = _snapshotGeneration;
    _setBusy(true);
    try {
      final patch = await ai.propose(
        snapshot: requestedSnapshot,
        selection: selected,
        instruction: normalized,
        constraints: GenUiEditConstraints(
          componentType: contract.type,
          editableProperties: {
            for (final property in contract.properties.values)
              property.name: {
                'type': property.type.name,
                if (property.enumValues.isNotEmpty) 'enum': property.enumValues,
              },
          },
          protectedProperties: contract.protectedProperties,
        ),
      );
      if (patch.componentId != selected.componentId) {
        throw const FormatException('The AI edit targeted another component.');
      }
      if (patch.expectedRevision != requestedSnapshot.revision ||
          generation != _snapshotGeneration ||
          selection?.surfaceId != selected.surfaceId ||
          selection?.componentId != selected.componentId) {
        throw const FormatException(
          'The UI changed before the AI edit returned.',
        );
      }
      _session.apply(patch);
      _error = null;
      _publish();
    } on Object catch (error) {
      _error = error is FormatException
          ? error.message
          : 'The AI edit could not be applied.';
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  void undo() {
    _session.undo();
    _publish();
  }

  void redo() {
    _session.redo();
    _publish();
  }

  void cancel() {
    _session.cancel();
    _publish();
  }

  Future<void> save() async {
    if (_busy || !permissions.canSave || storage == null || !isDirty) return;
    final persisted = snapshot;
    final baselineGeneration = _baselineGeneration;
    _setBusy(true);
    try {
      await storage!.save(persisted);
      if (baselineGeneration == _baselineGeneration) {
        _session.markSaved(persisted);
      }
      _error = null;
      notifyListeners();
    } on Object catch (error) {
      _error = error is FormatException
          ? error.message
          : 'The edited UI could not be saved.';
      notifyListeners();
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> reload() async {
    final adapter = storage;
    if (_busy || adapter == null) return;
    _setBusy(true);
    try {
      final loaded = await adapter.load();
      if (loaded != null) {
        _baselineGeneration++;
        _session.reload(loaded);
        _error = null;
        _publish();
      }
    } on Object catch (error) {
      _error = error is FormatException
          ? error.message
          : 'The edited UI could not be reloaded.';
      notifyListeners();
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  /// Replaces the editable definition when an agent generates a new surface.
  void setSurfaceSnapshot(GenUiEditSnapshot value) {
    _baselineGeneration++;
    _session.reload(value);
    _error = null;
    _publish();
  }

  void handlePointerDown(
    PointerDownEvent event,
    GenUiComponentSelection candidate,
  ) {
    if (_allowsTripleClick(event.kind) &&
        event.buttons == kPrimaryMouseButton) {
      final candidates = _tapCandidates.putIfAbsent(event.pointer, () => []);
      candidates.add(candidate);
      if (candidates.length == 1) {
        scheduleMicrotask(() => _registerTap(event.pointer, event.position));
      }
    }
    if (!_allowsLongPress(event.kind)) return;
    final candidates = _downCandidates.putIfAbsent(event.pointer, () => []);
    candidates.add(candidate);
    _pointerOrigins[event.pointer] = event.position;
    if (candidates.length == 1) {
      scheduleMicrotask(() => _startLongPress(event.pointer));
    }
  }

  void handlePointerMove(PointerMoveEvent event) {
    final origin = _pointerOrigins[event.pointer];
    if (origin != null && (event.position - origin).distance > 12) {
      _cancelPointer(event.pointer);
    }
  }

  void handlePointerUp(
    PointerUpEvent event,
    GenUiComponentSelection candidate,
  ) {
    _longPressTimers.remove(event.pointer)?.cancel();
    _pointerOrigins.remove(event.pointer);
    _downCandidates.remove(event.pointer);
  }

  void handlePointerCancel(PointerCancelEvent event) =>
      _cancelPointer(event.pointer);

  void _startLongPress(int pointer) {
    final candidates = _downCandidates[pointer];
    if (candidates == null || candidates.isEmpty) return;
    final candidate = _deepest(candidates);
    _longPressTimers[pointer]?.cancel();
    _longPressTimers[pointer] = Timer(
      const Duration(milliseconds: 550),
      () => open(candidate),
    );
  }

  void _registerTap(int pointer, Offset position) {
    final candidates = _tapCandidates.remove(pointer);
    if (candidates == null || candidates.isEmpty) return;
    final candidate = _deepest(candidates);
    final now = DateTime.now();
    final sameTarget = _lastTapComponentId == candidate.componentId;
    final soonEnough =
        _lastTapAt != null && now.difference(_lastTapAt!).inMilliseconds <= 500;
    final closeEnough =
        _lastTapPosition != null &&
        (position - _lastTapPosition!).distance <= 12;
    _tapCount = sameTarget && soonEnough && closeEnough ? _tapCount + 1 : 1;
    _lastTapAt = now;
    _lastTapPosition = position;
    _lastTapComponentId = candidate.componentId;
    if (_tapCount == 3) {
      _tapCount = 0;
      open(candidate);
    }
  }

  GenUiComponentSelection _deepest(List<GenUiComponentSelection> candidates) {
    // Nested Listener callbacks arrive child-first. Preserve that order while
    // removing duplicate callbacks from rebuilt regions.
    return candidates.first;
  }

  bool _allowsTripleClick(PointerDeviceKind kind) =>
      (trigger == EditTrigger.adaptive || trigger == EditTrigger.tripleClick) &&
      kind != PointerDeviceKind.touch;

  bool _allowsLongPress(PointerDeviceKind kind) =>
      (trigger == EditTrigger.adaptive || trigger == EditTrigger.longPress) &&
      kind != PointerDeviceKind.mouse;

  void _cancelPointer(int pointer) {
    _longPressTimers.remove(pointer)?.cancel();
    _pointerOrigins.remove(pointer);
    _downCandidates.remove(pointer);
    _tapCandidates.remove(pointer);
  }

  void _publish() {
    _snapshotGeneration++;
    onSnapshotChanged?.call(snapshot);
    notifyListeners();
  }

  void _setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final timer in _longPressTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}
