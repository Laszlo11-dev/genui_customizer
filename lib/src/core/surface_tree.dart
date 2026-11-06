import 'model.dart';

/// A component as it appears in an A2UI surface, independent of Flutter's
/// rendered widget tree.
final class GenUiSurfaceNode {
  const GenUiSurfaceNode({required this.id, required this.type, required this.children});

  final String id;
  final String type;

  /// Referenced definition children, without expanding repeated data instances.
  final List<GenUiSurfaceNode> children;
}

/// Projects the current A2UI component references into a navigable tree.
/// Malformed or cyclic references are omitted; the renderer remains the
/// authority for whether a definition is valid.
///
/// Expects unique component IDs and a component named `root`. Returns null when
/// that root is absent. This is a definition tree, not an expansion of repeated
/// template instances from the live data model.
GenUiSurfaceNode? buildGenUiSurfaceTree(GenUiEditSnapshot snapshot) {
  final components = <String, Map<String, Object?>>{};
  for (final message in snapshot.messages) {
    final update = message['updateComponents'];
    if (update is! Map || update['components'] is! List) continue;
    for (final raw in update['components'] as List) {
      if (raw is! Map || raw['id'] is! String || raw['component'] is! String) {
        continue;
      }
      components[raw['id'] as String] = raw.cast<String, Object?>();
    }
  }

  GenUiSurfaceNode? visit(String id, Set<String> ancestors) {
    final component = components[id];
    if (component == null || ancestors.contains(id)) return null;
    final nextAncestors = {...ancestors, id};
    final references = <String>[];
    void collect(Object? value) {
      if (value is String) {
        if (components.containsKey(value)) references.add(value);
      } else if (value is List) {
        for (final item in value) {
          collect(item);
        }
      } else if (value is Map) {
        for (final entry in value.entries) {
          if (entry.key == 'child' ||
              entry.key == 'children' ||
              entry.key == 'content' ||
              entry.key == 'componentId') {
            collect(entry.value);
          } else if (entry.key == 'tabs') {
            collect(entry.value);
          }
        }
      }
    }

    for (final key in const ['child', 'children', 'content', 'tabs']) {
      collect(component[key]);
    }
    final seen = <String>{};
    final children = <GenUiSurfaceNode>[];
    for (final childId in references) {
      if (!seen.add(childId)) continue;
      final child = visit(childId, nextAncestors);
      if (child != null) children.add(child);
    }
    return GenUiSurfaceNode(id: id, type: component['component'] as String, children: children);
  }

  return visit('root', const {});
}
