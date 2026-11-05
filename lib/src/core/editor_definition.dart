/// Serializable components describing a property editor, rooted at `root`.
///
/// Components use the property editor's catalog rather than the host UI catalog.
/// Treat constructor arguments as shared data; this class does not deep-copy them.
final class EditablePropertyEditorDefinition {
  const EditablePropertyEditorDefinition({
    required this.id,
    required this.components,
  });

  final String id;
  final List<Map<String, Object?>> components;

  /// Encodes the definition without copying its component data.
  Map<String, Object?> toJson() => {'id': id, 'components': components};

  /// Checks basic IDs and component types, throwing [FormatException] for an
  /// invalid envelope. Does not validate the component graph or catalog schema.
  factory EditablePropertyEditorDefinition.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final raw = json['components'];
    if (id is! String || id.isEmpty || raw is! List || raw.isEmpty) {
      throw const FormatException('Invalid property editor definition.');
    }
    final components = <Map<String, Object?>>[];
    for (final value in raw) {
      if (value is! Map ||
          value['id'] is! String ||
          value['component'] is! String) {
        throw const FormatException('Invalid property editor component.');
      }
      components.add(value.cast<String, Object?>());
    }
    return EditablePropertyEditorDefinition(id: id, components: components);
  }
}
