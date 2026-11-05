import 'dart:convert';

import 'catalog.dart';
import 'model.dart';

/// Validates property edits and maintains a saved baseline plus undo/redo state.
///
/// Inputs must be JSON-serializable. Component IDs must be unique throughout the
/// snapshot; isolate surfaces in separate sessions when they reuse IDs.
final class EditableGenUiSession {
  EditableGenUiSession({
    required GenUiEditSnapshot initial,
    required this.registry,
  }) : _saved = _copySnapshot(initial),
       _current = _copySnapshot(initial);

  final EditableCatalogRegistry registry;
  GenUiEditSnapshot _saved;
  GenUiEditSnapshot _current;
  final List<GenUiEditSnapshot> _undo = [];
  final List<GenUiEditSnapshot> _redo = [];
  GenUiComponentSelection? _selection;

  /// A deep copy of the current messages, safe to modify outside the session.
  GenUiEditSnapshot get current => _copySnapshot(_current);
  GenUiComponentSelection? get selection => _selection;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  /// Whether current messages differ from the last saved baseline.
  bool get isDirty => !_sameMessages(_saved.messages, _current.messages);

  /// Returns a detached component copy with an unmodifiable outer map, or null.
  Map<String, Object?>? component(String componentId) {
    final value = _findComponent(_current.messages, componentId);
    return value == null
        ? null
        : Map.unmodifiable(_copyMessages([value]).single);
  }

  /// Selects an available, registered component and refreshes its revision.
  /// Throws [FormatException] when the component cannot be selected.
  void select(GenUiComponentSelection selection) {
    final component = _findComponent(_current.messages, selection.componentId);
    if (component == null ||
        component['component'] != selection.componentType) {
      throw const FormatException('The selected component is unavailable.');
    }
    if (registry.contractFor(selection.componentType) == null) {
      throw const FormatException('The selected component is not editable.');
    }
    _selection = selection.atRevision(_current.revision);
  }

  void clearSelection() => _selection = null;

  /// Applies all changes atomically after validation and clears redo history.
  /// Throws [FormatException] without changing state for a rejected patch.
  GenUiEditSnapshot apply(GenUiPropertyPatch patch) {
    if (patch.expectedRevision != _current.revision) {
      throw const FormatException('The UI definition changed before the edit.');
    }
    final component = _findComponent(_current.messages, patch.componentId);
    if (component == null) {
      throw const FormatException('The edited component no longer exists.');
    }
    final type = component['component'];
    if (type is! String) {
      throw const FormatException('The edited component has no type.');
    }
    final contract = registry.contractFor(type);
    if (contract == null) {
      throw const FormatException('The component is not editable.');
    }
    for (final entry in patch.changes.entries) {
      if (contract.protectedProperties.contains(entry.key)) {
        throw FormatException('Property ${entry.key} is protected.');
      }
      final property = contract.properties[entry.key];
      if (property == null || !property.accepts(entry.value)) {
        throw FormatException('Invalid editable property ${entry.key}.');
      }
    }
    if (patch.changes.isEmpty ||
        patch.changes.entries.every(
          (entry) => component[entry.key] == entry.value,
        )) {
      throw const FormatException('The edit did not change this component.');
    }

    final previous = _copySnapshot(_current);
    final messages = _copyMessages(_current.messages);
    final target = _findComponent(messages, patch.componentId)!;
    target.addAll(patch.changes);
    _undo.add(previous);
    _redo.clear();
    _current = GenUiEditSnapshot(
      revision: _current.revision + 1,
      messages: messages,
    );
    _refreshSelection();
    return current;
  }

  /// Restores the previous snapshot, including its revision; no-op if empty.
  GenUiEditSnapshot undo() {
    if (_undo.isEmpty) return current;
    _redo.add(_copySnapshot(_current));
    _current = _undo.removeLast();
    _refreshSelection();
    return current;
  }

  /// Restores the next snapshot from redo history; no-op if empty.
  GenUiEditSnapshot redo() {
    if (_redo.isEmpty) return current;
    _undo.add(_copySnapshot(_current));
    _current = _redo.removeLast();
    _refreshSelection();
    return current;
  }

  /// Restores the saved baseline and clears both history stacks.
  GenUiEditSnapshot cancel() {
    _current = _copySnapshot(_saved);
    _undo.clear();
    _redo.clear();
    _refreshSelection();
    return current;
  }

  /// Marks [persisted], or the current snapshot, as the saved baseline.
  /// Keeps history when newer edits still differ from that baseline.
  void markSaved([GenUiEditSnapshot? persisted]) {
    _saved = _copySnapshot(persisted ?? _current);
    if (!isDirty) {
      _undo.clear();
      _redo.clear();
    }
  }

