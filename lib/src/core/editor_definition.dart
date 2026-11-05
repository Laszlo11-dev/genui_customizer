final class EditablePropertyEditorDefinition {
  const EditablePropertyEditorDefinition({
    required this.id,
    required this.components,
  });

  final String id;
  final List<Map<String, Object?>> components;

  Map<String, Object?> toJson() => {'id': id, 'components': components};

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