  /// Replaces both saved and current state and clears undo/redo history.
  /// This is a full replacement; hosts must merge incremental updates first.
  GenUiEditSnapshot reload(GenUiEditSnapshot snapshot) {
    _saved = _copySnapshot(snapshot);
    _current = _copySnapshot(snapshot);
    _undo.clear();
    _redo.clear();
    _refreshSelection();
    return current;
  }

  void _refreshSelection() {
    final selected = _selection;
    if (selected == null) return;
    final component = _findComponent(_current.messages, selected.componentId);
    if (component == null || component['component'] != selected.componentType) {
      _selection = null;
    } else {
      _selection = selected.atRevision(_current.revision);
    }
  }
}

/// Checks that two definitions differ only in permitted property values.
/// Throws [FormatException] for structural, protected, or invalid changes.
void validateEditableTransition({
  required List<Map<String, Object?>> baseMessages,
  required List<Map<String, Object?>> editedMessages,
  required EditableCatalogRegistry registry,
}) {
  if (!_sameValue(
    _definitionSkeleton(baseMessages),
    _definitionSkeleton(editedMessages),
  )) {
    throw const FormatException(
      'An editable patch cannot change the surface structure.',
    );
  }
  final base = _componentIndex(baseMessages);
  final edited = _componentIndex(editedMessages);
  if (base.keys.toSet().difference(edited.keys.toSet()).isNotEmpty ||
      edited.keys.toSet().difference(base.keys.toSet()).isNotEmpty) {
    throw const FormatException(
      'An editable patch cannot add or remove components.',
    );
  }
  for (final id in base.keys) {
    final before = base[id]!;
    final after = edited[id]!;
    if (before['component'] != after['component']) {
      throw const FormatException(
        'An editable patch cannot change component types.',
      );
    }
    final type = before['component'] as String;
    final contract = registry.contractFor(type);
    final keys = {...before.keys, ...after.keys};
    for (final key in keys) {
      if (_sameValue(before[key], after[key])) continue;
      final property = contract?.properties[key];
      if (property == null ||
          contract!.protectedProperties.contains(key) ||
          !property.accepts(after[key])) {
        throw FormatException(
          'The edited transition changed protected property $key.',
        );
      }
    }
  }
}

Object? _definitionSkeleton(Object? value) {
  if (value is Map) {
    if (value['id'] is String && value['component'] is String) {
      return {'id': value['id'], 'component': value['component']};
    }
    return {
      for (final entry in value.entries)
        entry.key.toString(): _definitionSkeleton(entry.value),
    };
  }
  if (value is List) {
    return [for (final child in value) _definitionSkeleton(child)];
  }
  return value;
}

Map<String, Object?>? _findComponent(
  List<Map<String, Object?>> messages,
  String componentId,
) {
  Map<String, Object?>? result;
  void visit(Object? value) {
    if (result != null) return;
    if (value is Map) {
      if (value['id'] == componentId && value['component'] is String) {
        result = value.cast<String, Object?>();
        return;
      }
      for (final child in value.values) {
        visit(child);
      }
    } else if (value is List) {
      for (final child in value) {
        visit(child);
      }
    }
  }

  visit(messages);
  return result;
}

GenUiEditSnapshot _copySnapshot(GenUiEditSnapshot value) => GenUiEditSnapshot(
  revision: value.revision,
  messages: _copyMessages(value.messages),
);

List<Map<String, Object?>> _copyMessages(List<Map<String, Object?>> messages) =>
    (jsonDecode(jsonEncode(messages)) as List<Object?>)
        .whereType<Map>()
        .map((value) => value.cast<String, Object?>())
        .toList(growable: false);

bool _sameMessages(
  List<Map<String, Object?>> left,
  List<Map<String, Object?>> right,
) => jsonEncode(left) == jsonEncode(right);

bool _sameValue(Object? left, Object? right) =>
    jsonEncode(left) == jsonEncode(right);

Map<String, Map<String, Object?>> _componentIndex(
  List<Map<String, Object?>> messages,
) {
  final result = <String, Map<String, Object?>>{};
  void visit(Object? value) {
    if (value is Map) {
      if (value['id'] is String && value['component'] is String) {
        final component = value.cast<String, Object?>();
        final id = component['id']! as String;
        if (result.containsKey(id)) {
          throw const FormatException(
            'The definition has duplicate component IDs.',
          );
        }
        result[id] = component;
      }
      for (final child in value.values) {
        visit(child);
      }
    } else if (value is List) {
      for (final child in value) {
        visit(child);
      }
    }
  }

  visit(messages);
  return result;
}
